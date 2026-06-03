# CONTRIBUTING 

Thanks for helping out! 

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

## What belongs here

**projectbluefin/common** is the shared OCI layer consumed by all Bluefin image variants:
- Shared system configuration and packages (applied to all Bluefin variants and Aurora)
- Organizational governance (CODEOWNERS, governance.md)
- Shared infrastructure and documentation
- Build automation (Justfile, Containerfile)

For image-specific changes, open issues and PRs in:
- **bluefin** — base Bluefin image (Fedora-based, `:stable` tag)
- **bluefin-lts** — long-term support variant (`:lts` tag)
- **dakota** — minimal variant (`:latest` tag)

Refer to [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture) to understand how layers flow downstream.

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
