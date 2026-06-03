# CI Lifecycle Bot Consolidation

## Current State Analysis

### Issue #409 - Strategic Consolidation of Lifecycle Bot Fragmentation

#### Problem Statement
Project Bluefin has fragmented lifecycle automation across multiple implementations and repos. This creates:
- **Maintenance burden**: Multiple implementations to update and fix
- **Inconsistent user experience**: Different issue pipelines in different repos
- **Knowledge fragmentation**: Rules and logic scattered across codebases
- **Scalability issues**: Hard to add new repos with consistent automation

#### Current Lifecycle Automation Systems

##### 1. Bonedigger Lifecycle (projectbluefin/bonedigger)
- **Purpose**: Generic lifecycle bot for issue management
- **Implementation**: Reusable workflow at `.github/workflows/lifecycle.yml`
- **Features**:
  - Issue pipeline: filed → approved → queued → claimed → done
  - Pipeline widget embedded in issue body
  - Commands: `/claim`, `/unclaim`, `/approve`, `/lgtm`, `/wontfix`
  - Automatic label management
  - Priority escalation via confirmation counting
  - Stale claim detection (7 days)
  - Donation flow detection for agent work
  - Role-based command permissions
  - Scheduled maintenance jobs

- **Repos Currently Using**:
  - bluefin-lts (via bonedigger.yml - from #412)
  - dakota (via bonedigger.yml - from #412)
  - knuckle (via bonedigger.yml - from #412)

- **Unique Features**:
  - Built-in support for user reporting flows (ujust report integration)
  - Donation workflow tracking
  - Integrated with projectbluefin/bonedigger repo
  - Brand customization inputs (emoji, name)
  - Pipeline marker customization

##### 2. Actionadon (dakota-specific implementation)
- **Purpose**: Issue pipeline bot for dakota
- **Implementation**: Inline workflow at `dakota/.github/workflows/actionadon.yml`
- **Features**:
  - Issue pipeline: filed → approved → queued → claimed → done
  - Pipeline widget embedded in issue body
  - Commands: `/claim`, `/unclaim`, `/approve`, `/lgtm`
  - Note: **NO `/wontfix` command** (unlike bonedigger)
  - Automatic label management
  - Priority escalation via confirmation counting
  - Stale claim detection (7 days)
  - Donation flow detection for agent work
  - Role-based command permissions

- **Current Users**:
  - dakota (primary implementation)
  - knuckle (copy of actionadon.yml)

- **Status**: 
  - **DUPLICATED** in knuckle (inline copy, not a reusable reference)
  - **DEPRECATED**: Bonedigger is the evolved, feature-complete version

##### 3. No Lifecycle Bot
- **Repos without automation**:
  - bonedigger (the repo providing the automation, doesn't use it itself)
  - bootc-installer
  - common
  - dakota-iso
  - documentation
  - dot-project
  - finpilot
  - fisherman
  - iso
  - renovate-config
  - testing-lab
  - testsuite
  - website
  - wolfictl

#### Root Cause Analysis

1. **Evolutionary Development**: Actionadon was built first for dakota, then bonedigger evolved as a generalized version
2. **Repo-specific Needs**: Different repos started with tailored implementations
3. **Lack of Consolidation Plan**: No systematic migration from actionadon to bonedigger
4. **Duplication**: Knuckle manually copied actionadon.yml instead of referencing bonedigger

### Proposed Unified State Machine

#### Architecture: Centralized Reusable Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  projectbluefin/bonedigger/.github/workflows/lifecycle.yml  │
│  (Single source of truth for issue pipeline automation)     │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
        ┌──────────────┐  ┌──────────┐  ┌──────────────┐
        │ bluefin-lts  │  │ dakota   │  │  knuckle     │
        │ bonedigger.  │  │bonedigger│  │bonedigger.yml│
        │yml wrapper   │  │.yml wrap │  │  wrapper     │
        └──────────────┘  └──────────┘  └──────────────┘
                │             │             │
        uses: projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main
```

#### State Diagram - Unified Pipeline

```
                    ISSUE LIFECYCLE
                    
┌─────────┐   needs-triage label
│  FILED  │────────────────────────────────────────────┐
└────┬────┘                                             │
     │ user reports via ujust report                    │
     │ or issue opened manually                         │
     │ pipeline_marker appears in body                  │
     │                                                  │
     │ DETECTION: Donation flow?                        │
     │   yes → AGENT_DONATION path                      │
     │   no → STANDARD path                             │
     │                                                  │
     v                                                  │
┌──────────────┐    /approve or             ┌────────────────┐
│ DISCUSSING   │    status/approved label   │ AUTO-APPROVED  │
│ (needs-tri)  │◄──────────────────────────►│ (donation work)│
└────┬─────────┘                            └────────┬───────┘
     │ user confirms 3+ times → priority/high         │
     │ user confirms 5+ times → priority/critical     │
     │                                                 │
     │ /approve (maintainer)                          │
     │ → status/approved + queue/agent-ready          │
     │                                                 │
     v                                                 v
  ┌─────────────────────────────────────────────────────┐
  │         QUEUED (queue/agent-ready)                  │
  │  Waiting for volunteer to claim with /claim         │
  └────┬────────────────────────────────────────────────┘
       │
       │ /claim <user> (contributor)
       │ → queue/claimed + assignee:<user>
       │
       v
  ┌──────────────────────────────────────────┐
  │   CLAIMED (queue/claimed)                 │
  │   <assignee> actively working             │
  └────┬─────────────────────────────────────┘
       │
       │ /unclaim or 7-day stale
       │ → return to QUEUED
       │
       │ issue closed (PR merged)
       │ → DONE
       │
       v
  ┌──────────────────────────────────────────┐
  │  DONE                                     │
  │  Fix shipped, awaiting user verification │
  │  ujust verify <issue#>                   │
  │  3x verify = case closed                 │
  └──────────────────────────────────────────┘
```

#### Label Schema - Unified

**Status Labels** (mutually exclusive):
- `needs-triage` - Needs human review
- `status/discussing` - Under discussion
- `status/approved` - Approved for work

**Queue Labels** (mutually exclusive):
- `queue/agent-ready` - Ready to claim
- `queue/claimed` - In active work

**Priority Labels**:
- `priority/high` - 3+ user confirmations
- `priority/critical` - 5+ user confirmations

**Flow/Kind Labels**:
- `kind:agent-donation` - Agent donation request
- `flow/project-report` - Project report flow
- `flow/issue-review` - Issue review flow
- `flow/pr-review` - PR review flow

**Decision Labels**:
- `lgtm` - Maintainer approved
- `agent/blocked` - Blocked on human input
- `needs-human/agent-oops` - Agent error
- `hold` - Do not automate
- `do-not-merge` - Do not merge/automate

#### Command Handlers - Unified

All repos would support the same commands:

| Command | Actor | Effect |
|---------|-------|--------|
| `/claim` | contributor | `queue/claimed` + assignee |
| `/unclaim` | assignee or maintainer | remove `queue/claimed` + unassign |
| `/approve` | maintainer | `status/approved` + `queue/agent-ready` |
| `/lgtm` | maintainer | alias for `/approve` |
| `/wontfix <reason>` | maintainer | close as "not planned" + comment |

#### Implementation Strategy

##### Phase 1: Replace Actionadon (Immediate)

1. **Dakota**: Already using bonedigger.yml (from #412) - COMPLETE
2. **Knuckle**: Already using bonedigger.yml (from #412) - COMPLETE
   - Remove old inline actionadon.yml once bonedigger is verified

##### Phase 2: Standardize Wrapper Workflows (Immediate)

All bonedigger.yml files should use identical wrapper with optional customization:

```yaml
name: bonedigger
on:
  issues:
    types: [opened, labeled, closed]
  issue_comment:
    types: [created]
  schedule:
    - cron: '0 9 * * *'

permissions:
  issues: write
  contents: read

jobs:
  bonedigger:
    uses: projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main
    with:
      brand_name: "<BRAND>"
      brand_emoji: "<EMOJI>"
    secrets: inherit
```

| Repo | Brand Name | Emoji |
|------|------------|-------|
| bluefin-lts | Bluefin | 🦖 |
| dakota | Dakota | 🦖 |
| knuckle | Knuckle | 🦖 |

##### Phase 3: Expand to Readiness Tier Repos (Strategic)

Candidate repos for adoption:
- `bootc-installer` - Clear issues scope
- `iso` - Clear issues scope
- `finpilot` - Has issues
- `documentation` - Has issues

Recommendation: Adopt incrementally as org governance stabilizes.

##### Phase 4: Handle Special Cases

- **bonedigger repo itself**: Should implement its own lifecycle (self-referential)
- **common repo**: Provides foundations, low issue volume - defer
- **Internal/reference repos** (dot-github, dot-project, etc.): No lifecycle needed

#### Benefits of Consolidation

1. **Single Source of Truth**: One workflow to maintain and evolve
2. **Consistent UX**: All repos have identical pipeline behavior
3. **Feature Parity**: `/wontfix` available everywhere (was missing in actionadon)
4. **Reduced Maintenance**: No duplicate code to update across repos
5. **Easier Onboarding**: New repos adopt with simple wrapper
6. **Scalability**: Can add repos without rebuilding automation
7. **Community Confidence**: Users understand issue lifecycle regardless of repo

#### Risk Mitigation

**Risk**: Repos with custom workflows lose flexibility
**Mitigation**: 
- Bonedigger already supports customization (brand_name, brand_emoji, pipeline_marker)
- Document how to extend if truly needed
- Keep repo-specific wrappers for future customization

**Risk**: Migration breaks existing issues
**Mitigation**:
- Pipeline widget uses HTML comment marker for parsing
- Upgrade is transparent - old issues keep working
- Marker (`<!-- bonedigger-pipeline -->`) is standardized

**Risk**: Breaking changes to bonedigger lifecycle
**Mitigation**:
- Pin to semantic versions in wrapper (e.g., `@v2`, not `@main`)
- Maintain backwards compatibility in lifecycle workflow
- Planned deprecations with migration period

#### Migration Checklist

- [x] #412: Add bonedigger.yml to bluefin-lts
- [x] #412: Add bonedigger.yml to dakota
- [x] #412: Add bonedigger.yml to knuckle
- [x] #413: Add skill-drift.yml to knuckle
- [ ] Remove actionadon.yml from dakota (after verification)
- [ ] Remove duplicate actionadon.yml from knuckle (after verification)
- [ ] Document consolidation strategy for org
- [ ] Set bonedigger as mandatory for issue-enabled repos
- [ ] Create governance doc for when repos adopt bonedigger
- [ ] Plan Phase 3 expansion to additional repos

#### Open Questions

1. Should bonedigger repo implement its own lifecycle?
   - Proposed: Yes, self-host to prove the system works
   
2. How to handle repos that want custom state machines?
   - Proposed: Keep bonedigger as standard, allow forks for edge cases
   
3. Should we version bonedigger lifecycle separately?
   - Proposed: Yes, adopt semantic versioning (@v1, @v2, etc.)

#### Related Issues

- #412: Add bonedigger.yml lifecycle workflow to repos
- #413: Add skill-drift.yml workflow to knuckle

---

**Document Status**: Analysis complete, ready for design review  
**Next Step**: Review recommendations, validate with team, execute Phase 1-2 items
