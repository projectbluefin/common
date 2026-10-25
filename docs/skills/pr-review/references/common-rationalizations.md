# Common Rationalizations

Part of [pr-review](../SKILL.md) — rationalizations agents and humans commonly reach for, and why they are wrong.

| Rationalization | Reality |
|---|---|
| "This one is obviously fine, I'll just merge it." | You cannot. `main` requires two approving reviews and three green checks, with no bypass actors — not even `--admin`. Agents never supply an approval. |
| "The PR says it fixes issue N, so closing the PR closes N." | Only a **merge** closes the linked issue. Closing leaves it open forever. |
| "I'll add `3-human-queue` and sort the labels out later." | Later never comes, and routing automation sees ambiguous state in the meantime. Swap in the same command. |
| "Both PRs touch the same file, so one must be a duplicate." | Same file, different bug, is common. Compare the actual hunks and the closing-issue sets before calling it. |
| "The doc change is small, I'll push to main and keep going." | There is no direct push. The ruleset's `pull_request` rule covers `refs/heads/main` with zero bypass actors. Docs-only changes open a PR like everything else; `validate` is the only check that runs on them. |
| "The maintainer will not want to be asked about this one." | Ask. Deferring to `3-human-queue` with findings is always available; guessing their verdict is not. |
| "The check is red, so the PR is broken." | Most reds here are environmental. A one-line digest bump cannot cause an HTTP 403. Classify the red before it costs the human a slot. |
| "I retitled it, so the title check will pass now." | It will not. `edited` is not a trigger, and a rerun replays the stale payload. Close and reopen, then verify. |
| "A flake re-run with no issue filed" is fine. | Re-running unblocks the PR; it leaves the flake in place for the next agent. File the fragility as an issue in the same breath. |
| "It was approved before, so I just need a fresh rubber-stamp." | Approvals are **not** auto-dismissed here (`dismiss_stale_reviews_on_push: false`), so a stale approval still counts toward the required two. That makes diffing from the approved SHA the only way to see what nobody reviewed. |
| "The reviewer already confirmed that concern was fixed." | They confirmed it against a head that no longer exists. Re-verify every resolved concern against the current head. |
| "The value is correct, so the pin is fine." | A mutable tag that resolves to the right commit today is still mutable. Correct-now is not the same as pinned. |
