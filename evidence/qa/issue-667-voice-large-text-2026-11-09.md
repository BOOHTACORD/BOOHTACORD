# Issue 667: Flutter voice cards with large text

At 320 x 480 logical pixels with 200% text and five participants, the
component capture on base `c96af5782b34d968fbc43de831cf816840316de5` shows
two 138-pixel cards per row. Voice text wraps awkwardly and the screen preview
placeholder is shrunk. A focused widget test failed on that base because the
first card measured 138 rather than at least 260 logical pixels; its 100%
case passed.

The changed layout uses one column when a compact two-column card would be
narrower than 128 times the text scale. The 100% 320-pixel case still has two
columns. The test checks that the next participant can be scrolled into a
hit-testable position. Dart analysis and 21 focused and adjacent Flutter tests
passed. The 320 x 480, five-participant component capture was individually
reviewed at source resolution: the first card fills the width and its voice
label is legible; the next card begins below it. After extracting the column
policy, the repeated capture had the same SHA-256.

Before SHA-256:
`230ca8562fe8e6db8e7fe3313a4bf3149251dbd39c645dee44daef37e9f7ebb8`.
After SHA-256:
`f53541c0924c47348cef457acdbb41c7471ab59cd3ceff7959d3f481d1c92396`.

This is a component-level check. The full local-feature gate, native runtime,
screen reader, physical device, broader 667 matrix and production are not
accepted by this record. No screenshot baseline was approved.
