#!/usr/bin/env python3
"""Reconcile common issues and PRs. Dry-run by default; never writes other repos."""

from __future__ import annotations

import argparse
import base64
import hashlib
import os
import json
from datetime import datetime, timezone
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote
from uuid import uuid4

REPOSITORY = "projectbluefin/common"
CATALOG_PATH = Path(__file__).resolve().parents[1] / ".github/issue-policy.json"
COMMENT_MARKER = "<!-- common-issue-lifecycle:v1 -->"
EMPTY = {"", "_no response_", "no response", "none"}


class StaleRecord(RuntimeError):
    """A human changed this record; skip it rather than overwrite that work."""


def headings(body):
    matches = list(re.finditer(r"^#{2,6}\s+(.+?)\s*$", body or "", re.M))
    return {
        match[1].lower(): (
            body[
                match.end() : matches[i + 1].start()
                if i + 1 < len(matches)
                else len(body)
            ]
        ).strip()
        for i, match in enumerate(matches)
    }


def labels_of(record):
    return {
        label if isinstance(label, str) else label["name"]
        for label in record.get("labels", [])
    }


def event_order(event):
    return (event.get("created_at", ""), event.get("id") or 0)


def latest_event(timeline, label, event="labeled"):
    matches = [
        e
        for e in timeline
        if e.get("event") == event and (e.get("label") or {}).get("name") == label
    ]
    return max(matches, key=event_order, default=None)


def trusted_event(event, facts):
    if not event:
        return False
    actor = event.get("actor") or {}
    return actor.get("type") == "User" and facts.get("permissions", {}).get(
        actor.get("login")
    ) in {"write", "maintain", "admin"}


def approved_scope(timeline, facts):
    event = latest_event(timeline, "triage/accepted")
    if not trusted_event(event, facts) or "last_edited_at" not in facts:
        return False
    if facts["last_edited_at"] and facts["last_edited_at"] >= event["created_at"]:
        return False
    withdrawal = latest_event(timeline, "triage/accepted", "unlabeled")
    if trusted_event(withdrawal, facts) and event_order(withdrawal) > event_order(
        event
    ):
        return False
    # Returning to assessment or information gathering invalidates that grant,
    # including a policy-generated request. A reporter reply cannot revive it.
    resets = [
        latest_event(timeline, label)
        for label in ("needs-triage", "triage/needs-information")
    ]
    return not any(
        reset and event_order(reset) > event_order(event) for reset in resets
    )


def delivery_evidence(body):
    text = headings(body).get("delivery evidence", "")
    image = re.search(r"^Image:\s*(\S+@sha256:[0-9a-f]{64})\s*$", text, re.M | re.I)
    revision = re.search(r"^Fix revision:\s*([0-9a-f]{40})\s*$", text, re.M | re.I)
    release = re.search(r"^Release/build:\s*(https://\S+)\s*$", text, re.M | re.I)
    verify = re.search(r"^Verify:\s*(\S.*)$", text, re.M | re.I)
    if not all((image, revision, release, verify)):
        return None
    return {
        "image": image[1],
        "revision": revision[1],
        "url": release[1],
        "verify": verify[1],
    }


def referenced_issues(body):
    # Full repository qualifiers must match; never interpret another repo's #N locally.
    expression = r"\b(?:refs?|references|close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+(?:(https://github\.com/[^\s]+/issues/)|(\w[\w.-]*/[\w.-]+))?#?(\d+)\b"
    numbers = set()
    for match in re.finditer(expression, body or "", re.I):
        url, repo, number = match.groups()
        if url and url != f"https://github.com/{REPOSITORY}/issues/":
            continue
        if repo and repo != REPOSITORY:
            continue
        numbers.add(int(number))
    return numbers


def plan(record, facts, catalog, *, migrate=False, labels_only=False):
    """Return a proposed public label/comment/state transition without performing I/O."""
    quiet = migrate or labels_only
    current = labels_of(record)
    stages, retired = set(catalog["stages"]), set(catalog["retired_stages"])
    if record.get("state") == "closed":
        return {
            "number": record["number"],
            "add": [],
            "remove": sorted(current & retired),
            "comment": None,
            "close": False,
            "stage": None,
        }
    if "pull_request" in record:
        pr = facts.get("pull_request", {})
        if pr.get("draft"):
            status = "Draft implementation"
            next_step = "Contributor: finish the agreed changes and tests, then mark the PR ready for review."
        elif pr.get("native_mergeable") == "CONFLICTING":
            status = "PR has merge conflicts"
            next_step = "Contributor: resolve the conflicts against the target branch, rerun the tests, address any outstanding review requests, and re-request review."
        elif pr.get("review_decision") == "CHANGES_REQUESTED":
            status = "Reviewer requested changes"
            next_step = "Contributor: address the outstanding review findings, run the relevant tests, and re-request review on the new head."
        elif pr.get("review_decision") == "APPROVED":
            status = "Native review approved; checks and merge controls still apply"
            next_step = "Contributor: resolve any failing checks. Merge automation/maintainer: let the required checks and native merge queue complete; do not bypass them."
        else:
            status = "Awaiting native PR review"
            next_step = "Reviewers: review the current head. Contributor: address requested changes and re-request review."
        text = f"{COMMENT_MARKER}\n**Status:** {status}\n\n**Next actor and steps:** {next_step}\n\nRequired reviews, checks, and the merge queue remain unchanged. Use non-closing references for image reports that have not shipped.\n\n**Reporter action:** none until the linked report requests information or verification."
        return {
            "number": record["number"],
            "add": [],
            "remove": sorted(current & (stages | retired)),
            "comment": None if quiet else text,
            "close": False,
            "stage": None,
        }

    body = record.get("body") or ""
    fields = headings(body)
    preference = fields.get("automation preference", "").strip()
    human_only = (
        "human-only" in current
        or preference == "Human interaction only"
        or bool(re.search(r"<!--\s*automation-preference:\s*human-only\s*-->", body))
    )
    if not preference or preference.lower() in EMPTY:
        human_only |= bool(
            re.search(r"<!--\s*[\w-]*queue-preference:\s*3-human-queue\s*-->", body)
        )
    human_only |= "3-human-queue" in current
    if migrate and "needs-human" in current and not (current & stages):
        human_only = True
    tracking = record["number"] in catalog["standing_issues"] or bool(
        current & {"tracking", "Epic", "epic"}
    )
    kind = {label for label in current if label.startswith("kind/")}
    if not kind:
        if (
            "bug" in current
            or "what happened?" in fields
            or re.search(
                r"<!--\s*report-type:\s*bug\s*-->|^## .*\bBug Report\b",
                body,
                re.M | re.I,
            )
        ):
            kind = {"kind/bug"}
        elif "problem to solve" in fields or re.search(
            r"<!--\s*report-type:\s*feature\s*-->|^## .*\bFeature Request\b",
            body,
            re.M | re.I,
        ):
            kind = {"kind/feature"}
        elif tracking:
            kind = {"kind/task"}
    timeline = facts.get("timeline", [])
    approved = approved_scope(timeline, facts)
    found = current & stages
    human_events = [latest_event(timeline, label) for label in found]
    human_events = [e for e in human_events if trusted_event(e, facts)]
    decision = max(human_events, key=event_order, default=None)
    requested = decision["label"]["name"] if decision else None
    stage = "needs-triage"
    if (
        requested == "triage/needs-information"
        or found == {"triage/needs-information"}
        or "needs-decision" in current
    ):
        stage = "triage/needs-information"
    if approved and not tracking and "needs-decision" not in current:
        stage = "triage/accepted"
    evidence = delivery_evidence(body)
    if (
        requested in {"awaiting-release", "needs-verification"}
        and "last_edited_at" in facts
    ):
        recent = (
            not facts["last_edited_at"]
            or decision["created_at"] > facts["last_edited_at"]
        )
        if recent:
            stage = (
                requested
                if requested != "needs-verification" or evidence
                else "awaiting-release"
            )
    merged = [
        pr
        for pr in facts.get("linked_prs", [])
        if pr.get("merged_at") and record["number"] in referenced_issues(pr.get("body"))
    ]
    image_details = fields.get(
        "image details", fields.get("image and version", fields.get("system", ""))
    ).lower()
    image_report = image_details not in EMPTY and "not applicable" not in image_details
    if approved and merged and not tracking and image_report:
        stage = "awaiting-release" if stage != "needs-verification" else stage

    info_event = latest_event(timeline, "triage/needs-information")
    comments = facts.get("comments", [])
    actor = record.get("user", {}).get("login")
    requester = "maintainer" if "needs-decision" in current or tracking else "reporter"
    replies = [
        c
        for c in comments
        if c.get("user", {}).get("type") == "User"
        and c.get("user", {}).get("login") == actor
        and (
            not info_event or c.get("created_at", "") > info_event.get("created_at", "")
        )
        and COMMENT_MARKER not in (c.get("body") or "")
    ]
    edited_answer = (
        info_event
        and facts.get("last_edited_at")
        and facts["last_edited_at"] > info_event["created_at"]
    )
    answered = bool(
        requester == "reporter" and info_event and (replies or edited_answer)
    )
    if stage == "triage/needs-information" and answered:
        stage = "needs-triage"

    missing = []
    if "what happened?" in fields:
        for name in (
            "what happened?",
            "what did you expect?",
            "steps to reproduce",
            "image details",
        ):
            if fields.get(name, "").lower() in EMPTY:
                missing.append(name)
    elif "problem to solve" in fields:
        for name in ("problem to solve", "desired outcome", "affected component"):
            if fields.get(name, "").lower() in EMPTY:
                missing.append(name)
    if (
        missing
        and stage in {"needs-triage", "triage/accepted"}
        and not tracking
        and not answered
    ):
        stage = "triage/needs-information"

    desired = {stage} | kind
    if not kind:
        desired.add("needs-kind")
    if tracking:
        desired.add("tracking")
    if human_only:
        desired.add("human-only")
    gated = (
        stage != "triage/accepted"
        or not kind
        or human_only
        or tracking
        or bool(current & {"blocked", "hold", "needs-decision"})
    )
    if gated:
        desired.add("needs-human")
    managed = stages | retired | {"needs-kind", "needs-human"}
    # Never clear an independent human/app routing gate just because scope was
    # accepted. Only the lifecycle bot's own automatic gate is removable.
    gate_event = latest_event(timeline, "needs-human")
    gate_actor = (gate_event or {}).get("actor") or {}
    automatic_gate = (
        gate_actor.get("type") == "Bot"
        and gate_actor.get("login") == "github-actions[bot]"
    )
    if "needs-human" in current and not automatic_gate:
        desired.add("needs-human")

    close = False
    if stage == "needs-verification":
        verify_event = latest_event(timeline, "needs-verification")
        responses = [
            c
            for c in replies
            if re.match(
                r"^\s*(?:confirmed fixed|still broken)\b", c.get("body") or "", re.I
            )
            and verify_event
            and c["created_at"] > verify_event["created_at"]
        ]
        response = max(
            responses, key=lambda c: (c["created_at"], c.get("id", 0)), default=None
        )
        if response and re.match(r"^\s*still broken\b", response["body"], re.I):
            desired.difference_update(stages)
            desired.update({"needs-triage", "needs-human"})
            stage = "needs-triage"
        elif response:
            close = True

    next_steps = (
        "Maintainer: review the scope and completion criteria in the issue body, then use GitHub's **Labels** picker to add `triage/accepted` if you approve implementation. "
        "Do not remove `needs-triage` or `needs-human` to signal approval: the bot restores them until acceptance is recorded. "
        "After valid acceptance, the bot clears the waiting stage and its automatic admission gate unless a block, hold, or human-only preference still applies; acceptance does not assign a contributor. "
        "If a specific question prevents acceptance, ask it and select `triage/needs-information`; if declining or marking a duplicate, close with the reason. "
        "`/hive approve` is not a Common lifecycle acceptance action."
    )
    reporter = "No action needed unless information is requested."
    if tracking:
        next_steps = "Maintainer: maintain this standing tracker and link actionable child issues. Do not assign the tracker as an implementation task."
    elif stage == "triage/needs-information":
        if missing:
            details = ", ".join(missing)
            next_steps = f"Reporter: supply {details}. Reply normally; a maintainer will reassess your response."
            if "image details" in missing:
                next_steps += " Run `bootc status` and paste the complete output, or explain that the machine cannot boot, the command fails, or it is not applicable."
            reporter = "Provide the requested information in a reply or edit the corresponding form fields."
        elif requester == "maintainer":
            next_steps = (
                "Maintainer: resolve the recorded decision and update the agreed scope and completion criteria in the issue body first. "
                "Then remove `needs-decision` if its reason is resolved and use GitHub's **Labels** picker to add `triage/accepted`. "
                "Removing a waiting label or posting `/hive approve` does not record Common implementation acceptance."
            )
        else:
            requests = [
                c
                for c in comments
                if c.get("user", {}).get("type") == "User"
                and facts.get("permissions", {}).get(c["user"].get("login"))
                in {"write", "maintain", "admin"}
                and COMMENT_MARKER not in (c.get("body") or "")
                and "factory issue pipeline" not in (c.get("body") or "")
                and (
                    "?" in (c.get("body") or "")
                    or re.search(r"\bplease\b", c.get("body") or "", re.I)
                )
            ]
            if requests:
                next_steps = f"Reporter: answer the maintainer's request in [this comment]({requests[-1]['html_url']}). Reply normally; a maintainer will reassess."
                reporter = "Answer the linked request."
            else:
                next_steps = "Maintainer: state the exact missing information or decision and name who should supply it. Reporter: reply once that request is clear."
    elif stage == "triage/accepted":
        next_steps = "Assigned contributor: implement only the accepted scope, run its tests, and open a linked PR. Reviewers: review the current head; required checks and merge controls still apply."
        if not record.get("assignees") and not facts.get("linked_prs"):
            next_steps = "Maintainer: use GitHub's **Assignees** picker to assign an available contributor for the accepted scope, or explicitly route the work. Acceptance does not self-assign. Contributor: implement that scope, test it, and open a linked PR."
        if human_only:
            next_steps = "Maintainer: assign a human contributor. Human contributor: implement the accepted scope and open a linked PR. Machine analysis and agent implementation are excluded."
        if "needs-human" in current and not automatic_gate and not human_only:
            next_steps = (
                "Maintainer: a human or app added an independent `needs-human` gate. Resolve its recorded reason, then explicitly remove that label only when implementation is allowed; the bot will not clear it for you. "
                + next_steps
            )
    elif stage == "awaiting-release":
        next_steps = "Maintainer/release owner: verify that the actual fix has merged, then track its consumption and publication in the affected image. Record `Delivery evidence` with Image, Fix revision, Release/build, and Verify fields before selecting `needs-verification`. A green run with publication skipped is not delivery."
        reporter = "No update or verification requested yet. A merged change is not proof it reached your image."
    elif stage == "needs-verification" and evidence:
        next_steps = f"Reporter: update to the image containing the fix documented in [this release/build]({evidence['url']}), reboot if required, and {evidence['verify']}"
        reporter = f"Check image `{evidence['image']}`. Reply `Confirmed fixed` with the version tested, or `Still broken` with what you observed."
    if current & {"blocked", "hold"}:
        next_steps = (
            "Maintainer/dependency owner: resolve the recorded blocker or hold, then have its owner remove `blocked` or `hold` using the Labels picker before new implementation dispatch. Preserve existing assignments and PRs. "
            + next_steps
        )
    if not kind:
        next_steps = (
            "Maintainer: classify the issue before scheduling it. " + next_steps
        )
    if "triage/accepted" in current and not approved:
        next_steps = (
            "Maintainer: the current scope lacks valid human acceptance or changed after approval. Review the body first, then use the Labels picker to select `triage/accepted` again to record a fresh acceptance event. "
            + next_steps
        )
    links = [
        f"[PR #{pr['number']}]({pr['html_url']})"
        for pr in facts.get("linked_prs", [])
        if not pr.get("merged_at") and pr.get("state") == "open"
    ]
    existing = (
        "\n\n**Existing work:** "
        + ", ".join(links)
        + ". Preserve this work; do not start a duplicate implementation."
        if links
        else ""
    )
    titles = {
        "needs-triage": "Awaiting maintainer assessment",
        "triage/needs-information": "Waiting for information or a decision",
        "triage/accepted": "Accepted for implementation",
        "awaiting-release": "Merged fix awaiting image delivery",
        "needs-verification": "Published fix awaiting reporter verification",
    }
    text = f"{COMMENT_MARKER}\n**Status:** {titles[stage]}\n\n**Next actor and steps:** {next_steps}\n\n**Reporter action:** {reporter}{existing}"
    if close:
        text = f"{COMMENT_MARKER}\n**Status:** Reporter confirmed the published fix.\n\n**Next actor and steps:** Lifecycle automation closes this report as completed. Maintainer: retain its delivery evidence.\n\n**Reporter action:** none; reopen or file a linked report if the problem returns."
    return {
        "number": record["number"],
        "add": sorted(desired - current),
        "remove": sorted((current & managed) - desired),
        "comment": None if quiet else text,
        "close": False if quiet else close,
        "stage": stage,
    }


class GitHub:
    def __init__(self, repo):
        if repo != REPOSITORY:
            raise ValueError(f"This pilot only writes {REPOSITORY}")
        self.repo = repo
        self.permission_cache = {}
        self.pr_cache = {}

    def request(self, method, path, body=None, *, pages=False):
        if (
            method != "GET"
            and path != "graphql"
            and not path.startswith(f"repos/{REPOSITORY}/")
        ):
            raise ValueError("Write outside common refused")
        if path == "graphql" and (body or {}).get("query", "").lstrip().startswith(
            "mutation"
        ):
            raise ValueError("GraphQL mutations are not part of this issue policy")
        command = ["gh", "api", "--method", method, path]
        if pages:
            command += ["--paginate", "--slurp"]
        if body is not None:
            command += ["--input", "-"]
        result = subprocess.run(
            command,
            input=json.dumps(body) if body is not None else None,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(
                f"GitHub {method} {path} failed: {result.stderr.strip()}"
            )
        if not result.stdout.strip():
            return None
        value = json.loads(result.stdout)
        return [item for page in value for item in page] if pages else value

    def permission(self, login):
        if login not in self.permission_cache:
            data = self.request(
                "GET",
                f"repos/{self.repo}/collaborators/{quote(login, safe='')}/permission",
            )
            self.permission_cache[login] = data.get("permission", "none")
        return self.permission_cache[login]

    def collect(self, number):
        root = f"repos/{self.repo}/issues/{number}"
        record = self.request("GET", root)
        if not record.get("html_url", "").startswith(
            f"https://github.com/{REPOSITORY}/"
        ):
            raise ValueError("Issue transferred outside common; no writes permitted")
        comments = self.request("GET", root + "/comments?per_page=100", pages=True)
        timeline = self.request("GET", root + "/timeline?per_page=100", pages=True)
        facts = {
            "comments": comments,
            "timeline": timeline,
            "permissions": {},
            "linked_prs": [],
        }
        actors = {
            e["actor"]["login"]
            for e in timeline
            if (e.get("actor") or {}).get("type") == "User"
            and e.get("event") in {"labeled", "unlabeled"}
        }
        actors |= {
            c["user"]["login"]
            for c in comments
            if c.get("user", {}).get("type") == "User"
        }
        facts["permissions"] = {login: self.permission(login) for login in actors}
        if "pull_request" in record:
            facts["pull_request"] = self.request(
                "GET", f"repos/{self.repo}/pulls/{number}"
            )
            query = 'query($number:Int!){repository(owner:"projectbluefin",name:"common"){pullRequest(number:$number){reviewDecision mergeable}}}'
            native = self.request(
                "POST", "graphql", {"query": query, "variables": {"number": number}}
            )
            if native.get("errors"):
                raise RuntimeError(
                    "Cannot read native PR state: " + json.dumps(native["errors"])
                )
            native = native["data"]["repository"]["pullRequest"]
            facts["pull_request"].update(
                {
                    "review_decision": native["reviewDecision"],
                    "native_mergeable": native["mergeable"],
                }
            )
            return record, facts
        query = 'query($number:Int!){repository(owner:"projectbluefin",name:"common"){issue(number:$number){lastEditedAt}}}'
        result = self.request(
            "POST", "graphql", {"query": query, "variables": {"number": number}}
        )
        if result.get("errors"):
            raise RuntimeError(
                "Cannot verify issue edit history: " + json.dumps(result["errors"])
            )
        facts["last_edited_at"] = result["data"]["repository"]["issue"]["lastEditedAt"]
        for event in timeline:
            source = (event.get("source") or {}).get("issue") or {}
            url = source.get("html_url", "")
            if "pull_request" not in source or not url.startswith(
                f"https://github.com/{self.repo}/pull/"
            ):
                continue
            pr_number = source["number"]
            if pr_number not in self.pr_cache:
                self.pr_cache[pr_number] = self.request(
                    "GET", f"repos/{self.repo}/pulls/{pr_number}"
                )
            pr = self.pr_cache[pr_number]
            if number in referenced_issues(pr.get("body")):
                facts["linked_prs"].append(pr)
        return record, facts

    def require_deployed_policy(self):
        # Retiring definitions must not break active default-branch callers or clients.
        for relative in (
            "scripts/common_issue_policy.py",
            ".github/workflows/issue-lifecycle.yml",
            ".github/issue-policy.json",
        ):
            data = self.request("GET", f"repos/{REPOSITORY}/contents/{relative}")
            local = Path(__file__).resolve().parents[1] / relative
            if base64.b64decode(data["content"]) != local.read_bytes():
                raise RuntimeError(
                    "Retirement requires this reviewed policy deployed on the default branch"
                )

    def sync_catalog(self, catalog, apply):
        current = {
            label["name"]: label
            for label in self.request(
                "GET", f"repos/{self.repo}/labels?per_page=100", pages=True
            )
        }
        for name, definition in (catalog["stages"] | catalog["labels"]).items():
            have = current.get(name)
            if have and all(
                have.get(key) == value for key, value in definition.items()
            ):
                continue
            print(
                json.dumps(
                    {"catalog": name, "operation": "update" if have else "create"}
                )
            )
            if apply:
                path = f"repos/{self.repo}/labels" + (
                    "/" + quote(name, safe="") if have else ""
                )
                self.request(
                    "PATCH" if have else "POST", path, {"name": name, **definition}
                )

    def apply(self, record, facts, result):
        # Re-read immediately before writing; abandon a stale plan rather than overwrite a human.
        fresh = self.request("GET", f"repos/{self.repo}/issues/{record['number']}")
        if (
            not fresh.get("html_url", "").startswith(
                f"https://github.com/{REPOSITORY}/"
            )
            or fresh["updated_at"] != record["updated_at"]
            or labels_of(fresh) != labels_of(record)
            or fresh.get("body") != record.get("body")
        ):
            raise StaleRecord(
                f"#{record['number']} changed during reconciliation; no stale writes applied"
            )
        root = f"repos/{self.repo}/issues/{record['number']}"
        # Install negative gates before removing old labels; never clear unrelated namespaces.
        if result["add"]:
            self.request("POST", root + "/labels", {"labels": result["add"]})
        for label in result["remove"]:
            self.request("DELETE", root + "/labels/" + quote(label, safe=""))
        if result["comment"]:
            authorized = lambda c: (
                c.get("user", {}).get("type") == "Bot"
                and c.get("user", {}).get("login") == "github-actions[bot]"
            )
            prior = [
                c
                for c in facts["comments"]
                if (c.get("body") or "").startswith(COMMENT_MARKER) and authorized(c)
            ]
            if not prior:
                # Only machine-authored notices are reusable. Human history is never rewritten.
                prior = [
                    c
                    for c in facts["comments"]
                    if re.match(
                        r"^This issue has been marked .+ as part of the factory issue pipeline\.",
                        (c.get("body") or "").strip(),
                    )
                    and authorized(c)
                ]
            action = (
                result["comment"]
                .split("**Next actor and steps:**", 1)[-1]
                .split("**Existing work:**", 1)[0]
            )
            requests_reporter = result["stage"] == "needs-verification" or (
                result["stage"] == "triage/needs-information"
                and (
                    "**Reporter action:** Provide" in action
                    or "**Reporter action:** Answer" in action
                )
            )
            notification = None
            text = result["comment"]
            if requests_reporter and record.get("user", {}).get("type") == "User":
                timeline = self.request(
                    "GET", root + "/timeline?per_page=100", pages=True
                )
                request_event = latest_event(timeline, result["stage"])
                request_id = (request_event or {}).get("id", "initial")
                key = hashlib.sha256(f"{request_id}:{action}".encode()).hexdigest()
                notification = "<!-- common-issue-request:" + key + " -->"
                person = record["user"]["login"]
                text = (
                    text.replace(COMMENT_MARKER, COMMENT_MARKER + f"\n@{person}", 1)
                    + "\n\n"
                    + notification
                )
            already_notified = notification and any(
                notification in (c.get("body") or "") and authorized(c)
                for c in facts["comments"]
            )
            if prior:
                if prior[-1]["body"] != text:
                    self.request(
                        "PATCH",
                        f"repos/{self.repo}/issues/comments/{prior[-1]['id']}",
                        {"body": text},
                    )
                if notification and not already_notified:
                    # Updating the status is not a notification. A new targeted comment is.
                    notice = text.replace(
                        COMMENT_MARKER, "Common lifecycle action request", 1
                    )
                    self.request("POST", root + "/comments", {"body": notice})
            else:
                self.request("POST", root + "/comments", {"body": text})
        if result["close"]:
            self.request(
                "PATCH", root, {"state": "closed", "state_reason": "completed"}
            )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=REPOSITORY, choices=[REPOSITORY])
    parser.add_argument("--issue", type=int, action="append")
    parser.add_argument("--event-file", type=Path)
    parser.add_argument(
        "--snapshot",
        type=Path,
        help="read-only issue/facts fixture; never used for live writes",
    )
    parser.add_argument(
        "--output", type=Path, help="save the preview/snapshot for review"
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--labels-only",
        action="store_true",
        help="repair labels without comments or closures",
    )
    parser.add_argument(
        "--migrate",
        action="store_true",
        help="conservatively migrate existing human-queue/needs-human preferences",
    )
    parser.add_argument(
        "--retire-labels",
        action="store_true",
        help="remove retired definitions only after all assignments have been migrated",
    )
    parser.add_argument(
        "--confirm-client-cutover",
        action="store_true",
        help="acknowledge older report clients no longer need retired definitions",
    )
    args = parser.parse_args(argv)
    if args.apply and (args.dry_run or args.snapshot):
        parser.error("--apply cannot be combined with --dry-run or --snapshot")
    if args.retire_labels and args.apply and not args.confirm_client_cutover:
        parser.error(
            "retain inert definitions until report clients are updated; retirement requires --confirm-client-cutover"
        )
    if args.apply and os.environ.get("GITHUB_ACTIONS") != "true":
        parser.error(
            "Apply through the merged common workflow_dispatch; a local user token would give automatic gates human provenance"
        )
    catalog = json.loads(CATALOG_PATH.read_text())
    github = GitHub(args.repo)
    if args.apply:
        github.require_deployed_policy()
    if args.snapshot:
        entries = json.loads(args.snapshot.read_text())
    else:
        numbers = args.issue
        if args.event_file:
            event = json.loads(args.event_file.read_text())
            if event.get("repository", {}).get("full_name") != REPOSITORY:
                parser.error("event repository is outside the common pilot")
            target = event.get("issue") or event.get("pull_request")
            numbers = [target["number"]] if target else None
            if event.get("pull_request"):
                numbers += sorted(referenced_issues(event["pull_request"].get("body")))
        if numbers is None:
            numbers = [
                i["number"]
                for i in github.request(
                    "GET",
                    f"repos/{args.repo}/issues?state=open&per_page=100",
                    pages=True,
                )
            ]
        entries = []
        for number in dict.fromkeys(numbers):
            record, facts = github.collect(number)
            entries.append({"record": record, "facts": facts})
    output = [
        {
            **entry,
            "plan": plan(
                entry["record"],
                entry["facts"],
                catalog,
                migrate=args.migrate,
                labels_only=args.labels_only,
            ),
        }
        for entry in entries
    ]
    legacy_changes = any(
        set(entry["plan"]["remove"]) & set(catalog["retired_stages"])
        for entry in output
    )
    if args.apply and (args.migrate or args.retire_labels or legacy_changes):
        # Archive old assignments and definitions, including closed history, before any mutation.
        backup_dir = Path.home() / ".local/state/common-issue-policy"
        backup_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup_path = backup_dir / f"{stamp}-{uuid4().hex}.json"
        backup = {
            "repository": REPOSITORY,
            "issues": github.request(
                "GET", f"repos/{REPOSITORY}/issues?state=all&per_page=100", pages=True
            ),
            "labels": github.request(
                "GET", f"repos/{REPOSITORY}/labels?per_page=100", pages=True
            ),
            "preview": output,
        }
        backup_path.write_text(json.dumps(backup, indent=2) + "\n")
        print(f"Migration backup: {backup_path}")
    if not args.snapshot:
        github.sync_catalog(catalog, args.apply)
    skipped = []
    for entry in output:
        result = entry["plan"]
        print(
            json.dumps(
                {
                    "number": result["number"],
                    "stage": result["stage"],
                    "add": result["add"],
                    "remove": result["remove"],
                    "close": result["close"],
                }
            )
        )
        if args.apply:
            try:
                github.apply(entry["record"], entry["facts"], result)
            except StaleRecord as error:
                skipped.append(result["number"])
                print(str(error), file=sys.stderr)
    if args.output:
        args.output.write_text(json.dumps(output, indent=2) + "\n")
    if skipped:
        raise RuntimeError(
            f"Skipped changed records {skipped}; review their current state and let the next reconciliation reassess them. Other records were processed; backup retained."
        )
    if args.retire_labels and args.apply:
        remaining = github.request(
            "GET", f"repos/{args.repo}/issues?state=open&per_page=100", pages=True
        )
        stale = [
            (i["number"], sorted(labels_of(i) & set(catalog["retired_stages"])))
            for i in remaining
            if labels_of(i) & set(catalog["retired_stages"])
        ]
        if stale:
            raise RuntimeError(
                "Retirement refused; numbered/obsolete assignments remain: "
                + json.dumps(stale)
            )
        definitions = {
            i["name"]
            for i in github.request(
                "GET", f"repos/{args.repo}/labels?per_page=100", pages=True
            )
        }
        for name in catalog["retired_stages"]:
            if name in definitions:
                github.request(
                    "DELETE", f"repos/{args.repo}/labels/{quote(name, safe='')}"
                )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
