# Security Policy

## Reporting a Vulnerability

Report security vulnerabilities through [GitHub Private Vulnerability Reporting](https://github.com/projectbluefin/common/security/advisories/new). Do not disclose an unpatched vulnerability in a public issue.

Include:
- vulnerability description and impact
- reproduction steps or proof of concept
- affected file, system configuration, or workflow
- suggested mitigation, if available

## Response

The maintainers acknowledge reports within 48 hours and aim to assess them within 7 days. Fix and disclosure timing depends on severity and coordination with affected upstreams.

## Scope

This repository is the shared OCI layer consumed by all Bluefin image variants (`bluefin`, `bluefin-lts`, `dakota`).

In scope:
- Shared system configurations under `system_files/`
- Polkit authorization policies and user setup hooks
- Repository CI workflows, build recipes, and test suites
- Package verification and repository trust configurations

Out of scope:
- Vulnerabilities in upstream Fedora/CentOS packages (report to upstream maintainers)
- Third-party Flatpaks or Homebrew formulae unless introduced by Bluefin packaging

## GitHub Actions Security Baseline

For the organization-wide GitHub Actions hardening standard (top-level permissions, action SHA pinning, `pull_request_target` restrictions, and release asset checksum verification), see:
👉 [ACTIONS-SECURITY.md](ACTIONS-SECURITY.md)
