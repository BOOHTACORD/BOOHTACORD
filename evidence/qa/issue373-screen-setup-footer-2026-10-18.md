# #373 — screen setup footer in short desktop windows

Task: FV2-054; dependencies FV2-003 and FV2-053. Date: 2026-10-18 (Europe/Istanbul).
Base: c8d46934d1dfed49f8930a68ae720c227736154c. Scope: Flutter layout only; capture, codecs, API/SFU contracts unchanged.

## Regression and implementation

Focused tests were added before the production fix. The original layout produced 15 failures / 10 passes in the 25-case matrix (`.out/issue373-red.log`), including RenderFlex bottom overflows of 93px at 1008×720, 50px at 1024×768 and 146px at 800×680. Existing Windows original-resolution open captures in #373 / CI 39072141204 show the clipped footer.

The source picker now uses the existing compact arrangement at every width: one bounded scrollable source/quality section between the fixed header and footer. The remaining height comes from Expanded inside SetupSurface rather than a viewport-width heuristic. No new size threshold or overflow suppression. Empty/pending states and expanded quality controls use the same scroll surface. Mobile quality-only mode, null cancellation, inventory disposal and Escape route shortcuts remain unchanged.

The new test matrix covers 1008×720, 1024×768, minimum desktop 800×680 and 1440×900, each with pending/empty/12-source inventory at 1×/2× text. It checks all action bounds against both the visible viewport and painted dialog surface, pointer hit testing, selection of the twelfth source, scrolling to and editing quality/content mode, fixed footer position and cancellation. A separate 800×680/2× keyboard test applies edited quality. Tests account for the first ExpansionTile animation frame before measuring reachability.

## Local verification

- Screen setup suite: 73 PASS after the layout fix. The registered feature component run also checks the strengthened final geometry assertions.
- Full Flutter unit suite: 1482 PASS, 1 existing skip.
- Registered screen component suite: 155 PASS.
- Focused Flutter analyzer: PASS, no issues.
- Windows fixture validator: 2 tests PASS, including rejection of absent/false footer, quality reachability and keyboard reachability observations. Those negative checks first failed against the old validator.
- Spec traceability: PASS_INDEX_ONLY, 39 requirements; the Windows-only approved brief is unavailable on this Mac. No contract changes.

Local feature run: `.out/local-features/20261018-081159`. Invoked `python3 -m tools.qa.local_features.run --feature screen --platform android --platform ios --native-device android:emulator-5554 --native-device ios:82C26E13-0F1F-43F9-AF27-866DC22C2456 --base origin/master --real-stack` with pinned Flutter 3.47.7/Dart 3.13.5, Node 24, Python 3.12, Java 17, dedicated QA Docker context and Android platform-tools on PATH. The underlying module preserves those pins instead of the shell wrapper's host SDK PATH.

- Android API35 ARM64 emulator: PASS, actual native runtime with isolated API/SFU.
- iOS27 dedicated Simulator: PASS, actual native runtime with isolated API/SFU.
- Four command stages PASS. Raw report remains REVIEW_REQUIRED for its incidental captures; scoped visual review PASS for the five screen setup images only.

Reviewed at source resolution: Flutter mobile 393×852/2× text/IME capture (786×1704 PNG), Android motion/text setup captures (1080×2400 PNG), iOS motion/text setup captures (1206×2622 PNG). The normal native footer shows both actions fully inside the rounded dialog; the separate IME fixture intentionally retains the compact single Start action plus X. Quality, FPS and content-mode choices remain readable and scrollable under a fixed header/footer. Content crossing the scroll viewport is intentional scrolling, not a clipped action. No broad visual claim is made for unrelated report images.

## Windows release acceptance

At this local preflight record: NOT_RUN. The pull request must pass the exact-head Windows workflow before merging. The existing disposable-host release harness now verifies actual action geometry within the painted dialog, scrolling/quality selection, real Win32 Tab/Shift+Tab reachability, four Escape/focus-return cases through header/dock, and unchanged real API/PostgreSQL/LiveKit room/lease/mute state without screen publication. Initial Escape cases still run before any Tab; expanded-quality/traversal checks run in the two traversed cases. Open/footer/closed full-view captures include the modal overlay.

Final Windows CI head, synthetic merge SHA/tree, native result and original PNG review belong in the PR and issue acceptance record; this section remains the historical local preflight, not a claim that Windows already passed.

No physical device, acoustic quality, hardware capture capacity or screen-reader certification is claimed. Generated captures, runtime configuration and logs stay ignored under `.out`; no credentials or generated media are staged.
