# Physical notice paths in Windows packages

Windows publication 43712394808 built the application and installer, then
stopped before publication: the ZIP lacked the indexed path
`half-2.4.1/licenses/Apache-2.0.txt`. The file was physically present under
`LICENSES/Apache-2.0.txt`. Both original source notices have identical hashes.

The collector explicitly visited `LICENSES` and `licenses`. On Windows those
names address the same directory; the index acquired two aliases while the
filesystem and PowerShell ZIP retained one physical spelling. The regression
failed for upper, lower and mixed-case directory spellings before the fix.

The collector now enumerates actual directories once and preserves their
physical names. Five focused collector tests pass, including exact ZIP path
and digest readback. The actual cached Cargo metadata for 161 packages was
processed into a new notice directory and archived with the same PowerShell
`Compress-Archive` used by the publisher. All 339 indexed notice paths and
SHA256 values match that archive. The former count of 341 included two aliases;
no original license text was removed. Unresolved licenses remain empty.

Scope: only the notice collector and notice archive were rebuilt and tested.
The DSP libraries, Flutter application and server were not rebuilt for this
diagnosis. Ordinary native builds use a new qualified cache directory so the
previous alias index cannot be reused. Original cache data is preserved.

The replacement source identity is 1.0.58+94/r73. Existing Windows 1.0.56 and
1.0.57 tags remain unchanged; neither failed attempt published public assets.
Web stays 1.0.56/r64. No Android/macOS release or catalog promotion is included.
Mandatory GitHub checks and the replacement publisher remain pending.
