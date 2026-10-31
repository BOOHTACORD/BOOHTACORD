package uploadrequest

import (
	"net/http/httptest"
	"time"
)

type deadlineRecorder struct{ *httptest.ResponseRecorder }

// Synthetic complete-body tests only; real socket tests use the native writer.
func newDeadlineRecorder() *deadlineRecorder              { return &deadlineRecorder{httptest.NewRecorder()} }
func (*deadlineRecorder) SetReadDeadline(time.Time) error { return nil }
