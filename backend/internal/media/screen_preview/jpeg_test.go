package screenpreview

import (
	"bytes"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"testing"
)

func testJPEG(t *testing.T, width, height int) []byte {
	t.Helper()
	frame := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			frame.SetRGBA(x, y, color.RGBA{R: uint8(x), G: uint8(y), B: 90, A: 255})
		}
	}
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, frame, &jpeg.Options{Quality: 35}); err != nil {
		t.Fatal(err)
	}
	return encoded.Bytes()
}

func TestValidateJPEGAcceptsSmallLandscapeAndPortraitFrames(t *testing.T) {
	for _, size := range [][2]int{{160, 90}, {90, 160}} {
		if err := ValidateJPEG(testJPEG(t, size[0], size[1])); err != nil {
			t.Fatalf("%dx%d rejected: %v", size[0], size[1], err)
		}
	}
}

func TestValidateJPEGAcceptsHigherResolutionLandscapeAndPortraitPreviewFrames(t *testing.T) {
	for _, size := range [][2]int{{480, 270}, {180, 320}} {
		if err := ValidateJPEG(testJPEG(t, size[0], size[1])); err != nil {
			t.Fatalf("%dx%d preview rejected: %v", size[0], size[1], err)
		}
	}
}

func TestValidateJPEGRejectsMalformedOversizedDimensionBombAndPolyglot(t *testing.T) {
	cases := map[string][]byte{
		"malformed":       []byte("<svg onload=alert(1) />"),
		"oversized":       make([]byte, MaxJPEGBytes+1),
		"dimension bomb":  testJPEG(t, MaxPreviewWidth+1, 32),
		"polyglot suffix": append(testJPEG(t, 64, 64), []byte("<html>secret</html>")...),
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			if err := ValidateJPEG(body); err == nil {
				t.Fatal("unsafe JPEG was accepted")
			}
		})
	}
}

func TestNormalizeJPEGKeepsServerCaptureInsidePrivatePreviewContract(t *testing.T) {
	frame := image.NewRGBA(image.Rect(0, 0, MaxPreviewWidth, MaxPreviewHeight))
	for y := 0; y < frame.Bounds().Dy(); y++ {
		for x := 0; x < frame.Bounds().Dx(); x++ {
			frame.SetRGBA(x, y, color.RGBA{R: uint8(x * 255 / MaxPreviewWidth), G: uint8(y * 255 / MaxPreviewHeight), B: uint8((x + y) % 256), A: 255})
		}
	}
	var source bytes.Buffer
	if err := jpeg.Encode(&source, frame, &jpeg.Options{Quality: 95}); err != nil {
		t.Fatal(err)
	}
	normalized, err := NormalizeJPEG(source.Bytes())
	if err != nil || ValidateJPEG(normalized) != nil || len(normalized) > MaxJPEGBytes {
		t.Fatalf("normalized size=%d validation=%v err=%v", len(normalized), ValidateJPEG(normalized), err)
	}
	if _, err := NormalizeJPEG([]byte("not-a-jpeg")); !errors.Is(err, ErrInvalidJPEG) {
		t.Fatalf("invalid source error=%v", err)
	}
}
