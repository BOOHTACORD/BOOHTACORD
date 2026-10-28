# Merge preparation for PR #590

Owner request: merge the implemented corrections into master and close the corresponding tasks. #584 has no implementation and remains open. Closing the four implementation scopes does not mark physical/native or release gates PASS.

Initial PR head `caeec06115c850c5b58ca521e36ec030f0c6be7e`, CI run `40754126616`, exposed two integration omissions:

- `contracts / contracts` required updated Web/iOS/Android regression decisions for changed shared `shell` paths. The parity validator also selects `admin`, `chat`, `screen` and `support`; their records now describe the actual changes, unchanged platform behavior and outstanding physical checks. No platform runtime was promoted to PASS.
- `flutter / dart` completed application/vendor tests and analysis, then rejected capture publication. Nine new synthetic regression PNGs were produced, while the finite allowlist still described 152 captures. Both measurement and publication now consume the explicit nine-name addition, giving 161 mandatory captures. Missing names and unknown uploaded images remain rejected. This does not weaken privacy, freshness or source checks.

Before the correction, the new focused capture-inventory regression failed because the required names were absent. Afterward, 24 focused artifact/publication/parity tests passed, and `tools.verify.client_parity.run --base origin/master` passed. No application behavior changed in this CI repair.

Required merge sequence: obtain passing required CI for the repaired exact head, leave draft state, merge using the expected head SHA, verify master contains the merge, then close #585/#586/#587/#589 with the merge and validation links. Preserve physical Gboard/touch/image checks in #303/#62 and real-stack context acceptance in #240/#241. Keep #584 and all incomplete parent gates open. Hosted CI and merge results are read back live; this preparation record alone does not assert completion.

The next contracts pass reached the Dart dependency validator and caught a UI-layer placement error: the dialog adapter imports `AppState`, so it belongs in `widgets/attachment_revocation`, alongside its owning `message_attachment_list`, rather than under feature owners. The file was physically moved, relative imports and the exact caller were rewired, and the feature coverage path follows the widget leaf. Its behavior is preserved; the feature/UI boundary validator remains unchanged.
