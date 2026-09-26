# Evaluation — Legacy SANE Scanning Appliance (saned/net)

**Status:** `EVALUATION` — protocol, security, and license assessment; not a
build proposal
**Filed:** [common#1215](https://github.com/projectbluefin/common/issues/1215)
**Parent epic:** [common#1210](https://github.com/projectbluefin/common/issues/1210)
**Scope:** No physical scanner was available for this evaluation. Any
statement about real hardware behavior below is marked **unverified** and is
based on upstream documentation only, not on a test run against a device.

---

## 1. Question this answers

Should `common` package a standalone `saned` (SANE network daemon) scanning
appliance as an OCI image, and if so, how must it be described so it is never
confused with driverless scanning (eSCL/WSD)? This is an investigation, not
an implementation: no Containerfile, systemd unit, or image is proposed here.
Any future prototype must (a) exercise a real synthetic SANE backend — e.g.
the `sane-project/backends` `test` backend, which emits deterministic
synthetic image data without hardware — and (b) be labeled and documented as
a distinct, legacy protocol from eSCL/WSD driverless scanning, per the
acceptance criteria on common#1215.

## 2. What `saned`/`net` actually is

SANE (Scanner Access Now Easy) is the Unix/Linux scanning API and backend
architecture (<https://gitlab.com/sane-project/backends>). It is not itself a
discovery or auto-configuration protocol. Its network capability is a
client/server pair:

- **`saned`** runs on the host with the scanner physically attached (USB,
  parallel, SCSI) and listens on TCP port 6566, traditionally invoked through
  `inetd`/`xinetd` rather than as a long-running standalone daemon.
- The **`net` backend** on the client side connects to a `saned` instance and
  proxies SANE API calls to it, making a locally-attached scanner reachable
  over a network.

There is no discovery layer: clients must be told the server address (via
`/etc/sane.d/net.conf` or `SANE_NET_HOSTS`). This is architecturally
different from eSCL/WSD, which are self-describing HTTP services found via
mDNS/DNS-SD (eSCL) or WS-Discovery (WSD).

## 3. Protocol and security assessment

| Property | saned/net | eSCL | WSD |
|---|---|---|---|
| Transport | Custom binary RPC over raw TCP | HTTP(S) + XML | SOAP over HTTP(S) |
| Discovery | None (static config) | mDNS/DNS-SD | WS-Discovery |
| Transport encryption | **None built in** | TLS via HTTPS | TLS via HTTPS |
| Access control | IP allow-list in `saned.conf` (`+` = any host, explicitly flagged as a risk in upstream docs); optional `saned.users` file of plain-text `user:password:backend` entries, sent as an MD5 challenge-response when the client supports it, otherwise in clear | HTTP auth / device-local | HTTP auth / device-local |
| Recommended exposure | Upstream docs (`saned(8)`) say explicitly: not fit for exposure beyond a trusted LAN; front with a firewall or tcpwrappers, or tunnel over SSH/VPN | Designed for LAN, HTTPS-capable | Designed for LAN, HTTPS-capable |
| Root/privilege notes | Must not run as root or setuid-root; classic advice is to run under a dedicated unprivileged user via inetd | N/A (client library, no daemon) | N/A |

Key findings:

1. **No native transport encryption.** The saned wire protocol predates TLS
   integration; there is no `saned`-native TLS mode. Any confidentiality on
   the wire must come from an external tunnel (SSH, WireGuard, VPN) — this is
   the documented community workaround, not a feature of the daemon.
2. **Authentication is weak by modern standards.** The optional
   `saned.users` file stores passwords in plain text on disk
   (`user:password:backend` per line); on the wire, the server sends a
   random salt and an MD5-supporting client responds with
   MD5(salt + password), but a client without MD5 support falls back to
   sending the password in clear (`sanei_auth.c`'s `check_passwd()`
   compares the plain-text file entry against either form). IP-based
   allow-listing is the primary control, and upstream documentation calls
   out the bare `+` wildcard entry as a specific misconfiguration risk.
3. **No discovery, so no accidental network exposure by default** — a
   `saned` container would need an operator to explicitly configure a client
   to find it. This bounds accidental blast radius but adds a UX gap
   compared to driverless protocols.
4. **This is a materially different threat model from eSCL/WSD.** Both
   driverless protocols run over HTTP and inherit HTTPS/TLS when the device
   or bridge (e.g. `ipp-usb`) supports it. Packaging `saned` alongside or
   as a substitute for eSCL support without this distinction documented
   would materially overstate its security posture.

**Conclusion:** a `saned` appliance is only appropriate for an isolated,
trusted network segment (or a tunnel), never for direct exposure, and any
image or documentation must say so explicitly rather than implying parity
with driverless discovery/encryption.

## 4. License assessment

SANE uses a tiered, non-uniform license scheme (source:
`sane-project/backends`, corroborated by Fedora's packaged SPDX expression
for `sane-backends-libs`):

- **Frontend tools** (`scanimage`, etc.): GPL-2.0-or-later.
- **Backend libraries** (`libsane`, individual scanner backends): GPL-2.0-or-later
  **with the "SANE exception"** — an explicit linking exception that
  predates the LGPL and permits differently-licensed programs to link
  against the backend libraries without those programs becoming subject to
  the GPL. Not every backend carries the exception uniformly.
- **The SANE API/network protocol specification** itself: public domain.
- Some backends bundle third-party code under other licenses (e.g. IJG JPEG
  code), producing a composite expression in downstream packaging
  (`GPL-2.0-or-later WITH SANE-exception AND ... AND LGPL-2.1-or-later AND
  IJG AND MIT`, per Fedora's package metadata).

Implication for `common`: packaging `sane-backends` and `saned` as a
container is license-compatible with an OCI image built and distributed the
way Bluefin's existing images are (GPL binaries running in a container, not
statically linked into a differently-licensed program), so licensing is not
a blocker. It does mean any vendored patches to backend code must preserve
the GPL-2.0-or-later + SANE-exception notices per-file, and a bundled SBOM
entry should record the composite expression rather than a single SPDX id.

## 5. Client requirements

For a client (bluefin desktop, another appliance, `sane-airscan`, etc.) to
reach a `saned` appliance:

1. `sane-backends` (specifically the `net` backend) installed on the client.
2. `/etc/sane.d/net.conf` or `SANE_NET_HOSTS` pointing at the appliance's
   address — no discovery is available.
3. Network path on TCP/6566 to the appliance, and, if the appliance's
   `saned.conf` allow-list is not `+`, the client's address (or hostname)
   present in that list.
4. If `saned.users` is configured, credentials provisioned out of band; the
   file stores plain-text passwords on the appliance and the wire protocol
   only optionally MD5-challenges them (falling back to cleartext against
   older clients), so this should be treated as access control, not
   confidentiality, and should ride over an encrypted tunnel if used outside
   a fully trusted segment.

## 6. Recommendation

- **Do not** publish a `saned` OCI image as, or alongside, a driverless
  scanning solution without the distinctions in §3 stated in its own
  documentation and container description (no eSCL/WSD language, no implied
  auto-discovery, no implied TLS).
- **If** a prototype is built, it must run `saned` against the upstream
  `test` backend (`sane-project/backends`, backend name `test`), which
  produces synthetic scan data deterministically and requires no physical
  scanner — this keeps the prototype's claims verifiable in CI without
  hardware, unlike claiming support for a real device this evaluation could
  not test.
- **Recommended follow-up scope**, each as its own bounded issue rather than
  bundled here: (a) a minimal `test`-backed `saned` container definition,
  gated by the Security human-gate given the transport findings in §3;
  (b) explicit `saned` vs. eSCL/WSD user-facing documentation if such a
  container ships; (c) do not attempt to make this the same appliance as
  the eSCL fixture tracked in common#1212 — they exercise different
  protocols and should stay separate to avoid conflating driverless and
  legacy scanning claims.
- This evaluation does not itself require the Design human-gate (no
  user-visible behavior changes yet), but a follow-up PR that ships a
  running `saned` container does, per
  [`docs/skills/human-gates.md`](../skills/human-gates.md), because it
  exposes a network-facing daemon with the weak-authentication properties
  documented in §3.

## 7. Sources

- `saned(8)` — <https://manpages.ubuntu.com/manpages/noble/man8/saned.8.html>
- `saned(8)` — <https://linux.die.net/man/8/saned>
- Debian Wiki, SaneOverNetwork — <https://wiki.debian.org/SaneOverNetwork>
- Penguin-Breeder, SANE network backend — <https://penguin-breeder.org/sane/saned/>
- Fedora Packages, `sane-backends-libs` — <https://packages.fedoraproject.org/pkgs/sane-backends/sane-backends-libs/>
- Wikipedia, Scanner Access Now Easy — <https://en.wikipedia.org/wiki/Scanner_Access_Now_Easy>
- Wikipedia, GPL linking exception — <https://en.wikipedia.org/wiki/GPL_linking_exception>
- `sane-project/backends` GitLab issue #55, GPL license and iOS App Store — <https://gitlab.com/sane-project/backends/-/issues/55>
- `sane-project/backends` NEWS changelog — <https://gitlab.com/sane-project/backends/blob/master/NEWS>
- Debian Wiki, eSCL — <https://wiki.debian.org/eSCL>
- `sane-airscan` — <https://github.com/alexpevzner/sane-airscan>
- Linux Plumbers Conference, "sane-airscan: the future of Linux driverless scanning" — <https://lpc.events/event/7/contributions/695/attachments/558/986/sane-airscan.pdf>
