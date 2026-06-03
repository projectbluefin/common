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

#### Benefits of Consolidation

1. **Single Source of Truth**: One workflow to maintain and evolve
2. **Consistent UX**: All repos have identical pipeline behavior
3. **Feature Parity**: `/wontfix` available everywhere (was missing in actionadon)
4. **Reduced Maintenance**: No duplicate code to update across repos
5. **Easier Onboarding**: New repos adopt with simple wrapper
6. **Scalability**: Can add repos without rebuilding automation
7. **Community Confidence**: Users understand issue lifecycle regardless of repo

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

---

**Document Status**: Analysis complete, ready for design review  
**Next Step**: Review recommendations, validate with team, execute Phase 1-2 items
