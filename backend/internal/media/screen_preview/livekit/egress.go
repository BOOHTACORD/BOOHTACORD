package screenpreviewlivekit

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

const (
	egressHTTPTimeout = 8 * time.Second
	maxCaptureFile    = 5 * 1024 * 1024
	staleCaptureAfter = 75 * time.Second
)

var errNoCaptureFile = screenpreview.ErrNoUpdate

type captureEntry struct {
	session     screenpreview.CaptureSession
	channelID   string
	trackSID    string
	egressID    string
	fingerprint string
	startedAt   time.Time
	lastFrameAt time.Time
}

type sessionLock struct {
	mu   sync.Mutex
	refs int
}

type Capturer struct {
	config      Config
	root        string
	controlMu   sync.RWMutex
	mu          sync.RWMutex
	lockMu      sync.Mutex
	sessionLock map[string]*sessionLock
	active      map[string]captureEntry
}

func NewCapturer(config Config) (*Capturer, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || config.APIKey == "" || config.APISecret == "" {
		return nil, ErrUnavailable
	}
	root, err := filepath.Abs(config.PreviewRoot)
	if err != nil || config.PreviewRoot == "" {
		return nil, ErrUnavailable
	}
	if err := os.MkdirAll(root, 0o777); err != nil {
		return nil, ErrUnavailable
	}
	if err := ensureWorldWritableDirectory(root); err != nil {
		return nil, ErrUnavailable
	}
	return &Capturer{
		config: config, root: root,
		sessionLock: make(map[string]*sessionLock),
		active:      make(map[string]captureEntry),
	}, nil
}

func (capture *Capturer) Ensure(ctx context.Context, channelID, leaseID, generationID, trackSID string) error {
	if uuid.Validate(channelID) != nil || uuid.Validate(leaseID) != nil || uuid.Validate(generationID) != nil || trackSID == "" {
		return ErrUnavailable
	}
	capture.controlMu.RLock()
	defer capture.controlMu.RUnlock()
	unlockSession := capture.lockLease(leaseID)
	defer unlockSession()
	key := captureKey(leaseID, generationID)
	capture.mu.RLock()
	previous, known := capture.active[key]
	capture.mu.RUnlock()
	if known && previous.channelID == channelID && previous.trackSID == trackSID && capture.isFresh(previous, time.Now()) {
		return nil
	}
	stale := known && !capture.isFresh(previous, time.Now())
	roomName := "voice:" + channelID
	identity := "voice-lease:" + leaseID
	prefix, directory := capture.output(leaseID, generationID)
	if err := capture.prepareDirectory(leaseID, generationID); err != nil {
		return err
	}
	service, err := capture.egressService(roomName)
	if err != nil {
		return err
	}
	items, err := capture.list(ctx, service, roomName)
	if err != nil {
		return err
	}
	var existing *livekit.EgressInfo
	for _, item := range items {
		request := item.GetParticipant()
		if request == nil || request.GetIdentity() != identity || !managedPreviewRequest(request, capture.root) {
			continue
		}
		if item.GetRoomName() == roomName && request.GetScreenShare() && hasOutputPrefix(request.GetImageOutputs(), prefix) && item.GetEgressId() != "" {
			if stale && item.GetEgressId() == previous.egressID {
				if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
					return err
				}
				continue
			}
			existing = item
			continue
		}
		if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
			return err
		}
	}
	if existing != nil {
		capture.mu.Lock()
		capture.active[key] = captureEntry{session: screenpreview.CaptureSession{LeaseID: leaseID, GenerationID: generationID}, channelID: channelID, trackSID: trackSID, egressID: existing.GetEgressId(), startedAt: time.Now()}
		capture.mu.Unlock()
		return nil
	}
	if stale {
		if err := os.RemoveAll(directory); err != nil {
			return ErrUnavailable
		}
		if err := capture.prepareDirectory(leaseID, generationID); err != nil {
			return err
		}
	}
	capture.mu.Lock()
	capture.active[key] = captureEntry{
		session:   screenpreview.CaptureSession{LeaseID: leaseID, GenerationID: generationID},
		channelID: channelID, trackSID: trackSID,
	}
	capture.mu.Unlock()
	request := &livekit.ParticipantEgressRequest{
		RoomName:    roomName,
		Identity:    identity,
		ScreenShare: true,
		ImageOutputs: []*livekit.ImageOutput{{
			CaptureInterval: uint32(screenpreview.CaptureInterval.Seconds()),
			Width:           screenpreview.MaxPreviewWidth,
			FilenamePrefix:  prefix,
			FilenameSuffix:  livekit.ImageFileSuffix_IMAGE_SUFFIX_NONE_OVERWRITE,
			ImageCodec:      livekit.ImageCodec_IC_JPEG,
			DisableManifest: true,
		}},
	}
	info, err := service.StartParticipantEgress(ctx, request)
	if err != nil || info == nil || info.GetEgressId() == "" {
		_ = os.RemoveAll(directory)
		return ErrUnavailable
	}
	capture.mu.Lock()
	capture.active[key] = captureEntry{session: screenpreview.CaptureSession{LeaseID: leaseID, GenerationID: generationID}, channelID: channelID, trackSID: trackSID, egressID: info.GetEgressId(), startedAt: time.Now()}
	capture.mu.Unlock()
	return nil
}

func (capture *Capturer) Stop(ctx context.Context, leaseID, generationID, trackSID string) error {
	if uuid.Validate(leaseID) != nil || uuid.Validate(generationID) != nil {
		return ErrUnavailable
	}
	capture.controlMu.RLock()
	defer capture.controlMu.RUnlock()
	unlockSession := capture.lockLease(leaseID)
	defer unlockSession()
	key := captureKey(leaseID, generationID)
	capture.mu.RLock()
	entry, known := capture.active[key]
	capture.mu.RUnlock()
	roomName := ""
	if known {
		roomName = "voice:" + entry.channelID
	}
	var stopErr error
	if roomName != "" {
		service, err := capture.egressService(roomName)
		if err != nil {
			return err
		}
		items, err := capture.list(ctx, service, roomName)
		if err != nil {
			return err
		}
		prefix := capture.directory(leaseID, generationID)
		for _, item := range items {
			request := item.GetParticipant()
			if item.GetRoomName() != roomName || request == nil || request.GetIdentity() != "voice-lease:"+leaseID || !hasOutputPrefix(request.GetImageOutputs(), filepath.Join(prefix, "frame")) {
				continue
			}
			if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
				stopErr = err
			}
		}
	}
	if stopErr == nil {
		capture.mu.Lock()
		delete(capture.active, key)
		capture.mu.Unlock()
	}
	directory := capture.directory(leaseID, generationID)
	if err := os.RemoveAll(directory); err != nil {
		stopErr = errors.Join(stopErr, err)
	}
	if stopErr != nil {
		return ErrUnavailable
	}
	return nil
}

func (capture *Capturer) Latest(ctx context.Context, leaseID, generationID string) (screenpreview.CaptureFrame, error) {
	if uuid.Validate(leaseID) != nil || uuid.Validate(generationID) != nil {
		return screenpreview.CaptureFrame{}, ErrUnavailable
	}
	capture.controlMu.RLock()
	defer capture.controlMu.RUnlock()
	unlockSession := capture.lockLease(leaseID)
	defer unlockSession()
	key := captureKey(leaseID, generationID)
	capture.mu.RLock()
	entry, found := capture.active[key]
	capture.mu.RUnlock()
	if !found {
		return screenpreview.CaptureFrame{}, errNoCaptureFile
	}
	directory := capture.directory(leaseID, generationID)
	items, err := os.ReadDir(directory)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return screenpreview.CaptureFrame{}, errNoCaptureFile
		}
		return screenpreview.CaptureFrame{}, ErrUnavailable
	}
	var newest os.DirEntry
	var newestInfo os.FileInfo
	for _, item := range items {
		if item.Type()&os.ModeSymlink != 0 || item.IsDir() || !strings.HasPrefix(item.Name(), "frame") {
			continue
		}
		extension := strings.ToLower(filepath.Ext(item.Name()))
		if extension != ".jpeg" && extension != ".jpg" {
			continue
		}
		info, err := item.Info()
		if err != nil || !info.Mode().IsRegular() || info.Size() < 1 || info.Size() > maxCaptureFile {
			continue
		}
		if newestInfo == nil || info.ModTime().After(newestInfo.ModTime()) {
			newest, newestInfo = item, info
		}
	}
	if newest == nil {
		return screenpreview.CaptureFrame{}, errNoCaptureFile
	}
	fingerprint := fmt.Sprintf("%s:%d:%d", newest.Name(), newestInfo.Size(), newestInfo.ModTime().UnixNano())
	if fingerprint == entry.fingerprint {
		return screenpreview.CaptureFrame{}, errNoCaptureFile
	}
	path := filepath.Join(directory, newest.Name())
	body, err := os.ReadFile(path)
	if err != nil || int64(len(body)) != newestInfo.Size() {
		return screenpreview.CaptureFrame{}, errNoCaptureFile
	}
	if info, err := os.Stat(path); err != nil || info.ModTime() != newestInfo.ModTime() || info.Size() != newestInfo.Size() {
		return screenpreview.CaptureFrame{}, errNoCaptureFile
	}
	entry.fingerprint = fingerprint
	entry.lastFrameAt = time.Now()
	capture.mu.Lock()
	capture.active[key] = entry
	capture.mu.Unlock()
	return screenpreview.CaptureFrame{Fingerprint: fingerprint, JPEG: body}, nil
}

func (capture *Capturer) isFresh(entry captureEntry, now time.Time) bool {
	lastActivity := entry.lastFrameAt
	if lastActivity.IsZero() {
		lastActivity = entry.startedAt
	}
	return !lastActivity.IsZero() && now.Sub(lastActivity) < staleCaptureAfter
}

func (capture *Capturer) Active() []screenpreview.CaptureSession {
	capture.mu.RLock()
	defer capture.mu.RUnlock()
	active := make([]screenpreview.CaptureSession, 0, len(capture.active))
	for _, entry := range capture.active {
		active = append(active, entry.session)
	}
	return active
}

func (capture *Capturer) Reconcile(ctx context.Context, active []screenpreview.ActiveGeneration) error {
	capture.controlMu.Lock()
	defer capture.controlMu.Unlock()

	capture.mu.Lock()
	wanted := make(map[string]screenpreview.ActiveGeneration, len(active))
	for _, generation := range active {
		wanted[captureKey(generation.LeaseID, generation.GenerationID)] = generation
	}
	capture.mu.Unlock()
	service, err := capture.globalEgressService()
	if err != nil {
		return err
	}
	items, err := capture.list(ctx, service, "")
	if err != nil {
		return err
	}
	seen := make(map[string]struct{}, len(wanted))
	for _, item := range items {
		request := item.GetParticipant()
		if request == nil || !managedPreviewRequest(request, capture.root) {
			continue
		}
		leaseID := strings.TrimPrefix(request.GetIdentity(), "voice-lease:")
		if uuid.Validate(leaseID) != nil {
			if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
				return err
			}
			continue
		}
		var generationID string
		for _, output := range request.GetImageOutputs() {
			if output != nil {
				generationID = capture.generationFromPrefix(leaseID, output.GetFilenamePrefix())
				if generationID != "" {
					break
				}
			}
		}
		key := captureKey(leaseID, generationID)
		expected, keep := wanted[key]
		if _, duplicate := seen[key]; duplicate {
			if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
				return err
			}
			continue
		}
		if !keep || !request.GetScreenShare() || expected.ChannelID == "" || item.GetRoomName() != "voice:"+expected.ChannelID {
			if err := capture.stopEgress(ctx, service, item.GetEgressId()); err != nil {
				return err
			}
			capture.mu.Lock()
			delete(capture.active, key)
			capture.mu.Unlock()
			continue
		}
		capture.mu.Lock()
		capture.active[key] = captureEntry{
			session:   screenpreview.CaptureSession{LeaseID: leaseID, GenerationID: generationID},
			channelID: expected.ChannelID, trackSID: expected.TrackSID, egressID: item.GetEgressId(),
		}
		capture.mu.Unlock()
		seen[key] = struct{}{}
	}
	capture.mu.Lock()
	for key := range capture.active {
		if _, keep := wanted[key]; !keep {
			delete(capture.active, key)
		}
	}
	capture.mu.Unlock()
	if err := capture.cleanStaleDirectories(wanted); err != nil {
		return ErrUnavailable
	}
	return nil
}

func (capture *Capturer) lockLease(leaseID string) func() {
	capture.lockMu.Lock()
	lock := capture.sessionLock[leaseID]
	if lock == nil {
		lock = &sessionLock{}
		capture.sessionLock[leaseID] = lock
	}
	lock.refs++
	capture.lockMu.Unlock()

	lock.mu.Lock()
	return func() {
		lock.mu.Unlock()
		capture.lockMu.Lock()
		lock.refs--
		if lock.refs == 0 {
			delete(capture.sessionLock, leaseID)
		}
		capture.lockMu.Unlock()
	}
}

func (capture *Capturer) list(ctx context.Context, service livekit.Egress, roomName string) ([]*livekit.EgressInfo, error) {
	var items []*livekit.EgressInfo
	request := &livekit.ListEgressRequest{RoomName: roomName, Active: true}
	for page := 0; page < 100; page++ {
		response, err := service.ListEgress(ctx, request)
		if err != nil || response == nil {
			return nil, ErrUnavailable
		}
		items = append(items, response.GetItems()...)
		if response.GetNextPageToken() == nil || response.GetNextPageToken().GetToken() == "" {
			return items, nil
		}
		request.PageToken = response.GetNextPageToken()
	}
	return nil, ErrUnavailable
}

func (capture *Capturer) stopEgress(ctx context.Context, service livekit.Egress, egressID string) error {
	if egressID == "" {
		return nil
	}
	if _, err := service.StopEgress(ctx, &livekit.StopEgressRequest{EgressId: egressID}); err != nil {
		return ErrUnavailable
	}
	return nil
}

func (capture *Capturer) egressService(roomName string) (livekit.Egress, error) {
	token, err := auth.NewAccessToken(capture.config.APIKey, capture.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomRecord: true, Room: roomName}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return nil, ErrUnavailable
	}
	return livekit.NewEgressJSONClient(capture.config.URL, &http.Client{Timeout: egressHTTPTimeout,
		Transport: bearerTransport{token: token, next: capture.transport()}}), nil
}

func (capture *Capturer) globalEgressService() (livekit.Egress, error) {
	token, err := auth.NewAccessToken(capture.config.APIKey, capture.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomRecord: true, RoomList: true}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return nil, ErrUnavailable
	}
	return livekit.NewEgressJSONClient(capture.config.URL, &http.Client{Timeout: egressHTTPTimeout,
		Transport: bearerTransport{token: token, next: capture.transport()}}), nil
}

func (capture *Capturer) transport() http.RoundTripper {
	if capture.config.HTTPTransport != nil {
		return capture.config.HTTPTransport
	}
	return http.DefaultTransport
}

func (capture *Capturer) output(leaseID, generationID string) (string, string) {
	directory := capture.directory(leaseID, generationID)
	return filepath.Join(directory, "frame"), directory
}

func (capture *Capturer) directory(leaseID, generationID string) string {
	return filepath.Join(capture.root, leaseID, generationID)
}

func (capture *Capturer) prepareDirectory(leaseID, generationID string) error {
	leaseDirectory := filepath.Join(capture.root, leaseID)
	directory := capture.directory(leaseID, generationID)
	if err := os.MkdirAll(directory, 0o777); err != nil {
		return ErrUnavailable
	}
	if err := ensureWorldWritableDirectory(leaseDirectory); err != nil {
		return ErrUnavailable
	}
	if err := ensureWorldWritableDirectory(directory); err != nil {
		return ErrUnavailable
	}
	return nil
}

func ensureWorldWritableDirectory(path string) error {
	return ensureWorldWritableDirectoryWith(path, os.Chmod)
}

func ensureWorldWritableDirectoryWith(path string, chmod func(string, os.FileMode) error) error {
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return ErrUnavailable
	}
	if info.Mode().Perm()&0o007 == 0o007 {
		return nil
	}
	return chmod(path, 0o777)
}

func (capture *Capturer) generationFromPrefix(leaseID, prefix string) string {
	leaseRoot := filepath.Join(capture.root, leaseID)
	relative, err := filepath.Rel(leaseRoot, prefix)
	if err != nil || filepath.IsAbs(relative) {
		return ""
	}
	parts := strings.Split(filepath.Clean(relative), string(filepath.Separator))
	if len(parts) != 2 || parts[1] != "frame" || uuid.Validate(parts[0]) != nil {
		return ""
	}
	return parts[0]
}

func (capture *Capturer) cleanStaleDirectories(wanted map[string]screenpreview.ActiveGeneration) error {
	leases, err := os.ReadDir(capture.root)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	for _, leaseDirectory := range leases {
		if !leaseDirectory.IsDir() || leaseDirectory.Type()&os.ModeSymlink != 0 || uuid.Validate(leaseDirectory.Name()) != nil {
			continue
		}
		path := filepath.Join(capture.root, leaseDirectory.Name())
		generations, err := os.ReadDir(path)
		if err != nil {
			return err
		}
		for _, generationDirectory := range generations {
			if !generationDirectory.IsDir() || generationDirectory.Type()&os.ModeSymlink != 0 || uuid.Validate(generationDirectory.Name()) != nil {
				continue
			}
			if _, keep := wanted[captureKey(leaseDirectory.Name(), generationDirectory.Name())]; !keep {
				if err := os.RemoveAll(filepath.Join(path, generationDirectory.Name())); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func managedPreviewRequest(request *livekit.ParticipantEgressRequest, root string) bool {
	if request == nil || !strings.HasPrefix(request.GetIdentity(), "voice-lease:") || len(request.GetImageOutputs()) == 0 {
		return false
	}
	for _, output := range request.GetImageOutputs() {
		if output == nil || output.GetFilenamePrefix() == "" {
			continue
		}
		relative, err := filepath.Rel(root, output.GetFilenamePrefix())
		if err == nil && relative != "." && !filepath.IsAbs(relative) && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func hasOutputPrefix(outputs []*livekit.ImageOutput, prefix string) bool {
	for _, output := range outputs {
		if output != nil && filepath.Clean(output.GetFilenamePrefix()) == filepath.Clean(prefix) {
			return true
		}
	}
	return false
}

func captureKey(leaseID, generationID string) string { return leaseID + "/" + generationID }
