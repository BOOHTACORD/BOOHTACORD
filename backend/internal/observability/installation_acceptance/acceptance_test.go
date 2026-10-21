//go:build installation_acceptance

// These tests require the owned fixture runner; skips are never runtime PASS.
package installationacceptance

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	metricscollector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	collector "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	metrics "go.opentelemetry.io/proto/otlp/metrics/v1"
	resource "go.opentelemetry.io/proto/otlp/resource/v1"
	spans "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
	migrate "voice-platform/backend/internal/database/migrate"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	central "voice-platform/backend/internal/observability/central_export"
	gateway "voice-platform/backend/internal/observability/central_gateway"
	projection "voice-platform/backend/internal/observability/central_projection"
	correlate "voice-platform/backend/internal/observability/correlate_session"
	relay "voice-platform/backend/internal/observability/ingest_client_traces"
	identity "voice-platform/backend/internal/observability/installation"
	installationapi "voice-platform/backend/internal/observability/installation/api"
	metricstart "voice-platform/backend/internal/observability/start_metrics"
	tracing "voice-platform/backend/internal/observability/start_tracing"
)

func ownedDatabase(t *testing.T, base string) *pgxpool.Pool {
	t.Helper()
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, base)
	must(t, err, "open owned cluster")
	name := "it336_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	_, err = admin.Exec(ctx, `CREATE DATABASE `+name)
	must(t, err, "create owned database")
	u, err := url.Parse(base)
	must(t, err, "parse owned DSN")
	u.Path = "/" + name
	db, err := pgxpool.New(ctx, u.String())
	must(t, err, "open isolated database")
	t.Cleanup(func() {
		db.Close()
		_, _ = admin.Exec(context.Background(), `DROP DATABASE `+name+` WITH (FORCE)`)
		admin.Close()
	})
	return db
}
func must(t *testing.T, err error, stage string) {
	t.Helper()
	if err != nil {
		t.Fatal(stage + " failed")
	}
}
func eventually(t *testing.T, stage string, check func() bool) {
	t.Helper()
	deadline := time.Now().Add(45 * time.Second)
	for time.Now().Before(deadline) {
		if check() {
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
	t.Fatal(stage + " did not become true")
}
func TestTwoInstallationsThroughActualStorage(t *testing.T) {
	base := os.Getenv("BOOHTACORD_TELEMETRY_TEST_DATABASE_URL")
	if base == "" {
		t.Skip("requires owned PostgreSQL/Tempo/Prometheus fixture")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Second)
	defer cancel()
	aDB, bDB, registryDB := ownedDatabase(t, base), ownedDatabase(t, base), ownedDatabase(t, base)
	must(t, migrate.Run(ctx, aDB), "migrate installation A")
	must(t, migrate.Run(ctx, bDB), "migrate installation B")
	for _, db := range []*pgxpool.Pool{aDB, bDB} {
		_, e := db.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES('00000000-0000-4000-8000-000000000001','synthetic336','Synthetic private fixture','not-a-login-hash','MEMBER')`)
		must(t, e, "seed equal isolated accounts")
	}
	a, err := identity.Load(ctx, aDB)
	must(t, err, "load A")
	b, err := identity.Load(ctx, bDB)
	must(t, err, "load B")
	if a.ID == b.ID {
		t.Fatal("independent databases collided")
	}
	aRestart, err := identity.Load(ctx, aDB)
	must(t, err, "restore identity")
	if aRestart.ID != a.ID || !bytes.Equal(aRestart.Key, a.Key) {
		t.Fatal("restart changed identity")
	}
	store := gateway.Postgres{DB: registryDB}
	must(t, store.Initialize(ctx), "initialize real registry")
	gw, err := gateway.New(gateway.Config{Registry: store, CredentialKey: bytes.Repeat([]byte{7}, 32), ReadToken: "synthetic-private-owner-token", TempoURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_OTLP"), TempoQueryURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_TEMPO"), MetricsURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_COLLECTOR")})
	must(t, err, "compose gateway")
	server := httptest.NewTLSServer(gw)
	defer server.Close()
	client := server.Client()
	tlsTransport := client.Transport.(*http.Transport).Clone()
	tlsTransport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		u, _ := url.Parse(server.URL)
		return (&net.Dialer{}).DialContext(ctx, network, u.Host)
	}
	client = &http.Client{Transport: tlsTransport, Timeout: 4 * time.Second}
	u, _ := url.Parse(server.URL)
	endpoint := "https://example.com:" + u.Port()
	runtime := func(db *pgxpool.Pool, i identity.Identity) *central.Runtime {
		r := central.New(i, func(ctx context.Context) (identity.Identity, error) { return identity.Load(ctx, db) }, func(ctx context.Context, i identity.Identity) error { return identity.Save(ctx, db, i) }, client)
		r.RecordAcceptance = func(ctx context.Context, i identity.Identity, at time.Time) error {
			return identity.Confirm(ctx, db, i, at)
		}
		return r
	}
	ra, rb := runtime(aDB, a), runtime(bDB, b)
	must(t, ra.Enable(ctx, endpoint), "signed enrollment A")
	must(t, rb.Enable(ctx, endpoint), "signed enrollment B")
	stopA, stopB := ra.Start(ctx), rb.Start(ctx)
	defer stopA(context.Background())
	defer stopB(context.Background())
	a = ra.Identity()
	b = rb.Identity()
	tokenA, tokenB := a.Credential, b.Credential
	post := func(path, token string, raw []byte) int {
		req, _ := http.NewRequestWithContext(ctx, "POST", endpoint+path, bytes.NewReader(raw))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/x-protobuf")
		req.Header.Set("X-Scope-OrgID", b.ID)
		response, e := client.Do(req)
		if e != nil {
			return 0
		}
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
		return response.StatusCode
	}
	sameTrace := bytes.Repeat([]byte{1}, 16)
	account := "00000000-0000-4000-8000-000000000001"
	batch := func(i identity.Identity) []byte {
		now := uint64(time.Now().UnixNano())
		span := &spans.Span{Name: "startup", TraceId: sameTrace, SpanId: bytes.Repeat([]byte{2}, 8), StartTimeUnixNano: now - 1000000, EndTimeUnixNano: now, Attributes: []*common.KeyValue{projection.String("user.id", account), projection.String("session.id", "same-session"), projection.String("user.name", "SYNTHETIC_PRIVATE")}}
		rs := &spans.ResourceSpans{Resource: &resource.Resource{Attributes: []*common.KeyValue{projection.String("service.name", "boohtacord-api"), projection.String("service.instance.id", uuid.NewString())}}, ScopeSpans: []*spans.ScopeSpans{{Spans: []*spans.Span{span}}}}
		raw, _ := proto.Marshal(&collector.ExportTraceServiceRequest{ResourceSpans: []*spans.ResourceSpans{rs}})
		out, e := projection.Traces(raw, i)
		must(t, e, "project actual export")
		return out
	}

	aBody, bBody := batch(a), batch(b)
	if post("/v1/traces", tokenA, bBody) != 400 {
		t.Fatal("credential crossed installation body")
	}
	statusA, statusB := post("/v1/traces", tokenA, aBody), post("/v1/traces", tokenB, bBody)
	if statusA != 200 || statusB != 200 {
		t.Fatalf("actual tenant trace ingest status A=%d B=%d", statusA, statusB)
	}
	read := func(i identity.Identity) ([]byte, int) {
		req, _ := http.NewRequestWithContext(ctx, "GET", endpoint+"/read/tempo/"+i.ID+"/api/traces/"+hex.EncodeToString(sameTrace), nil)
		req.Header.Set("Authorization", "Bearer synthetic-private-owner-token")
		response, e := client.Do(req)
		if e != nil {
			return nil, 0
		}
		defer response.Body.Close()
		body, _ := io.ReadAll(response.Body)
		return body, response.StatusCode
	}
	for _, i := range []identity.Identity{a, b} {
		i := i
		eventually(t, "tenant-isolated trace query", func() bool {
			body, status := read(i)
			other := a
			if i.ID == a.ID {
				other = b
			}
			return status == 200 && bytes.Contains(body, []byte(i.Pseudonym("user", account))) && !bytes.Contains(body, []byte(other.Pseudonym("user", account))) && !bytes.Contains(body, []byte("SYNTHETIC_PRIVATE"))
		})
	}

	principal := session.Principal{AccountID: account, DisplayName: "SYNTHETIC_PRIVATE", SessionDigest: [sha256.Size]byte{1}}
	binding := correlate.Attributes(principal.AccountID, principal.SessionDigest)[1].Value.AsString()
	now := uint64(time.Now().UnixNano())
	attrs := []*common.KeyValue{projection.String("session.id", binding), projection.String("app.visit.id", strings.Repeat("3", 32)), projection.String("app.flow.id", strings.Repeat("4", 32)), projection.String("app.flow.name", "startup"), projection.String("app.flow.stage", "restore"), projection.String("app.flow.record", "checkpoint"), projection.String("app.flow.outcome", "success"), projection.String("user.id", "forged-user")}
	attrs = append(attrs, &common.KeyValue{Key: "app.schema.version", Value: &common.AnyValue{Value: &common.AnyValue_IntValue{IntValue: 1}}}, &common.KeyValue{Key: "app.flow.attempt", Value: &common.AnyValue{Value: &common.AnyValue_IntValue{IntValue: 1}}})
	clientSpan := &spans.Span{Name: "startup", TraceId: sameTrace, SpanId: bytes.Repeat([]byte{3}, 8), StartTimeUnixNano: now - 1000, EndTimeUnixNano: now, Attributes: attrs}
	clientRaw, _ := proto.Marshal(&collector.ExportTraceServiceRequest{ResourceSpans: []*spans.ResourceSpans{{ScopeSpans: []*spans.ScopeSpans{{Spans: []*spans.Span{clientSpan}}}}}})
	request := httptest.NewRequest("POST", "/api/v1/telemetry/traces", bytes.NewReader(clientRaw))
	request = request.WithContext(sessionapi.WithPrincipal(ctx, principal))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "web")
	request.Header.Set("X-Telemetry-Session", binding)
	response := httptest.NewRecorder()
	relay.NewHandler("", "", nil, relay.Options{Central: ra, CausalKey: a.ProofKey()}).ServeHTTP(response, request)
	if response.Code != 202 {
		t.Fatalf("legacy-compatible authenticated client relay status %d", response.Code)
	}
	eventually(t, "client/server user correlation in real Tempo", func() bool {
		body, status := read(a)
		return status == 200 && bytes.Contains(body, []byte("boohtacord-web")) && bytes.Contains(body, []byte(a.Pseudonym("user", account))) && !bytes.Contains(body, []byte("forged-user"))
	})
	t.Log("PASS: same trace/span and account IDs are separated by authenticated Tempo tenants; exported private strings absent")
	// The real SDK uses the same process resource and projector as production.
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "")
	prior := otel.GetTracerProvider()
	defer otel.SetTracerProvider(prior)
	shutdown, err := tracing.Start(central.Context(ctx, ra))
	must(t, err, "start actual SDK exporter")
	_, span := otel.Tracer("synthetic-336").Start(ctx, "startup")
	span.SetAttributes(attribute.String("user.id", account))
	span.End()
	must(t, shutdown(ctx), "flush actual SDK exporter")
	eventually(t, "asynchronous SDK delivery", func() bool { return ra.Snapshot().LastAccepted != nil })
	secondA := runtime(aDB, a)
	if secondA.Instance() == ra.Instance() || secondA.Identity().ID != a.ID {
		t.Fatal("replica identity collision")
	}
	metricBody := func(i identity.Identity, instance string) []byte {
		now := uint64(time.Now().UnixNano())
		point := &metrics.NumberDataPoint{StartTimeUnixNano: now - 1000000, TimeUnixNano: now, Value: &metrics.NumberDataPoint_AsInt{AsInt: 1}, Attributes: []*common.KeyValue{projection.String("user.id", "SYNTHETIC_PRIVATE"), projection.String("status", "200")}}
		point.Attributes = append(point.Attributes, projection.String("http.route", "GET /api/v1/channels"))
		secondPoint := proto.Clone(point).(*metrics.NumberDataPoint)
		secondPoint.Attributes[len(secondPoint.Attributes)-1] = projection.String("http.route", "GET /api/v1/admin/accounts")
		instrument := &metrics.Metric{Name: "boohtacord.http.server.requests", Data: &metrics.Metric_Sum{Sum: &metrics.Sum{IsMonotonic: true, AggregationTemporality: metrics.AggregationTemporality_AGGREGATION_TEMPORALITY_CUMULATIVE, DataPoints: []*metrics.NumberDataPoint{point, secondPoint}}}}
		rm := &metrics.ResourceMetrics{Resource: &resource.Resource{Attributes: []*common.KeyValue{projection.String("service.name", "boohtacord-api"), projection.String("service.instance.id", instance)}}, ScopeMetrics: []*metrics.ScopeMetrics{{Metrics: []*metrics.Metric{instrument}}}}
		raw, _ := proto.Marshal(&metricscollector.ExportMetricsServiceRequest{ResourceMetrics: []*metrics.ResourceMetrics{rm}})
		out, e := projection.Metrics(raw, i)
		must(t, e, "project actual metrics")
		return out
	}

	if post("/v1/metrics", tokenA, metricBody(a, ra.Instance())) != 200 || post("/v1/metrics", tokenA, metricBody(a, secondA.Instance())) != 200 || post("/v1/metrics", tokenB, metricBody(b, rb.Instance())) != 200 {
		t.Fatal("actual metric ingest failed")
	}
	query := url.QueryEscape(`boohtacord_http_server_requests_total{installation_id="` + a.ID + `"}`)
	eventually(t, "Prometheus installation and replica series", func() bool {
		response, e := http.Get(os.Getenv("BOOHTACORD_TELEMETRY_TEST_PROMETHEUS") + "/api/v1/query?query=" + query)
		if e != nil {
			return false
		}
		defer response.Body.Close()
		var result struct {
			Data struct {
				Result []struct {
					Metric map[string]string `json:"metric"`
				} `json:"result"`
			} `json:"data"`
		}
		if json.NewDecoder(response.Body).Decode(&result) != nil {
			return false
		}
		instances := map[string]bool{}
		for _, row := range result.Data.Result {
			if row.Metric["installation_id"] != a.ID || row.Metric["user_id"] != "" {
				return false
			}
			instances[row.Metric["service_instance_id"]] = true
		}
		return instances[ra.Instance()] && instances[secondA.Instance()]
	})

	// Exercise production delivery-health instruments through the actual SDK,
	// privacy projector, authenticated gateway and Prometheus translation.
	t.Setenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "")
	t.Setenv("APP_VERSION", "1.0.44")
	previousMeter := otel.GetMeterProvider()
	defer otel.SetMeterProvider(previousMeter)
	stopMetrics, err := metricstart.Start(central.Context(ctx, ra))
	must(t, err, "start real delivery-health metrics")
	defer stopMetrics(context.Background())
	must(t, otel.GetMeterProvider().(*sdkmetric.MeterProvider).ForceFlush(ctx), "flush delivery-health instruments")
	eventually(t, "delivery-health build and installation in real Prometheus", func() bool {
		response, e := http.Get(os.Getenv("BOOHTACORD_TELEMETRY_TEST_PROMETHEUS") + "/api/v1/query?query=" + url.QueryEscape(`boohtacord_telemetry_build_info{installation_id="`+a.ID+`",service_version="1.0.44"}`))
		if e != nil {
			return false
		}
		defer response.Body.Close()
		body, _ := io.ReadAll(response.Body)
		return bytes.Contains(body, []byte(a.ID)) && bytes.Contains(body, []byte("service_version"))
	})
	for _, fixture := range []struct {
		identity identity.Identity
		runtime  *central.Runtime
		source   string
	}{{a, ra, os.Getenv("BOOHTACORD_TELEMETRY_TEST_SFU_A")}, {b, rb, os.Getenv("BOOHTACORD_TELEMETRY_TEST_SFU_B")}} {
		var sample float64
		eventually(t, "private SFU metrics available", func() bool {
			response, e := http.Get(fixture.source + "/metrics")
			if e != nil {
				return false
			}
			defer response.Body.Close()
			raw, e := io.ReadAll(io.LimitReader(response.Body, 2*1024*1024))
			if e != nil {
				return false
			}
			for _, line := range strings.Split(string(raw), "\n") {
				if strings.HasPrefix(line, "livekit_room_total ") || strings.HasPrefix(line, "livekit_room_total{") {
					fields := strings.Fields(line)
					if len(fields) < 2 {
						continue
					}
					value, e := strconv.ParseFloat(fields[1], 64)
					if e == nil {
						sample = value
						return true
					}
				}
			}
			return false
		})
		point := &metrics.NumberDataPoint{TimeUnixNano: uint64(time.Now().UnixNano()), Value: &metrics.NumberDataPoint_AsDouble{AsDouble: sample}}
		instrument := &metrics.Metric{Name: "livekit_room_total", Data: &metrics.Metric_Gauge{Gauge: &metrics.Gauge{DataPoints: []*metrics.NumberDataPoint{point}}}}
		resourceMetrics := &metrics.ResourceMetrics{Resource: &resource.Resource{Attributes: []*common.KeyValue{projection.String("service.name", "boohtacord-livekit"), projection.String("boohtacord.installation.id", fixture.identity.ID)}}, ScopeMetrics: []*metrics.ScopeMetrics{{Metrics: []*metrics.Metric{instrument}}}}
		raw, _ := proto.Marshal(&metricscollector.ExportMetricsServiceRequest{ResourceMetrics: []*metrics.ResourceMetrics{resourceMetrics}})
		request := httptest.NewRequest("POST", "/internal/telemetry/metrics", bytes.NewReader(raw))
		request.Header.Set("Authorization", "Bearer "+fixture.identity.Pseudonym("local-agent", fixture.identity.ID))
		request.Header.Set("Content-Type", "application/x-protobuf")
		response := httptest.NewRecorder()
		installationapi.Handler{Runtime: fixture.runtime}.Agent(response, request)
		if response.Code != 200 {
			t.Fatal("local authenticated SFU relay failed")
		}
	}
	eventually(t, "both actual private SFUs in central Prometheus", func() bool {
		response, e := http.Get(os.Getenv("BOOHTACORD_TELEMETRY_TEST_PROMETHEUS") + "/api/v1/query?query=" + url.QueryEscape(`livekit_room_total{service_name="boohtacord-livekit"}`))
		if e != nil {
			return false
		}
		defer response.Body.Close()
		body, _ := io.ReadAll(response.Body)
		return bytes.Contains(body, []byte(a.ID)) && bytes.Contains(body, []byte(b.ID))
	})
	t.Log("PASS: real Prometheus retains installation and replica identity without user labels")
	proof := a.ProofKey()
	_, err = registryDB.Exec(ctx, `UPDATE telemetry_installations SET epoch=epoch+1 WHERE installation_id=$1`, a.ID)
	must(t, err, "rotate write credential")
	if post("/v1/traces", tokenA, aBody) != 401 {
		t.Fatal("old credential survived rotation")
	}
	must(t, ra.Enable(ctx, endpoint), "reenroll same owner")
	if ra.Identity().ProofKey() != proof {
		t.Fatal("transport rotation changed causal key")
	}
	_, err = registryDB.Exec(ctx, `UPDATE telemetry_installations SET enabled=false WHERE installation_id=$1`, a.ID)
	must(t, err, "revoke A")
	if post("/v1/traces", ra.Identity().Credential, aBody) != 401 || post("/v1/traces", tokenB, bBody) != 200 {
		t.Fatal("revoke crossed installations")
	}
	must(t, rb.Disable(ctx), "disable external export")
	if rb.Enqueue("traces", bBody) || rb.Snapshot().Queued != 0 {
		t.Fatal("disabled queue retained export")
	}
	record, err := store.Get(ctx, b.ID)
	must(t, err, "read disabled registration")
	if record.Mode != "disabled" {
		t.Fatal("central disable acknowledgment missing")
	}
	clone, err := identity.ResetClone(ctx, bDB)
	must(t, err, "explicit independent clone reset")
	if clone.ID == b.ID || clone.Pseudonym("user", account) == b.Pseudonym("user", account) || clone.Credential != "" || clone.Mode != "local_only" {
		t.Fatal("clone reused identity or credential")
	}
	var remaining int
	must(t, bDB.QueryRow(ctx, `SELECT count(*) FROM users WHERE login='synthetic336'`).Scan(&remaining), "check clone product rows")
	if remaining != 1 {
		t.Fatal("clone reset changed product accounts")
	}
	_, err = bDB.Exec(ctx, `DELETE FROM installation_identity`)
	must(t, err, "inject missing identity")
	must(t, migrate.Run(ctx, bDB), "repeat migration on corrupt identity")
	if _, err = identity.Load(ctx, bDB); err == nil {
		t.Fatal("missing identity silently regenerated")
	}
	t.Log("PASS: credential rotation/revoke, disabled egress, explicit clone reset and corruption behavior")
}

func TestConcurrentFirstInitialization(t *testing.T) {
	base := os.Getenv("BOOHTACORD_TELEMETRY_TEST_DATABASE_URL")
	if base == "" {
		t.Skip("requires owned PostgreSQL fixture")
	}
	db := ownedDatabase(t, base)
	raw, err := os.ReadFile("../../database/migrate/migrations/0054_installation_identity.sql")
	must(t, err, "read production identity migration")
	var group sync.WaitGroup
	results := make(chan error, 8)
	for n := 0; n < 8; n++ {
		group.Add(1)
		go func() { defer group.Done(); _, err := db.Exec(context.Background(), string(raw)); results <- err }()
	}
	group.Wait()
	close(results)
	for err := range results {
		must(t, err, "concurrent initialization")
	}
	var count int
	must(t, db.QueryRow(context.Background(), `SELECT count(*) FROM installation_identity`).Scan(&count), "read identity count")
	if count != 1 {
		t.Fatal("parallel init produced duplicate installation")
	}
	fmt.Println("PASS: eight concurrent first boots return one persistent installation")
}
