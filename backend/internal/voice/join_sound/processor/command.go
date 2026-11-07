package soundprocessor

import (
	"bytes"
	"context"
	"errors"
	"os/exec"
)

type bounded struct {
	bytes.Buffer
	max int
}

func (b *bounded) Write(p []byte) (int, error) {
	if len(p) > b.max-b.Len() {
		return 0, errors.New("processor output limit")
	}
	return b.Buffer.Write(p)
}
func command(ctx context.Context, name string, args ...string) ([]byte, []byte, error) {
	out, diagnostic := &bounded{max: 300000}, &bounded{max: 32768}
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdout = out
	cmd.Stderr = diagnostic
	err := cmd.Run()
	return out.Bytes(), diagnostic.Bytes(), err
}
