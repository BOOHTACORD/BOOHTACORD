# Owner-local telemetry between two owned hosts

Use an existing approved private network first. When the API and its existing
owner-only Collector are on different hosts without a shared private route, the
link below carries OTLP through authenticated, host-key-pinned SSH. Raw local
diagnostics stay in the same owner's existing private Collector/Tempo/Grafana;
this is not enrollment in the central gateway and does not enable central consent.
Do not use this procedure for a third party's installation or a shared tenant
Collector. Do not replace the application's private-destination transport guard.

A public `OTEL_EXPORTER_OTLP_ENDPOINT` is deliberately rejected by
`central_export/private_transport.go`. Repeated `local collector address is not
private` errors plus no recent stored spans indicate a broken local delivery
route; Collector HTTP acceptance alone is still not storage confirmation. DNS
resolution or disabling the guard is not a remedy.

## Design and review boundary

```text
API container (existing private Docker network)
  → exact host Docker-bridge IPv4:14318
  → OpenSSH encrypted connection, dedicated write-only transport credential
  → owned monitor's 127.0.0.1:4318
  → existing Collector → Tempo / Prometheus → private Grafana
```

The API host's listener binds only the inspected RFC1918 Docker bridge address,
never its public IP, `0.0.0.0`, wildcard IPv6 or a host DNS name. A read-only
preflight rejects a changed/missing bridge/address before every service start.
The monitor keeps Collector bound to loopback; no new public ingest/read/control
listener is introduced. API containers already attached to that approved private
bridge can reach the link. If that bridge includes untrusted containers, stop and
use a separately reviewed network/authentication design instead.

Use a **dedicated monitor account** such as `boohtacord-otel`, with no sudo,
application ownership or normal login role. Do not place this policy on the human
operator's account, and never copy a general-purpose/root private key. The new
ED25519 private key is generated on the API host only and stays there in a root-only
file. The systemd service runs as a DynamicUser and receives it using
`LoadCredential`; the unit never embeds a credential or requests ssh-agent access.
Only the public key is installed on the monitor, restricted to the API's fixed
SSH source IP and Collector loopback destination.

`restrict,port-forwarding,permitopen=...` in `authorized_keys` is insufficient by
itself: it re-enables TCP forwarding. The dedicated account's sshd Match policy
also requires `AllowTcpForwarding local`, `PermitListen none`,
`AllowStreamLocalForwarding no`, `MaxSessions 0`, no agent/PTY/X11/user RC and a
forced false command. `permitlisten="none"` is **not valid authorized_keys
syntax**; `PermitListen none` belongs in `sshd_config`. Never substitute the
operator account to avoid creating the dedicated account. See the authoritative
[OpenSSH key options](https://man.openbsd.org/sshd.8#AUTHORIZED_KEYS_FILE_FORMAT)
and [sshd forwarding/session controls](https://man.openbsd.org/sshd_config.5#AllowTcpForwarding).

Creating a persistent restricted credential/account and changing production
routing must be reviewed by the operator against these concrete files before
application. The source renderer only writes a new local review bundle; it does
not connect, generate credentials, alter accounts, reload services or deploy.

## Prepare a reviewable bundle

Read the exact Docker private network gateway and Linux bridge interface from the
running API deployment. Do not use the host's default bridge gateway or a guessed
subnet. In the #513 investigation the approved API gateway was `172.19.0.1`; a
separate bridge used another subnet. Confirm the actual current interface before
using that value. The renderer accepts a literal RFC1918 IPv4 and an inspected
`br-<12 hex digits>` / `docker0` interface only.

Obtain the monitor's ED25519 **public host key** through the existing trusted
operator connection or console. Check its fingerprint independently; do not use
`ssh-keyscan` as trust establishment, `accept-new`, disabled host validation or
agent forwarding. Confirm that systemd supports `DynamicUser` and
`LoadCredential` (systemd 247 or newer) and the installed OpenSSH supports the
rendered Match directives. Existing operator SSH access must remain unchanged.

```sh
python3 -m tools.observability.private_link.render \
  --api-source-ip API_FIXED_SSH_SOURCE_IPV4 \
  --bridge-ip INSPECTED_PRIVATE_GATEWAY \
  --bridge-interface INSPECTED_LINUX_BRIDGE \
  --monitor-ip OWNED_MONITOR_IPV4 \
  --monitor-host-key-file /private/monitor-ed25519-host.pub \
  --output .out/issue513/private-link-review
```

Without an API public key this produces an explicit, noninstallable
`monitor-authorized-key.template` and `pending_public_key` plan. Review the
listener/destination, account restrictions, credential paths, endpoint change and
rollback below. After operator review, generate a fresh transport ED25519 key **on
the API host**, outside Git, and set the containing directory to 0700 and private
key to 0400. The unencrypted-on-disk key supports unattended startup; its restricted
scope and root-only storage are required. Do not copy it to this workstation or
include it in command output, logs, issues, evidence or deployment artifacts.

Only transfer its `.pub` file to the authorized owner connection, then rerender
into another new review directory with `--api-public-key-file /private/api-link.pub`.
The helper validates the actual ED25519 wire format and discards key comments.
The monitor host key and transport public key are different keys.

## Apply after review

1. Keep a trusted operator SSH session open. Record only the prior OTLP endpoint
   values and exact changed config paths in protected operator notes; do not dump
   the complete API environment or credentials. Verify the monitor Collector is
   the existing owner-only stack and still listens on `127.0.0.1:4318`.
2. Create/confirm the dedicated monitor account with no sudo and no normal session
   purpose. Install `monitor-authorized-key` as root-owned
   `/etc/ssh/boohtacord-otel.authorized_keys` with mode 0644 (public key only; sshd
   reads it under the target UID). Append the rendered Match section at the
   **end of `/etc/ssh/sshd_config`**, after existing global/Match configuration.
   Do not put this Match block in an early drop-in: its trailing `Match all`
   still leaves the parser in a Match context and can make later global-only
   directives invalid. Its `AuthorizedKeysFile` points only at this dedicated
   file. Do not edit operator/root authorized keys or global
   forwarding/authentication defaults. An account disabled by the host's PAM or
   account-lock policy may need operator-specific configuration; do not work
   around that by enabling password login or granting shell/sudo rights.
3. Validate `sshd -t` and inspect effective settings using `sshd -T -C
   user=boohtacord-otel,addr=API_FIXED_SSH_SOURCE_IPV4,host=API_FIXED_SSH_SOURCE_IPV4`.
   Confirm every restriction, including local-only TCP forwarding, `permitlisten
   none`, no StreamLocal, `maxsessions 0` and the pinned Collector destination.
   Compare effective settings for root and the existing normal operator account
   against their pre-change output; both must remain unchanged. Reload only after
   these checks; verify the old trusted session and a second operator connection
   still work. Do not reload an invalid configuration.
4. On the API host, install root-only `ssh_config`, `known_hosts` and generated
   private key under `/etc/boohtacord/telemetry-private-link/`. Install the reviewed
   standalone `check_binding.py` under
   `/usr/local/libexec/boohtacord-telemetry-private-link/`, root-owned and not
   writable by the service. `/usr/local/libexec` may not exist: create the full
   directory hierarchy using
   `install -d -o root -g root -m 0755 /usr/local/libexec/boohtacord-telemetry-private-link`
   before installing the
   helper with root ownership and mode 0644. Install the unit under
   `/etc/systemd/system/`.
   Run `systemd-analyze verify` against the installed unit and execute its
   read-only binding preflight. Reload units and start the dedicated link.
5. Confirm host `ss -ltn` shows **only** the inspected bridge address on 14318,
   never public/wildcard addresses. Check access from the API container.
   `AF_NETLINK` is allowed only so the read-only iproute2 preflight can inspect
   addresses; the service has no `CAP_NET_ADMIN` or other capabilities. Verify
   public IP port 14318 remains unreachable from an independent host. Check an attempted
   shell/subsystem, different `-L` destination and `-R` forwarding using only the
   dedicated key are denied; the permitted `127.0.0.1:4318` forward works.
6. Set `OTEL_EXPORTER_OTLP_ENDPOINT=http://INSPECTED_PRIVATE_GATEWAY:14318` using
   the normal deployment configuration path. Review specific
   `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` and `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`
   overrides: either remove obsolete overrides or set them to the corresponding
   private `/v1/traces` and `/v1/metrics` URLs. The relay uses the explicit traces
   endpoint first too. Preserve ingest authorization, installation identity,
   consent, central endpoint/mode and all application settings. Recreate/restart
   only the affected API through the ordinary deployment mechanism.
7. Generate an owned synthetic action. Read its sanitized trace from Tempo and
   required series from Prometheus; check source labels/units, account/visit scope
   and no high-cardinality metric labels. Verify new private-address errors have
   stopped, Collector export failures are not increasing and both the existing
   dashboard UID and private access remain correct. An accepted OTLP request alone
   does not pass this step. Record source SHA, configuration versions and cleaned
   `PASS/FAIL/NOT_RUN` evidence, without credentials, actual user data or key files.

The SSH keepalive detects lost transport after approximately 45 seconds; systemd
restarts failed or cleanly disconnected transport processes with a 5 second
interval. Existing API request and exporter deadlines/queues remain bounded
independently. The link does not
promise retention during an outage, replace Collector retry policy, retain failed
payloads forever or make chat/voice depend on monitoring. Monitor its systemd
state and actual Collector/Tempo delivery separately. This service has no backup,
snapshot, product media proxy or central consent behavior.

## Failure and rollback

Stop the link before recreating/changing the private Docker bridge. If its
interface/address changes, the service must fail its preflight; inspect and
rerender instead of binding a wildcard or bypassing the check. A host-key change
also requires independent owner verification and reviewed pin replacement.

For rollback, restore the exact previous OTLP endpoint configuration through the
normal API deployment path, then stop/disable the dedicated link and revoke only
its public-key entry. Remove only the dedicated appended Match block after `sshd -t`
and unchanged operator-access checks; no operator key or other rule is changed.
Do not auto-delete credential files or retained telemetry as part of rollback.
If the old endpoint was public and rejected by the guard, rollback restores that
known degraded diagnostic state; it must not disable the guard or report healthy
delivery. Product smoke and export/Tempo readback are separate outcomes. Retained
trace storage and central consent remain unchanged.

## Source checks

```sh
python3 -m unittest tools.observability.private_link.test_render \
  tools.observability.private_link.test_verify_binding
```

Tests verify exact private binding, changed-interface failure, dedicated-account
constraints, key/config injection rejection, pinned trust and credential handling,
non-overwriting bundles and actual OpenSSH client config parsing without
connecting. POSIX 0700/0600 checks run on POSIX hosts; Windows runs the pure render
and non-overwrite checks, with filesystem ACL review remaining an operator step.
The installed transport and preflight runtime is Ubuntu-only. These tests do not
substitute for the installed sshd/systemd effective-policy checks or production
packet/storage readback above.
