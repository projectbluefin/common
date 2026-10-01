---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-b7af645f-chairlift-developer-feeds-pulp

## Overview

Developer Mode offers an opt-in, community-vetted collection of Bluefin changelogs, cloud-native reading and podcasts through Pulp without changing a person’s existing subscriptions. Four of its five native children are closed; only user-scoped Pulp provisioning and OPML staging remains open. Source: [chairlift#235](https://github.com/projectbluefin/chairlift/issues/235).

## Requirements

- [x] **Provide a curated feed catalog**
  Developer Tools can offer a categorized, community-vetted OPML catalog with Bluefin releases, Homebrew, engineering blogs and podcasts.
- [x] **Keep feed choice opt-in**
  A user enabling Developer Mode can separately choose whether to stage feeds or install Pulp; disabling the mode does not remove Pulp or subscriptions.
- [x] **Explain the optional experience**
  People can find instructions to import staged feeds into Pulp from Developer Tools.
- [x] **Show relevant developer reading**
  Developer Mode can open docs, training and current GNOME resources without coupling them to feed import.
- [ ] **Provide a user-scoped reader**
  A user who opts in can install Pulp at user scope and import a staged OPML file without database mutation.

## Constraints

- Side-effectful auto-install and feed staging default to disabled under dx_group; user/system scope must never be conflated.
- Never write Pulp’s versioned sandbox SQLite database or assume a stable import CLI/D-Bus interface.
- The existing Developer Mode disable crash (#142) must not be worsened; any async work remains off the GTK thread and respects dry-run.
- Offline OPML validation must not depend on network availability; stale endpoint verification is a separate manual check.

## Acceptance Criteria

- [x] **Provide a curated feed catalog**
  Closed #236 supplies an offline-validated OPML catalog and categorized entries, with stale candidates called out.
- [x] **Keep feed choice opt-in**
  Closed #238 preserves the opt-in toggle and a no-op on disable; explicit false remains the default.
- [x] **Explain the optional experience**
  Closed #239 guidance covers setup, user scope and non-destructive import.
- [x] **Show relevant developer reading**
  Closed #240 exposes developer reading through the existing surface.
- [ ] **Provide a user-scoped reader**
  Open #237 proves user-scoped Pulp installation, OPML staging and explicit user import; no existing Pulp data changes.

## Technical Approach

- Use org.gnome.gitlab.cheywood.Pulp as user Flatpak and stage OPML at ~/.local/share/chairlift/developer-feeds.opml; the user invokes Pulp’s import flow.
- The source issue records the feed catalog, checked URL status and community-review request; keep catalog entries in the source OPML asset, not a second live database in ChairLift.
- Native children #236, #238, #239, #240 are closed; #237 is open. Coordinate Developer Tools placement with chairlift#195/#233 so the feature is not duplicated.
- Original curated feed and podcast catalog (preserve verified URLs and stale notes):

### Curated Feed & Podcast Inventory (Status & Vetting)

#### 1. Project Bluefin & Image Changelog Feeds (from https://docs.projectbluefin.io/changelogs/)
| Feed Name | Feed URL | Verified Type | Notes |
|---|---|---|---|
| **Bluefin OS Releases Atom** | `https://github.com/projectbluefin/bluefin/releases.atom` | Atom XML (200 OK) | Official image releases changelog |
| **Bluefin LTS Releases Atom** | `https://github.com/projectbluefin/bluefin-lts/releases.atom` | Atom XML (200 OK) | LTS image stream changelog |
| **Homebrew Core / Brew Releases** | `https://github.com/Homebrew/brew/releases.atom` | Atom XML (200 OK) | Homebrew toolchain & formula updates |
| **Bluefin Documentation & Blog** | `https://docs.projectbluefin.io/blog/rss.xml` | RSS 2.0 XML (200 OK) | Official blog & monthly reports feed |
| **Bluefin Discussions Atom** | `https://github.com/ublue-os/bluefin/discussions.atom` | Atom XML (200 OK) | Community announcements & discussions |

#### 2. Requested Blogs & Newsletters
| Publication | Canonical / Feed URL | Status | Verified Format |
|---|---|---|---|
| **Official CNCF Blog** | `https://www.cncf.io/blog/feed/` | Verified (200 OK) | `application/rss+xml` |
| **DevOps'ish (Chris Short's Newsletter)** | `https://devopsish.substack.com/feed` | Verified (200 OK) | `application/xml` (Substack mirror; devopsish.com is JSON-only) |
| **Chris Short's Personal Blog** | `https://chrisshort.net/index.xml` | Verified (200 OK) | `application/xml` |
| **Cassidy Williams' Blog** | `https://cassidoo.co/rss.xml` | Verified (200 OK) | `application/xml` |
| **Last Week in Cloud Native (LWCN)** | `https://lwcn.dev/?utm_source=bluefin` | **Unreachable / Parked** | Domain displays EuroDNS parking page pending validation; kept as candidate for re-check |

#### 3. Cloud Native & Developer Podcasts

##### A. CNCF Ambassador & Core Kubernetes Shows
*(Cross-referenced with official CNCF people registry `cncf/people.json`)*
- **Kubernetes Podcast from Google** — Hosted by Abdel Sghiouar (CNCF Ambassador) & Google Cloud team
  - Feed: `https://rss.libsyn.com/shows/419861/destinations/3486674.xml` (Verified)
- **OpenObservability Talks** — Hosted by Dotan Horovits (CNCF Ambassador)
  - Feed: `https://anchor.fm/s/26ef538c/podcast/rss` (Verified)
- **Geeking Out** — Hosted by Adriana Villela (CNCF Ambassador, OpenTelemetry maintainer)
  - Feed: `https://feeds.transistor.fm/geeking-out` (Verified)
- **DevOps Paradox** — Co-hosted by Viktor Farcic (CNCF Ambassador)
  - Feed: `https://rss.libsyn.com/shows/183152/destinations/1254752.xml` (Verified)
- **Agentic DevOps (Docker Talk)** — Hosted by Bret Fisher (CNCF Ambassador, Docker Captain)
  - Feed: `https://feeds.transistor.fm/agentic-devops` (Verified)
- **PurePerformance** — Co-hosted by Andi Grabner (CNCF Ambassador, Keptn co-founder)
  - Feed: `https://www.spreaker.com/show/1746210/episodes/feed` (Verified)

##### B. Cloud Architecture, Infrastructure & Observability
- **KubeFM** — Real-world Kubernetes production post-mortems and architecture breakdowns
  - Feed: `https://kube.fm/podcast.xml` (Verified clean feed, no tracking parameters)
- **The Kubelist Podcast** — Creator and maintainer interviews behind CNCF OSS projects
  - Feed: `https://www.heavybit.com/category/library/podcasts/the-kubelist-podcast/feed/feed.rss` (Verified)
- **Argo Unpacked** — GitOps, continuous delivery, and Argo workflows
  - Feed: `https://rss.libsyn.com/shows/581300/destinations/5041390.xml` (Verified)
- **The Cloudcast** — Essential independent cloud computing & platform engineering show
  - Feed: `https://anchor.fm/s/1036f0744/podcast/rss` (Verified)
- **Ship It!** — Changelog’s container infrastructure and delivery show
  - Feed: `https://changelog.com/shipit/feed` (Verified)
- **Heavy Networking** — Packet Pushers (eBPF, Cilium, service meshes, cloud infrastructure)
  - Feed: `https://feeds.packetpushers.net/PacketPushersWeeklyPodcast` (Verified)
- **The New Stack Podcast** — Cloud ecosystems, WebAssembly, and CNCF tech trends
  - Feed: `https://feeds.simplecast.com/IgzWks06` (Verified)

##### C. Software Craft, Systems & Industry Perspectives
- **Software Defined Talk** — Coté & Matt Ray (Enterprise infrastructure, cloud business analysis)
  - Feed: `https://feeds.fireside.fm/sdt/rss` (Verified)
- **Screaming in the Cloud** — Corey Quinn (Cloud architecture and economics)
  - Feed: `https://feeds.transistor.fm/screaming-in-the-cloud` (Verified)
- **The Changelog** — Deep dives into open source software craft and maintainers
  - Feed: `https://changelog.com/podcast/feed` (Verified)
- **Latent Space** — Swyx & Alessio Fanelli (Local AI models, open weights, GPU infra)
  - Feed: `https://api.substack.com/feed/podcast/1084089.rss` (Verified)
- **Software Unscripted** — Richard Feldman (Compilers, systems, programming languages)
  - Feed: `https://feeds.acast.com/public/shows/664fde3eda02bb0012bad909` (Verified)
- **CoRecursive** — Adam Gordon Bell (Stories behind pivotal software breakthroughs)
  - Feed: `https://rss.libsyn.com/shows/112428/destinations/628353.xml` (Verified)

#### 4. Recommended Engineering Blogs
- **Official Kubernetes Blog:** `https://kubernetes.io/feed.xml` (Verified)
- **GitHub Engineering Blog:** `https://github.blog/feed/` (Verified)
- **Lobste.rs:** `https://lobste.rs/rss` (Verified)
- **LWN.net (Linux Weekly News):** `https://lwn.net/headlines/rss` (Verified)

---



## Success Metrics

- Opting out leaves Pulp and existing feeds untouched; opting in gives one importable OPML and a single reader installation.

## Non-Goals

- No silent installation, Pulp database edits, PolicyKit escalation or automatic recurring feed sync.
