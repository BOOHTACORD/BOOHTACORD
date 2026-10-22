package supportbridge

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"log/slog"
	"time"
	send "voice-platform/backend/internal/chat/send_direct_message"
	sendpostgres "voice-platform/backend/internal/chat/send_direct_message/postgres"
	sendrealtime "voice-platform/backend/internal/chat/send_direct_message/realtime"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	recipients "voice-platform/backend/internal/realtime/resolve_direct_message_recipients/postgres"
	files "voice-platform/backend/internal/storage/download_text_attachment"
)

const DefaultEndpoint = "https://metric.bootybay.ru/support/v1"

type Sender interface {
	Send(context.Context, send.Input) (send.Result, error)
}
type Worker struct {
	db     *pgxpool.Pool
	client Client
	files  files.FileStore
	sender Sender
	peer   string
}

func NewWorker(ctx context.Context, db *pgxpool.Pool, root, endpoint string, events *eventhub.Hub) (Worker, error) {
	var seed []byte
	var peer string
	if err := db.QueryRow(ctx, `SELECT seed,account_id::text FROM support_product_identity WHERE singleton=true`).Scan(&seed, &peer); err != nil {
		return Worker{}, ErrGateway
	}
	if endpoint == "" {
		endpoint = DefaultEndpoint
	}
	client, err := NewClient(endpoint, seed)
	if err != nil {
		return Worker{}, err
	}
	storage, err := files.NewFileStore(root)
	if err != nil {
		return Worker{}, err
	}
	sender := sendrealtime.New(send.New(sendpostgres.New(sendpostgres.NewPoolDatabase(db))), recipients.New(recipients.NewPoolDatabase(db)), events)
	return Worker{db, client, storage, sender, peer}, nil
}
func (w Worker) Start(parent context.Context) func(context.Context) error {
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() {
		defer close(done)
		timer := time.NewTicker(10 * time.Second)
		defer timer.Stop()
		for {
			run, stop := context.WithTimeout(ctx, 2*time.Minute)
			err := w.Tick(run)
			stop()
			if err != nil && ctx.Err() == nil {
				slog.Warn("product support delivery will retry")
			}
			select {
			case <-ctx.Done():
				return
			case <-timer.C:
			}
		}
	}()
	return func(ctx context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}
