# Issue 687: component-only Web settings review

Windows Chromium rendered the isolated settings fixture at 1440 px and 393 px.
With the flag off, the DeepFilterNet option was absent. With the flag on, the
option could be selected and the CPU/latency warning was visible. Automated
tests passed for both widths in both configurations. This fixture did not
connect to a server or process microphone audio.

Source-resolution screenshots were inspected. At 393 px, the initial layout
split the noise-suppression label and truncated the selected option. The final
layout stacks the label and select at narrow widths, with the warning on its
own line. At 1440 px, the default screenshot hash was unchanged across this
specific CSS adjustment. This comparison is against the pre-adjustment
fixture, not a pristine master build.

| Fixture screenshot | SHA-256 |
| --- | --- |
| Before mobile adjustment, default 1440 px | `42facc6bcc3dfdea6a05b1a4c9856002472feb94e2c629fcb158e8a5ef67b3c2` |
| Before mobile adjustment, default 393 px | `3a6d0a4f75c8c72d91fead300ec0c28fbd7a6d5d7d2e7c2ecbec089e9f2b612a` |
| After adjustment, default 1440 px | `42facc6bcc3dfdea6a05b1a4c9856002472feb94e2c629fcb158e8a5ef67b3c2` |
| After adjustment, default 393 px | `857f5fdada7c13f91e4085cc9db2a0d4f0e6e231ef3f45e8bde46997de3711ba` |
| After adjustment, opt-in 1440 px | `e738306795dc750757625810c6da843d6dd72d718fc8a46311aa14a459814b36` |
| After adjustment, opt-in 393 px | `6616d0565aee66e51d9a99c945b58eaf5bd23cf512fb7c9c70f5cd581276b686` |

The authenticated real-stack gate and its before/after visual review remain
BLOCKED while the isolated WSL/Docker environment is unavailable. Component
screenshots do not satisfy native, real-stack or release acceptance.
