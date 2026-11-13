package httpmetrics

import (
	"context"
	"errors"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	ErrAttachmentFilesystemAlreadyRegistered = errors.New("attachment filesystem metric source already registered")
	ErrInvalidAttachmentFilesystemSource     = errors.New("invalid attachment filesystem metric source")
)

type AttachmentFilesystemSnapshot struct{ AvailableBytes, TotalBytes int64 }

type AttachmentFilesystemSource interface {
	Snapshot(context.Context) (AttachmentFilesystemSnapshot, error)
	ReservedBytes() int64
}

type attachmentFilesystemCollector struct {
	available, reserved, success, total *prometheus.Desc
	source                              AttachmentFilesystemSource
}

func newAttachmentFilesystemCollector(source AttachmentFilesystemSource) attachmentFilesystemCollector {
	return attachmentFilesystemCollector{
		available: prometheus.NewDesc("voice_platform_attachment_filesystem_available_bytes", "Available bytes on the private attachment filesystem.", nil, nil),
		reserved:  prometheus.NewDesc("voice_platform_attachment_upload_reserved_bytes", "Bytes reserved for in-flight attachment uploads.", nil, nil),
		success:   prometheus.NewDesc("voice_platform_attachment_filesystem_snapshot_success", "Whether the current private attachment filesystem snapshot succeeded.", nil, nil),
		total:     prometheus.NewDesc("voice_platform_attachment_filesystem_total_bytes", "Total bytes on the private attachment filesystem.", nil, nil),
		source:    source,
	}
}

func (collector attachmentFilesystemCollector) Describe(descriptions chan<- *prometheus.Desc) {
	descriptions <- collector.available
	descriptions <- collector.reserved
	descriptions <- collector.success
	descriptions <- collector.total
}

func (collector attachmentFilesystemCollector) Collect(metrics chan<- prometheus.Metric) {
	snapshot, err := collector.source.Snapshot(context.Background())
	available, total, success := snapshot.AvailableBytes, snapshot.TotalBytes, 1.0
	if err != nil || available < 0 || total < 0 || available > total {
		available, total, success = 0, 0, 0
	}
	metrics <- prometheus.MustNewConstMetric(collector.available, prometheus.GaugeValue, float64(available))
	metrics <- prometheus.MustNewConstMetric(collector.reserved, prometheus.GaugeValue, float64(collector.source.ReservedBytes()))
	metrics <- prometheus.MustNewConstMetric(collector.total, prometheus.GaugeValue, float64(total))
	metrics <- prometheus.MustNewConstMetric(collector.success, prometheus.GaugeValue, success)
}

func (recorder *Recorder) RegisterAttachmentFilesystem(source AttachmentFilesystemSource) error {
	if source == nil {
		return ErrInvalidAttachmentFilesystemSource
	}
	if recorder.attachmentFilesystemRegistered {
		return ErrAttachmentFilesystemAlreadyRegistered
	}
	recorder.registry.MustRegister(newAttachmentFilesystemCollector(source))
	recorder.resourceRegistry.MustRegister(newAttachmentFilesystemCollector(source))
	recorder.attachmentFilesystemRegistered = true
	return nil
}
