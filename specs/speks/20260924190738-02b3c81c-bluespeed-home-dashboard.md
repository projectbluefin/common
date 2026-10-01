---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-02b3c81c-bluespeed-home-dashboard

## Overview

A Bluespeed user can read physical host and cluster health from one understandable home dashboard without learning the full cluster-management console. The view remains read-only and distinguishes the physical hub, k3s VMs and enrolled client laptops. Source: [bluespeed#28](https://github.com/projectbluefin/bluespeed/issues/28).

## Requirements

- [ ] **Show physical host health**
  The home view presents CPU, memory, data-volume disk and uptime for the hub.
- [ ] **Show cluster health**
  The view lists k3s nodes, versions and state, running/total pods and error pods.
- [ ] **Show cluster age honestly**
  The Forged on date represents the first observed healthy cluster, not the UI deployment time.
- [ ] **Keep clients distinct**
  An enrolled laptop appears as a client, not a k3s node.

## Constraints

- Use OTel→Prometheus for host metrics and k3s APIs/node labels for cluster metadata.
- No registry.yaml, separate database or theme engine; at most two custom label fields per node.
- KubeStellar Console owns cluster management; Bluespeed home is read-only.

## Acceptance Criteria

- [ ] **Show physical host health**
  Reported values correspond to OTel/Prometheus observations and do not offer mutating controls.
- [ ] **Show cluster health**
  Adding a node changes the displayed node list and error state without editing a registry file.
- [ ] **Show cluster age honestly**
  The displayed date matches the cluster’s first-healthy timestamp and remains stable across page reloads.
- [ ] **Keep clients distinct**
  Node and client counts remain separate in a topology with a physical hub, VMs and a laptop.

## Technical Approach

- The source issue relates to #16 contributor loop, #25 local DNS and #27 naming; its four native sub-issues show three closed and #23 OTel external-node installation open.
- Do not turn this home page into a second KubeStellar Console.

## Success Metrics

- Host and cluster panels reflect measured state and stay readable with more k3s nodes.

## Non-Goals

- No database-backed registry, infrastructure mutation, per-node theme editor or laptop-as-node model.
