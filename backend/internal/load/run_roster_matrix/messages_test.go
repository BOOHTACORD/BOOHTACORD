package runrostermatrix

import (
	"context"
	"testing"
	"time"
	chat "voice-platform/backend/internal/load/matrix_chat"
)

func TestMessageWorkloadRecordsEveryRecipientAndRejectsDuplicates(t *testing.T) {
	const id = "11111111-1111-4111-8111-111111111111"
	c, err := chat.New(2)
	if err != nil {
		t.Fatal(err)
	}
	send := func(context.Context) (string, error) {
		now := time.Now()
		c.Observe(0, id, now)
		c.Observe(1, id, now)
		return id, nil
	}
	got, err := measureMessages(context.Background(), c, 3, send)
	if err != nil || got.Messages != 3 || got.Deliveries.Count != 6 || got.Duplicates != 0 || len(got.Batches) != 3 || got.Batches[0].Count != 2 {
		t.Fatalf("workload: %+v %v", got, err)
	}
	duplicate := func(context.Context) (string, error) {
		now := time.Now()
		c.Observe(0, id, now)
		c.Observe(0, id, now)
		c.Observe(1, id, now)
		return id, nil
	}
	if result, err := measureMessages(context.Background(), c, 1, duplicate); err == nil || result.Failure != "duplicates" {
		t.Fatal("duplicates accepted")
	}
	if _, err := measureMessages(context.Background(), c, 21, send); err == nil {
		t.Fatal("unbounded count accepted")
	}
}

func TestMessageWorkloadSummarizesPresenceDuringFirstDelivery(t *testing.T) {
	const id = "11111111-1111-4111-8111-111111111111"
	c, _ := chat.New(1)
	c.ObservePresence(0)
	c.ObserveAuxiliary(0, "roster")
	report, err := measureMessages(context.Background(), c, 1, func(context.Context) (string, error) {
		c.ObservePresence(0)
		c.ObservePresence(0)
		c.ObserveAuxiliary(0, "maintenance")
		c.Observe(0, id, time.Now())
		return id, nil
	})
	if err != nil || report.PresenceBeforeFirst != 1 || report.PresenceDuringFirst != 2 || report.AuxiliaryBeforeFirst != [2]uint64{1, 0} || report.AuxiliaryDuringFirst != [2]uint64{0, 1} {
		t.Fatalf("presence accounting: %+v %v", report, err)
	}
}

func TestMessageWorkloadRecordsReceiptLatencySeparatelyFromDelivery(t *testing.T) {
	const id = "11111111-1111-4111-8111-111111111111"
	c, _ := chat.New(1)
	report, err := measureMessages(context.Background(), c, 1, func(context.Context) (string, error) {
		c.Observe(0, id, time.Now())
		time.Sleep(25 * time.Millisecond)
		return id, nil
	})
	if err != nil || len(report.ReceiptMillis) != 1 || report.ReceiptMillis[0] < 20 || report.Batches[0].P95MS >= report.ReceiptMillis[0] {
		t.Fatalf("receipt and delivery timings: %+v %v", report, err)
	}
}

func TestMessageWorkloadReportsSafeSendFailure(t *testing.T) {
	c, _ := chat.New(1)
	report, err := measureMessages(context.Background(), c, 1, func(context.Context) (string, error) {
		return "", &chat.ReceiptError{StatusCode: 429}
	})
	if err == nil || report.Failure != "send" || report.HTTPStatus != 429 {
		t.Fatalf("failure classification: %+v", report)
	}
}
