# CONTRIBUTING 

Thanks for helping out! 

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is the shared OCI layer and coordination hub for the Bluefin factory: shared `system_files/` overlays, governance and process docs, and the canonical skill docs live here. If you need to change an image-specific build or runtime behavior, work in the relevant image repo instead (`projectbluefin/bluefin`, `projectbluefin/bluefin-lts`, `projectbluefin/dakota`, or `projectbluefin/knuckle`). See the [architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture) for the repo boundaries.

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
