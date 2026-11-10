package runrostermatrix

import (
	"context"
	"errors"
	"time"
	chat "voice-platform/backend/internal/load/matrix_chat"
)

type MessageReport struct {
	Failure                                    string
	HTTPStatus                                 int
	Messages                                   int
	Duplicates                                 int
	Deliveries                                 Summary
	Batches                                    []Summary
	ReceiptMillis                              []float64
	CreatedMillis                              []float64
	EventAges                                  []Summary
	ServerBefore, ServerAfter                  map[string]float64
	PresenceBeforeFirst, PresenceDuringFirst   uint64
	AuxiliaryBeforeFirst, AuxiliaryDuringFirst [2]uint64
}

func measureMessages(parent context.Context, collector *chat.Collector, count int, send func(context.Context) (string, error)) (report MessageReport, err error) {
	return measureMessagesWithProbe(parent, collector, count, send, nil)
}

func measureMessagesWithProbe(parent context.Context, collector *chat.Collector, count int, send func(context.Context) (string, error), probe func(context.Context) (map[string]float64, error)) (report MessageReport, err error) {
	if collector == nil || send == nil || count < 1 || count > 20 {
		report.Failure = "invalid_workload"
		return report, errors.New("invalid message workload")
	}
	values := make([]float64, 0, count*100)
	for i := 0; i < count; i++ {
		if i == 0 {
			if probe != nil {
				report.ServerBefore, err = probe(parent)
				if err != nil {
					report.Failure = "probe_before"
					return report, errors.New("server latency probe unavailable")
				}
			}
			report.PresenceBeforeFirst = collector.PresenceCount()
			report.AuxiliaryBeforeFirst = collector.AuxiliaryCounts()
		}
		ctx, cancel := context.WithTimeout(parent, 5*time.Second)
		started := time.Now()
		if collector.Begin(started) != nil {
			report.Failure = "observation_start"
			cancel()
			return report, errors.New("message observation already active")
		}
		id, sendErr := send(ctx)
		report.ReceiptMillis = append(report.ReceiptMillis, float64(time.Since(started))/float64(time.Millisecond))
		if sendErr != nil {
			report.Failure = "send"
			var status *chat.ReceiptError
			if errors.As(sendErr, &status) {
				report.HTTPStatus = status.StatusCode
			}
			cancel()
			return report, errors.New("synthetic message send failed")
		}
		result, finishErr := collector.FinishDetailed(ctx, id)
		samples, duplicates := result.Samples, result.Duplicates
		if len(result.Ages) > 0 {
			ages := make([]float64, 0, len(result.Ages))
			for _, age := range result.Ages {
				ages = append(ages, float64(age)/float64(time.Millisecond))
			}
			report.CreatedMillis = append(report.CreatedMillis, float64(result.CreatedAfter)/float64(time.Millisecond))
			report.EventAges = append(report.EventAges, summarizeMessages(ages))
		}
		if i == 0 {
			if probe != nil {
				report.ServerAfter, err = probe(parent)
				if err != nil {
					report.Failure = "probe_after"
					cancel()
					return report, errors.New("server latency probe unavailable")
				}
			}
			report.PresenceDuringFirst = collector.PresenceCount() - report.PresenceBeforeFirst
			counts := collector.AuxiliaryCounts()
			for j := range counts {
				report.AuxiliaryDuringFirst[j] = counts[j] - report.AuxiliaryBeforeFirst[j]
			}
		}
		cancel()
		report.Duplicates += duplicates
		if finishErr != nil || duplicates != 0 {
			report.Failure = "fanout"
			if finishErr == nil {
				report.Failure = "duplicates"
			}
			return report, errors.New("message fanout incomplete or duplicated")
		}
		report.Messages++
		batch := make([]float64, 0, len(samples))
		for _, sample := range samples {
			batch = append(batch, float64(sample)/float64(time.Millisecond))
		}
		values = append(values, batch...)
		report.Batches = append(report.Batches, summarizeMessages(batch))
	}
	report.Deliveries = summarizeMessages(values)
	return report, nil
}
