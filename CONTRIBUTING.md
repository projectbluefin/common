# Contributing

Thanks for helping out! Start with the
[Bluefin contributing guide](https://docs.projectbluefin.io/contributing).
The [architecture overview](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture)
explains how the image repositories fit together.

Common holds shared configuration. Image-specific changes belong in
[bluefin](https://github.com/projectbluefin/bluefin),
[bluefin-lts](https://github.com/projectbluefin/bluefin-lts), or
[dakota](https://github.com/projectbluefin/dakota); Aurora-compatible shared
configuration lives in `system_files/shared/` here.

Use the bug-report or feature-request form; maintainers decide what is accepted.
Reporters can reply normally without learning labels or slash commands.
The [repo contract](AGENTS.md) covers builds, accepted agent work, and PR gates.

PR checks include `Validate PR`, `Build`, `Unit Tests`, and `PR E2E`, without
expensive VM boots. Full layer validation (the `common` behave suite in
[testsuite](https://github.com/projectbluefin/testsuite)) runs on merges to main.

Task-specific references: [testing](docs/TESTING.md),
[style](docs/contributing/style-guide.md),
[Actions security](ACTIONS-SECURITY.md), and
[Prow commands](docs/skills/label-workflow.md).
