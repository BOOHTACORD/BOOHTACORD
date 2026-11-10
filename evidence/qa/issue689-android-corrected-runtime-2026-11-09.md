# Issue 689: Android runtime retry on the local stack

- Source at execution: HEAD `72928320db20baa1ca7c9810d5a7bafe7e8a7533`, dirty worktree SHA-256 `4fa00f08e1e6309daf57f7b0e0f34f1c516b5a85ec4743d819599b8fdbc9b73d`. Each target completed with matching source fingerprints before and after; this is not an immutable release build.
- The full registered gate `.out/local-features/20261109-152119/` remains FAIL: 1832 Flutter tests passed with three skips, component captures 724 passed with one skip, and four runtime attempts failed before application launch because the wrong Docker CLI was selected. Source stability passed. A first individual retry found BuildKit was disabled; that failure is retained separately.
- With the task-local Linux Docker CLI, its buildx plugin and BuildKit enabled, four individual native targets passed on owned AVD `BOOHTACORD_QA_ISSUE689` (`emulator-5554`) using disposable local services, pinned TLS and no mocked application components: `local_qa_test`, `issue689_listener_test`, `issue689_roster_test`, and `update_required_test`.
- These receipts cover authentication/workspace/settings/logout, real SFU listener across app socket recovery, public/auth maintenance handoff and empty roster reconnect, and a required update from a synthetic catalog. They do not prove a physical device, actual transmitted microphone audio, media quality, updater installation or an installed old-client transition.
- The previous full feature-gate result is not overwritten. All owner-labelled containers, networks, images and volumes from these four retries and the failed BuildKit attempt were independently checked absent.

## Visual review

- All 14 local-QA screenshots were individually inspected at 1080×1920. Authentication, navigation, status, search, audio, profile and administration labels are legible. The gray system strip remains at the bottom; long admin and advanced-audio views extend beyond the capture and a screenshot does not establish scrolling to every control. The support prompt begins at the left edge; this observation does not establish a regression.
- Three roster screenshots were inspected at 1080×1920: the maintenance warning is legible; the initial lower form extends behind the system strip, and the address/version are visible after scrolling. The roster image shows an empty synthetic voice channel.
- The listener image shows connected voice, one synthetic participant, a muted microphone indicator and visible controls. The required-update image shows legible title, explanation and update action; no installer was launched. No screenshot baseline was approved.

## Screenshot SHA-256

- `local_qa_test/native-admin.png`: `a868b112f7f979fc12436e4e50338de13f73efbb98df8d049ad2fc6b72a70444`
- `local_qa_test/native-audio-advanced.png`: `b2968afd9562be366597836347943a3cff9b852c41775ba59829d27e0a9278ec`
- `local_qa_test/native-audio.png`: `964396dfd02bcc77fcf4171c5f740b636294dbe6cf157c70cc525e35c3a2350e`
- `local_qa_test/native-auth.png`: `f2b9639c47c3d7dfcffb9cd057815eb451875596d975af1cd7946cbdd751178f`
- `local_qa_test/native-channel-favorites.png`: `ffa8e5c88315655a5c226ccf3a3adbd15ba843b4fbdbbd20078886b98542a5ed`
- `local_qa_test/native-connection-status.png`: `dce5f83869407113e30bb3fe4369c7d71a3baa5db2dde3718307009c34ee10bb`
- `local_qa_test/native-context-search.png`: `98cd3d834d7be04d5798dc74c8e6c107a92ab96f0837cf921bf5239f30b05243`
- `local_qa_test/native-navigation.png`: `47e0ed60310626616625693786dcffafe3c5880a831625775e195766aaae9f6c`
- `local_qa_test/native-profile.png`: `e7594ea8e5fea3779d8a8f1051a9186c0a9059615211c85cd18d7ebf294ca5fc`
- `local_qa_test/native-public-support-default.png`: `8104d86313b824c8709c1838022d8cd5d621f7fd91b6188d1fc64c8529557952`
- `local_qa_test/native-screen-motion-independent-fps.png`: `f9d384f76986d8bf0747b28e1f9530f13ce95af28628b707c4afd06d775cc2c4`
- `local_qa_test/native-screen-text-independent-fps.png`: `945348dc6f089aaa26e0d1bfb12f6169037df86d69c5968f43020561d5c01c17`
- `local_qa_test/native-signed-out.png`: `f2b9639c47c3d7dfcffb9cd057815eb451875596d975af1cd7946cbdd751178f`
- `local_qa_test/native-workspace.png`: `8104d86313b824c8709c1838022d8cd5d621f7fd91b6188d1fc64c8529557952`
- `issue689_roster_test/android-maintenance-unknown-scrolled.png`: `7dd2ac4c5df99358ee219287bb181571d84f7af590adb7cc716711b2b8bbd697`
- `issue689_roster_test/android-maintenance-unknown.png`: `c8ac73db6ea0fd57e0a0fe60eae4c38283ca6be8b759d821add8588a7676efd7`
- `issue689_roster_test/android-roster-socket.png`: `579fca780bde768509bf81c1d130be5058811fad27f0af059b21efcdc823f931`
- `issue689_listener_test/android-listener-realtime-recovered.png`: `ad5695a77f467c30770108b8591d0034edda47daa131941e88db2bc93cbdff5d`
- `update_required_test/android-required-update.png`: `72de8175ceffe5004355e1d8047fd6ee940c2d447bcbdb221efd5e9eb8221794`
