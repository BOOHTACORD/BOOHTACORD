# Background voice dependency faults

Run on the local Unix Docker QA host, with a dedicated `BOOHTACORD_QA*`
Android emulator visible to `adb` and the pinned Flutter/Node dependencies ready:

```sh
python -m tools.qa.client_lifecycle.background_fault.run \
  --device emulator-5580 --role api --output .out/background-app-fault
python -m tools.qa.client_lifecycle.background_fault.run \
  --device emulator-5580 --role sfu --output .out/background-media-fault
```

The commands reuse the Android microphone uplink/independent browser receiver
integration target. The original runner's logs and JSON stay under `raw/`.
`fault.json` records verified container state and timestamps; `assessment.json`
is written only after the original runner and the additional media checks pass.
An existing nonempty output directory is rejected.

| Fault | Required observations |
| --- | --- |
| API paused for 60 seconds | Direct API health request silently times out; LiveKit is untouched; one healthy receiver peer and continued RTP with no observed stall longer than six seconds. This affects application HTTP as well as WS. |
| SFU paused for 15 seconds | Direct SFU health request silently times out; RTP stops after a three-second settle window; a healthy peer and advancing RTP are observed within 15 seconds of verified restore. Signaling and media are affected together. |

The pause is allowed only for this run's exact `qa-client-<nonce>-api` or `-sfu`
container with the matching ownership label on a local Unix Docker daemon.
Foreign, previously paused and unsupported targets are rejected. The context
restores the dependency on normal exit, exceptions and lost pause responses;
the CLI turns SIGTERM into an interrupt so its cleanup executes. SIGKILL and
host failure cannot be given a Python cleanup guarantee.

The original native background/resume assertions remain intact. Dense samples,
a working pre-fault stream and an actually interrupted stream are required;
`connected` alone, a no-op fault, sparse samples or late recovery cannot pass.
The source integration target remains a two-minute emulator check. Sampling is
approximately every two seconds; the recovery measurement is conservative.

These are dependency-process faults, not physical Wi-Fi/LTE, airplane, secure
keyguard, Doze, audio routing or acoustic acceptance. No speech is recorded or
inspected. The broad #785 physical/iOS/release gates remain separate.
