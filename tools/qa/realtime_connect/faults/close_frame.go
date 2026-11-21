package main

import "encoding/binary"

// Observe frame boundaries only; never retain payloads or change forwarded bytes.
type closeFrameWatch struct {
	header    []byte
	remaining uint64
}

func (w *closeFrameWatch) feed(data []byte) bool {
	closed := false
	for len(data) > 0 {
		if w.remaining > 0 {
			count := uint64(len(data))
			if count > w.remaining {
				count = w.remaining
			}
			data = data[int(count):]
			w.remaining -= count
			continue
		}
		w.header = append(w.header, data[0])
		data = data[1:]
		if len(w.header) < 2 {
			continue
		}
		size := w.header[1] & 127
		needed := 2
		if size == 126 {
			needed = 4
		}
		if size == 127 {
			needed = 10
		}
		if len(w.header) < needed {
			continue
		}
		length := uint64(size)
		if size == 126 {
			length = uint64(binary.BigEndian.Uint16(w.header[2:]))
		}
		if size == 127 {
			length = binary.BigEndian.Uint64(w.header[2:])
		}
		if w.header[0]&15 == 8 {
			closed = true
		}
		w.remaining = length
		if w.header[1]&128 != 0 {
			w.remaining += 4
		}
		w.header = nil
	}
	return closed
}
