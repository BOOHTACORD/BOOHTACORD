# Native Android component layout

On reconciled source `a9392e4c0c1b2f775c36d707e49b1ff758c09f33`, an Android 35
emulator ran the actual Flutter voice participant widget at a 320 dp width and
text scale 2 using the product theme. The local test source is
`native_test.dart.txt`. It verified a single column, a card width of at least
260 dp and that the second card becomes reachable by scrolling. The test and
driver exited 0.

The 1080x1920 synthetic screenshot was inspected at original resolution:
the first card and labels are readable and the next card is partially below
the viewport; scrolling was checked by the test. Screenshot SHA-256:
`5025606a2f2986bf4491969f1992a9426f1e52f5e419611ae200d9a8916f8406`.

This is an isolated component rendered on an emulator with a synthetic room,
not a real-server voice join, physical device, screen-reader, iOS or media
acceptance. The full local feature gate and remaining gallery remain open.
Earlier wrappers stalled on a cached test target; a new target was used for
this completed run, so those earlier attempts are not counted as passes.
