# Native profile revision acceptance (#276)

Runs the production Flutter application against an owned loopback HTTPS Go API, PostgreSQL and synthetic single guild. Requires the dedicated Android QA AVD or an explicitly named QA iOS simulator.

```sh
python3 -m tools.qa.profile_revision.run --platform android --device emulator-5554
python3 -m tools.qa.profile_revision.run --platform ios --device 82C26E13-0F1F-43F9-AF27-866DC22C2456
```

The runner owns default local QA ports 4810, 4812, 4820 and LiveKit ports. Do not run another default Stack concurrently. Independent workers must allocate their own ports and build directories. SDK and Docker context currently follow this macOS workstation's installed QA environment.

It creates two MEMBER accounts using a real ADMIN session, updates names and protected avatars from independent authenticated sessions, and holds actual finite HTTP replies to check profile revision ordering. Streaming responses are forwarded unchanged. Same-application logout/login checks clear revision state and reject avatar replies from the previous session. Blocking one synthetic account and anonymous reads check the server-side avatar ACL.

Credentials and the certificate pin are provided through a temporary mode-0600 Dart defines file. The stack is removed in finally. Never publish this temporary file, raw payloads or screenshot binaries. Reports contain generic phases, revision values, status codes and local screenshot SHA256 receipts. Review actual screenshots before accepting visual evidence.

Outputs are ignored local artifacts under `.out/qa276-20261012/<platform>/`. A FAIL or missing screenshot is not acceptance. Emulator coverage does not establish physical media, OS notification or OS screen-reader capability.
