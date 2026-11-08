# Common Rationalizations

Part of [pr-review](../SKILL.md) — rationalizations agents and humans commonly reach for, and why they are wrong.

| Rationalization | Reality |
|---|---|
| "This one is obviously fine, I'll just merge it." | The human verdict is the only review gate on `main` — approvals are not enforced. Merging without one means the change had zero review. |
| "The PR says it fixes issue N, so closing the PR closes N." | Only a **merge** closes the linked issue. Closing leaves it open forever. |
| "I'll add a queue label and sort it out later." | Common PRs use native review state and human-directed holds, not retired queue labels. Elsewhere, swap queues under the target repository's contract. |
| "Both PRs touch the same file, so one must be a duplicate." | Same file, different bug, is common. Compare the actual hunks and the closing-issue sets before calling it. |
| "The doc change is small, I'll push to main and keep going." | Direct pushes bump every queued PR. Cheap to re-check, expensive to discover a week later. |
| "The maintainer will not want to be asked about this one." | Ask. Preserve a human-directed hold in common or use the target repository's local human queue; do not guess the verdict. |
| "The check is red, so the PR is broken." | Most reds here are environmental. A one-line digest bump cannot cause an HTTP 403. Classify the red before it costs the human a slot. |
| "I retitled it, so the title check will pass now." | It will not. `edited` is not a trigger, and a rerun replays the stale payload. Close and reopen, then verify. |
| "A flake re-run with no issue filed" is fine. | Re-running unblocks the PR; it leaves the flake in place for the next agent. File the fragility as an issue in the same breath. |
| "It was approved before, so I just need a fresh rubber-stamp." | The approval was dismissed because the head moved. Those commits can revert what the reviewer approved — and still pass CI. Diff against the approved SHA. |
| "The reviewer already confirmed that concern was fixed." | They confirmed it against a head that no longer exists. Re-verify every resolved concern against the current head. |
| "The value is correct, so the pin is fine." | A mutable tag that resolves to the right commit today is still mutable. Correct-now is not the same as pinned. |
