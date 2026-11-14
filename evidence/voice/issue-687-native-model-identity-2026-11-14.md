# Issue 687: compiled native RNNoise identity

The plugin now exposes `getNoiseSuppressionCapabilities` with a
`rnnoiseModelId` derived from the library's compiled backend, independently
of requested/effective processing mode. This identifies the compiled model;
it does not prove initialization, active processing, acceptable load or rights.

The new native test first failed to compile before the identity API existed.
After implementation, all 23 default MSVC Release CTests passed, reporting
`rnnoise-stock-v0.1`. A separate source-verified local v0.2 library passed the
same identity test with `rnnoise-stock-v0.2`. Switching off/browser/rnnoise
does not change the compiled identity. The actual Flutter Windows debug
plugin also compiled with the new method-channel dispatcher.

No client call has yet consumed this capability as a production Auto
preflight. Actual method-channel execution, load measurement, signed model
delivery and acoustic acceptance remain open. No model was published and
no server deployment occurred.
