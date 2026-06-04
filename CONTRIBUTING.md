# CONTRIBUTING

Thanks for helping out!

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is the **shared OCI layer** consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical — see the scope warning in [`AGENTS.md`](./AGENTS.md). Make sure you also check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

- For Bluefin-specific image changes: [projectbluefin/bluefin](https://github.com/projectbluefin/bluefin)
- For LTS image changes: [projectbluefin/bluefin-lts](https://github.com/projectbluefin/bluefin-lts)
- For dakota changes: [projectbluefin/dakota](https://github.com/projectbluefin/dakota)
- For shared system config: [ublue-os/aurorafin-shared](https://github.com/ublue-os/aurorafin-shared)

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
