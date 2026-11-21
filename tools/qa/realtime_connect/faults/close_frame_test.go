package main

import "testing"

func TestCloseFrameWatchIgnoresPayloadAndSupportsFragmentation(t *testing.T) {
	var w closeFrameWatch
	if w.feed([]byte{0x81, 2, 0x88, 0x80}) {
		t.Fatal("payload mistaken for close")
	}
	if w.feed([]byte{0x88}) {
		t.Fatal("incomplete header accepted")
	}
	if !w.feed([]byte{0x80, 0, 0, 0, 0}) {
		t.Fatal("fragmented masked close missed")
	}
}
