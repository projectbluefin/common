# CONTRIBUTING 

Thanks for helping out! 

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is for building the images, you are probably looking for [@projectbluefin/common](https://github.com/projectbluefin/common) to change something in Bluefin. Make sure you check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.

### Pre-merge Validation

Since `common` is a shared library used by downstream images (Bluefin, Dakota), a PR comment bot will notify you of recent build status in those repos. **Before merging**, manually verify your changes work correctly in the downstream images:

1. Check the latest build status links posted in your PR comment
2. Test your changes in the most recent bluefin and dakota image builds
3. Run `ujust` and test any recipes/commands you modified
4. Report any issues to the relevant downstream repository

This MVP validation approach provides immediate feedback without blocking PRs. Full automated composition gate (issue #405) will be implemented separately.
