# CONTRIBUTING 

Thanks for helping out! 

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is for building the images, you are probably looking for [@projectbluefin/common](https://github.com/projectbluefin/common) to change something in Bluefin. Make sure you check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
