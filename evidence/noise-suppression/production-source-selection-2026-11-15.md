# Production source selection for issue 687

The official Xiph GitHub release asset rnnoise-0.2.tar.gz was downloaded from
https://github.com/xiph/rnnoise/releases/tag/v0.2. Its SHA256 is
90fce4b00b9ff24c08dbfe31b82ffd43bae383d85c5535676d28b0a2b11c0d37.
The complete distribution contains src/rnnoise_data.c, src/rnnoise_data.h and
COPYING. COPYING grants redistribution in source/binary form under BSD-3-Clause
and names Jean-Marc Valin, Amazon, Mozilla, Xiph.Org and Mark Borgerding.

The release source/model and notice hashes are pinned in
tools/audio/release_source/lock.json. Every extracted source file is compared
with the authenticated archive when a cached tree is reused; added or changed
files are rejected. Corrupt archives/notices, traversal and cache injection have
focused passing tests. The archive was extracted and verified locally.

Important distinction: the model C hash in this complete official distribution
is dece58eabca6a722a0bd9dbc8dfadba27abac1271760fad65e1071f54717dc78.
It is not the research model 522b6a64fded05bf85e58c06206eafe57ce7d94f3af58c725b17628b481d7890
downloaded separately from media.xiph.org. The header hash is identical.
Research measurements cannot be relabeled as acceptance of this release model.

Licensing basis is the complete upstream source distribution and its included
COPYING, including generated model C source. This is the engineering reading
of the package-level grant, not an additional model-specific statement from
the author. The separate-weight licensing question at
https://github.com/xiph/rnnoise/issues/284 remains open as of this check. No
third-party assertion or training-data CC0 notice is used as a substitute.
Retain the complete original COPYING and model/source provenance in every
delivered native and Web package. Do not ship the separate research archive.

Pinned DeepFilter source revisions retain upstream's MIT/Apache-2.0 choice;
the original LICENSE, LICENSE-MIT and LICENSE-APACHE will be delivered together
with model provenance and transitive notices. Full package/notice verification,
actual runtime acceptance and release delivery are separate open gates.
