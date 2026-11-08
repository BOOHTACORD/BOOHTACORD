package soundprocessor

import "testing"

func TestLevelVerificationFailsClosed(t *testing.T) {
	for _, raw := range []string{`{}`, `{"input_tp":"0","input_i":"-18"}`, `{"input_tp":"NaN","input_i":"-18"}`, `{"input_tp":"-4","input_i":"-5"}`} {
		if safeLevels([]byte(raw)) {
			t.Fatal("unsafe levels accepted")
		}
	}
	if !safeLevels([]byte(`{"input_tp":"-4","input_i":"-18"}`)) {
		t.Fatal("safe levels denied")
	}
}
