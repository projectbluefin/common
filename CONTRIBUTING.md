# CONTRIBUTING

Thanks for helping out!

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

## What belongs here

**`projectbluefin/common`** is the shared OCI layer consumed by all Bluefin variants (bluefin, bluefin-lts, dakota). Changes here propagate to every downstream image. Be surgical.

- `system_files/shared/` — shared system config (staged from `ublue-os/aurorafin-shared`; upstream PRs go there, not here)
- `system_files/bluefin/` — Bluefin-specific config editable directly in this repo
- `Containerfile` — shared OCI image build
- `.github/` — org governance: CODEOWNERS, issue templates, skill sync, lifecycle automation

## Where to go for image-specific changes

| What you want to change | Repo |
|---|---|
| Bluefin-specific packages / config | [projectbluefin/bluefin](https://github.com/projectbluefin/bluefin) |
| Bluefin LTS | [projectbluefin/bluefin-lts](https://github.com/projectbluefin/bluefin-lts) |
| Dakota / GNOME OS image | [projectbluefin/dakota](https://github.com/projectbluefin/dakota) |
| Shared system config (Aurora + Bluefin) | [ublue-os/aurorafin-shared](https://github.com/ublue-os/aurorafin-shared) |
| E2E test suite | [projectbluefin/testsuite](https://github.com/projectbluefin/testsuite) |

Make sure you check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
