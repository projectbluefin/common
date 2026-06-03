# CONTRIBUTING

Thanks for helping out!

## What belongs here

`projectbluefin/common` is the **shared OCI layer** consumed by all Bluefin variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota` at next build — stay surgical.

| If you want to change… | Go to |
|---|---|
| Bluefin desktop defaults, apps, just recipes | [`projectbluefin/bluefin`](https://github.com/projectbluefin/bluefin) |
| LTS-specific behavior | [`projectbluefin/bluefin-lts`](https://github.com/projectbluefin/bluefin-lts) |
| Dakota (GNOME OS variant) | [`projectbluefin/dakota`](https://github.com/projectbluefin/dakota) |
| Shared system config (applies to Aurora too) | [`ublue-os/aurorafin-shared`](https://github.com/ublue-os/aurorafin-shared) |
| E2E test suite | [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite) |
| Shared just recipes, profile scripts, CODEOWNERS | **here** |

See the [architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture) for the full picture.

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
