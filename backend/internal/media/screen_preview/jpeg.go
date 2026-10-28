package screenpreview

import (
	"bytes"
	"errors"
	"image/jpeg"
)

const (
	MaxJPEGBytes     = 14 * 1024
	MaxPreviewWidth  = 480
	MaxPreviewHeight = 320
	MaxPreviewPixels = MaxPreviewWidth * MaxPreviewHeight
)

var ErrInvalidJPEG = errors.New("invalid screen preview JPEG")

func ValidateJPEG(body []byte) error {
	if len(body) == 0 || len(body) > MaxJPEGBytes || !validateJPEGContainer(body) {
		return ErrInvalidJPEG
	}
	config, err := jpeg.DecodeConfig(singleByteReader{bytes.NewReader(body)})
	if err != nil || config.Width < 1 || config.Height < 1 || config.Width > MaxPreviewWidth || config.Height > MaxPreviewHeight || config.Width*config.Height > MaxPreviewPixels {
		return ErrInvalidJPEG
	}
	reader := singleByteReader{bytes.NewReader(body)}
	frame, err := jpeg.Decode(reader)
	if err != nil || frame.Bounds().Dx() != config.Width || frame.Bounds().Dy() != config.Height || reader.reader.Len() != 0 {
		return ErrInvalidJPEG
	}
	return nil
}

type singleByteReader struct{ reader *bytes.Reader }

func (reader singleByteReader) Read(value []byte) (int, error) { return reader.reader.Read(value) }
func (reader singleByteReader) ReadByte() (byte, error)        { return reader.reader.ReadByte() }
