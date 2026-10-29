package screenpreview

import (
	"bytes"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
)

const (
	MaxJPEGBytes     = 14 * 1024
	MaxPreviewWidth  = 480
	MaxPreviewHeight = 320
	MaxPreviewPixels = MaxPreviewWidth * MaxPreviewHeight
	maxCaptureWidth  = 3840
	maxCaptureHeight = 2160
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

// NormalizeJPEG enforces the existing private-preview wire contract on frames
// produced by Egress. It lowers encoding quality first, then dimensions, so
// ordinary screenshots stay crisp while pathological desktop frames remain
// bounded in memory and on the API response path.
func NormalizeJPEG(body []byte) ([]byte, error) {
	if len(body) == 0 || len(body) > 5*1024*1024 || !validateJPEGContainer(body) {
		return nil, ErrInvalidJPEG
	}
	config, err := jpeg.DecodeConfig(singleByteReader{bytes.NewReader(body)})
	if err != nil || config.Width < 1 || config.Height < 1 || config.Width > maxCaptureWidth || config.Height > maxCaptureHeight || config.Width*config.Height > maxCaptureWidth*maxCaptureHeight {
		return nil, ErrInvalidJPEG
	}
	frame, err := jpeg.Decode(singleByteReader{bytes.NewReader(body)})
	if err != nil || frame.Bounds().Empty() {
		return nil, ErrInvalidJPEG
	}
	width, height := frame.Bounds().Dx(), frame.Bounds().Dy()
	if width > MaxPreviewWidth || height > MaxPreviewHeight {
		scale := min(float64(MaxPreviewWidth)/float64(width), float64(MaxPreviewHeight)/float64(height))
		width, height = max(1, int(float64(width)*scale)), max(1, int(float64(height)*scale))
		frame = resizeBilinear(frame, width, height)
	}
	current := frame
	for width > 0 && height > 0 {
		for _, quality := range []int{74, 62, 50, 38, 28, 20} {
			var encoded bytes.Buffer
			if err := jpeg.Encode(&encoded, current, &jpeg.Options{Quality: quality}); err != nil {
				return nil, ErrInvalidJPEG
			}
			if encoded.Len() <= MaxJPEGBytes {
				return encoded.Bytes(), nil
			}
		}
		if width == 1 && height == 1 {
			break
		}
		width = max(1, width*4/5)
		height = max(1, height*4/5)
		current = resizeBilinear(current, width, height)
	}
	return nil, ErrInvalidJPEG
}

func resizeBilinear(source image.Image, width, height int) *image.RGBA {
	bounds := source.Bounds()
	destination := image.NewRGBA(image.Rect(0, 0, width, height))
	sourceWidth, sourceHeight := bounds.Dx(), bounds.Dy()
	for y := 0; y < height; y++ {
		sy := (float64(y)+0.5)*float64(sourceHeight)/float64(height) - 0.5
		y0 := max(0, min(sourceHeight-1, int(sy)))
		y1 := min(sourceHeight-1, y0+1)
		fy := max(0, min(1, sy-float64(y0)))
		for x := 0; x < width; x++ {
			sx := (float64(x)+0.5)*float64(sourceWidth)/float64(width) - 0.5
			x0 := max(0, min(sourceWidth-1, int(sx)))
			x1 := min(sourceWidth-1, x0+1)
			fx := max(0, min(1, sx-float64(x0)))
			c00 := color.RGBAModel.Convert(source.At(bounds.Min.X+x0, bounds.Min.Y+y0)).(color.RGBA)
			c10 := color.RGBAModel.Convert(source.At(bounds.Min.X+x1, bounds.Min.Y+y0)).(color.RGBA)
			c01 := color.RGBAModel.Convert(source.At(bounds.Min.X+x0, bounds.Min.Y+y1)).(color.RGBA)
			c11 := color.RGBAModel.Convert(source.At(bounds.Min.X+x1, bounds.Min.Y+y1)).(color.RGBA)
			destination.SetRGBA(x, y, color.RGBA{
				R: bilinear(c00.R, c10.R, c01.R, c11.R, fx, fy),
				G: bilinear(c00.G, c10.G, c01.G, c11.G, fx, fy),
				B: bilinear(c00.B, c10.B, c01.B, c11.B, fx, fy), A: 0xff,
			})
		}
	}
	return destination
}

func bilinear(c00, c10, c01, c11 uint8, x, y float64) uint8 {
	top := float64(c00)*(1-x) + float64(c10)*x
	bottom := float64(c01)*(1-x) + float64(c11)*x
	return uint8(top*(1-y) + bottom*y + 0.5)
}

type singleByteReader struct{ reader *bytes.Reader }

func (reader singleByteReader) Read(value []byte) (int, error) { return reader.reader.Read(value) }
func (reader singleByteReader) ReadByte() (byte, error)        { return reader.reader.ReadByte() }
