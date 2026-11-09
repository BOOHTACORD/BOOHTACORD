# Issue 648: explicit leave during Android voice recovery

2026-11-09. Integrated source `be97f71727a6d263390ebe13c30ad93228c71760`;
Android 15 emulator; isolated local API/PostgreSQL/LiveKit and synthetic account.
After ten stable listener samples, the owner-checked controller stopped the
isolated SFU. The Flutter integration driver observed `reconnecting`, located
the actual control by tooltip `Выйти из голосового канала` and tapped it.
The selected voice channel became null and recovery was inactive. After the
leave marker the controller restarted the owned SFU; for 90 one-second samples
after leaving, the channel stayed null. The driver and controller exited 0.

The 1080 x 2400 post-observation screenshot was inspected at original
resolution: the voice dock and selected-channel marker were absent. SHA-256
`baf971810b28224fa923d269911b4ca9552a3006156c8c16bbb34cfd664e7434`.
The 90-second period begins with leaving; the SFU restart took place during
that interval, so it is not a measured 90 seconds after SFU readiness. The
scripts used are preserved alongside this report. The test uses mock local
preferences and secure storage, and no production account.

This is an emulator/UI cancellation check, not proof for logout, handoff,
ban, other devices, physical audio or the full issue. Temporary reverses and
test app were removed; the owned stack stopped. No deployment was performed.
