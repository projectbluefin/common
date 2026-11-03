---
name: acceptance-evidence
version: "1.0"
last_updated: "2026-11-02"
id: acceptance-evidence
one_line_purpose: Record which acceptance checks are automatable in CI/VMs and which are physical-only.
entry_point: docs/skills/acceptance-evidence.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [acceptance, evidence, hardware, promotion, hive]
description: >-
  Acceptance evidence for promotion candidates. Use when deciding whether a
  check can run in a CI VM, recording a physical-only exception, or having
  Hive gather boot/update/rollback and desktop evidence without an operator.
metadata:
  type: runbook
---

# Acceptance evidence in the factory loop

A promotion candidate is only as good as the proof that it actually works.
"Acceptance evidence" is that proof: record that a candidate image boots,
installs, updates, and rolls back, and that the desktop works on the hardware
people actually use. This is different from a unit test or a shared-layer
check — it proves the whole image behaves end to end before it is promoted.

The factory loop wants to stop requiring a human to run these checks by hand,
while keeping the checks that only a real device can answer. This skill
records, for each remaining acceptance check, whether it can run in an
isolated CI/VM on the exact candidate image, or whether it is genuinely
physical-only and must stay pending until a human observes it.

## The rule that guards everything

**Never treat a missing, failed, or stale observation as a pass.** If the
evidence was not captured, the candidate failed, or the image behind the
evidence is older than the candidate being promoted, the answer is "not
proven" — never "passed." Admission is blocked until real evidence exists, and
that evidence is linked to the task that owns the repair.

## What can be automated in a CI/VM

These checks can run in an isolated VM against the signed exact-candidate
image. The VM boots the candidate the same way a person would, so a pass here
is real proof, not a proxy:

| Check | Issue | What the VM does |
|---|---|---|
| Composefs install / boot / update / rollback | Utah #938 | Boot the candidate, run a fresh install, boot it, apply an update, boot it, roll back, boot it. This is the lifecycle path that currently avoids the composefs default because no accepted proof existed. |
| SELinux policy-store change | Utah #894 | Exercise the policy-store change in the VM. The change itself is VM-testable; only the booted-update verification (see below) is held out. |
| Decoder capability / load | Utah #919 | After the underlying repair lands, run a runtime check that the decoder loads and decodes in the VM. |

Anything that can boot, install, update, roll back, or run a software
capability inside a VM is automatable. It only needs a bounded runner that can
spin up the exact candidate and a way to read the result back.

## What is physical-only and why

Some checks can only be answered by a real device and a human eye. They cannot
be inferred from the installed packages, from static metadata, or from SSH
plumbing into a machine. These stay explicitly **pending** until observed:

| Check | Issue | Why it is physical-only |
|---|---|---|
| Physical screen unlock | Utah #461 | Unlock depends on the actual sensor/firmware and the person; no image inspection can prove it. |
| Desktop rendering | Utah #992 | The panel must actually paint; a VM or SSH session cannot show real desktop rendering. |
| Physical unlock / desktop rendering observations | Utah #997 | Same as above — requires the real display and human observation. |

The precise physical-only exception, stated once: **any check that depends on
a real display or a physical unlock requires human observation of the device;
package inspection, static metadata, and SSH access are not valid substitutes.**
These remain pending and must not be closed from SSH plumbing alone.

## What is not acceptance at all

Some work is easy to mistake for acceptance but is neither package
publication nor runtime acceptance:

- Packages #812 / #804 (VMware / input-method package import) — importing a
  package is neither publishing it nor proving it runs. These do not belong in
  the acceptance-evidence list and require no boot evidence.

## How Hive acquires the automatable evidence

For the automatable checks above, Hive should be able to trigger an isolated
boot/install/upgrade/rollback on the exact candidate and read the signed result
back, without an operator dispatching each run, and to retry only genuine
infrastructure failures. To do that Hive needs, from the owner, things that live
outside this repository:

- a bounded VM / hardware-runner interface,
- approved images and test inputs plus access to the signed exact-image
  artifacts, and
- scoped credential and network access.

This repository cannot provide those on its own. It is the shared OCI layer that
the checks run against, not the runner that boots them. In addition, the factory
secrets policy forbids agents from creating any new secret, PAT, token, or
credential, so the credential piece of that interface must come from a human —
not from an agent editing a workflow.

## Checklist for a candidate

- [ ] Every automatable check above has a real VM evidence record for this exact image digest.
- [ ] Failed, missing, or old-image evidence blocks admission and names the owning repair task.
- [ ] Each physical-only check is recorded as pending with the reason it cannot be automated.
- [ ] Non-acceptance work (package imports) is kept out of the acceptance list.

## Related paths

- Which checks need a real device: [`hardware-testing.md`](./hardware-testing.md)
- What already runs in CI/VMs: [`e2e-ci.md`](./e2e-ci/SKILL.md)
- When to stop and ask a human: [`human-gates.md`](./human-gates.md)
- Issue this records against: projectbluefin/common#1614
