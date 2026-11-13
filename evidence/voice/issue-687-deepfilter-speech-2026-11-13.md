# Issue 687: offline DeepFilterNet speech fixture

The eight public CC0 Russian inputs identified in
`issue-687-speech-inputs-2026-11-13.md` were processed offline with the local
research WASM/model identified in `issue-687-deepfilternet-browser-2026-11-13.md`.
Input gain was unchanged; each output has frame padding plus 12 tail frames.
No sample exceeded unit amplitude in these eight outputs. Files stay outside
version control. Output float32le SHA-256 in input order:

1. `62a404ce68fa5e0bae6efb116b1fe281cc24d3621046b5fbdc3a1fb4ee2b0939`
2. `33c0ae797eafe2847fe117b28bfefbe353a993f6e94ab22ce05d79948aef0688`
3. `2bc89c7a79680669a9470fa46cacc5ce357ec2c4cd503dc42ef1f7cc3f2aeeac`
4. `460a169affb1df2725456de3c2e647d4cc7d5417770760e74096881e0a8af899`
5. `dd9f847371031a0f530465d55653aa730ea3ec07858f03aa8965ea94bdf2835a`
6. `266a18b71263029f01d3bbeacf84a351f0a567fb7fc8a219c82251ccb36cd03a`
7. `f3e88c411a9db939bbc7c031b630dace2a6151d8f416b01ac0308824e0152c81`
8. `0665e652ff02af17deef1e8950b7b54a878dda4eee8b53bc4d2ea8062668df78`

After shifting the output by 1440 samples, the synthetic correlation lag,
dry-input Pearson correlation min/median/max was 0.8828/0.9969/0.9994.
This exploratory statistic is not speech intelligibility or evidence against
cut words. These clips are not a balanced quiet/noisy corpus; listening,
device, latency and release acceptance all remain NOT_RUN.
