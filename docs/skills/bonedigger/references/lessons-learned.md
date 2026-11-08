# bonedigger — Lessons Learned & Sources

Part of [bonedigger](../SKILL.md) — lessons learned from production incidents, common rationalizations to reject, and source verification notes.

## Lessons Learned

### Preserve drafts rather than transient reports

`/usr/libexec/bonedigger-report` stores a submission draft in the user's state
directory before any public upload. On a failed or declined submission, retain
that draft and print its exact `ujust report --resume …` command so reports are
not lost. After a successful issue submission, copy the report body from the
 draft into `$XDG_STATE_HOME/ujust-report/last/` before removing the draft. Keep
 copy operations conditional on each source file: optional report artifacts may
 not exist, and `cp` must never make a successful report fail with `cannot stat`.

## Common Rationalizations

- "A full journal is more useful." Targeted profiles are easier to review and
  less likely to expose unrelated data.
- "A missing label is harmless." Do not make issue creation fail because an
  optional intake label is absent.
- "A failed upload can be retried from memory." Preserve a draft and print the
  exact resume command instead.

## Sources

GitHub CLI command options were verified against Context7 source
`/websites/cli_github_manual`: `gh issue create` supports `--repo`, `--title`,
`--body-file`, and `--label`; `gh gist create --public` publishes selected files.
