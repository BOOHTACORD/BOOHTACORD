package loadkeys

import (
	"bytes"
	"encoding/base64"
	"os"
	"path/filepath"
	"testing"
)

func TestKeyFileIsBoundedAndErrorsDoNotExposePath(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operator-key")
	key := bytes.Repeat([]byte{7}, 32)
	if err := os.WriteFile(path, []byte(base64.RawURLEncoding.EncodeToString(key)), 0600); err != nil {
		t.Fatal(err)
	}
	got, err := Load32(path)
	if err != nil || !bytes.Equal(got, key) {
		t.Fatal("key read failed")
	}
	if err = os.WriteFile(path, bytes.Repeat([]byte{'x'}, 2000), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = Load32(path); err == nil || bytes.Contains([]byte(err.Error()), []byte(path)) {
		t.Fatal("unbounded key or path exposed")
	}
	if _, err = Load32(""); err == nil {
		t.Fatal("missing key accepted")
	}
}
