"""Consumer-visible common lifecycle transitions and authorization boundaries."""

import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "common_issue_policy", ROOT / "scripts/common_issue_policy.py"
)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)
CATALOG = json.loads((ROOT / ".github/issue-policy.json").read_text())
T0 = "2026-10-02T10:00:00Z"
T1 = "2026-10-02T11:00:00Z"
T2 = "2026-10-02T12:00:00Z"


def issue(labels=(), body="", number=10):
    return {
        "number": number,
        "state": "open",
        "body": body,
        "labels": list(labels),
        "user": {"login": "reporter", "type": "User"},
        "assignees": [],
        "updated_at": T0,
    }


def event(label, actor="maintainer", kind="User", time=T1, action="labeled"):
    return {
        "event": action,
        "label": {"name": label},
        "actor": {"login": actor, "type": kind},
        "created_at": time,
        "id": 1,
    }


def facts(timeline=(), comments=(), edited=None, prs=()):
    return {
        "timeline": list(timeline),
        "comments": list(comments),
        "last_edited_at": edited,
        "permissions": {"maintainer": "maintain", "outsider": "read"},
        "linked_prs": list(prs),
    }


def reply(text, actor="reporter", kind="User", time=T2):
    return {
        "id": 2,
        "body": text,
        "created_at": time,
        "html_url": "https://github.com/projectbluefin/common/issues/10#issuecomment-2",
        "user": {"login": actor, "type": kind},
    }


def final_labels(record, result):
    return (policy.labels_of(record) - set(result["remove"])) | set(result["add"])


def accepted(labels=()):
    return issue(("triage/accepted", "kind/feature", *labels)), facts(
        (event("triage/accepted"),)
    )


def delivery_body():
    return (
        "### Delivery evidence\nImage: ghcr.io/projectbluefin/utah:stable@sha256:"
        + "a" * 64
        + "\nFix revision: "
        + "b" * 40
        + "\nRelease/build: https://github.com/projectbluefin/utah/actions/runs/1\nVerify: repeat the original reproduction steps.\n"
    )


def test_noncollaborator_report_is_initialized_from_body_not_client_labels():
    record = issue(
        body="<!-- report-type: bug -->\n<!-- automation-preference: human-only -->\n### Summary\nBroken update\n"
    )
    result = policy.plan(record, facts(), CATALOG)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/bug",
        "human-only",
        "needs-human",
    }
    assert not result["close"]


@pytest.mark.parametrize("label", ["3-clanker-queue", "1-triage", "4-review"])
def test_legacy_queue_is_not_implementation_approval(label):
    record = issue((label, "kind/feature"))
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/feature",
        "needs-human",
    }


def test_old_human_queue_preference_survives_retirement():
    record = issue(("3-human-queue", "kind/bug"))
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/bug",
        "human-only",
        "needs-human",
    }


@pytest.mark.parametrize(
    "actor,kind,permission",
    [("outsider", "User", "read"), ("agent[bot]", "Bot", "admin")],
)
def test_forged_acceptance_cannot_release_native_hive_gate(actor, kind, permission):
    record = issue(("triage/accepted", "needs-human", "kind/bug"))
    data = facts((event("triage/accepted", actor, kind),))
    data["permissions"][actor] = permission
    result = policy.plan(record, data, CATALOG)
    assert final_labels(record, result) == {"needs-triage", "needs-human", "kind/bug"}


def test_authenticated_maintainer_acceptance_releases_gate():
    record, data = accepted(("needs-human",))
    data["timeline"].insert(
        0, event("needs-human", "github-actions[bot]", "Bot", time=T0)
    )
    result = policy.plan(record, data, CATALOG)
    assert final_labels(record, result) == {"triage/accepted", "kind/feature"}


def test_edited_spec_revokes_acceptance_without_reassigning_work():
    record, data = accepted()
    record["assignees"] = [{"login": "contributor"}]
    data["last_edited_at"] = T2
    result = policy.plan(record, data, CATALOG)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/feature",
        "needs-human",
    }
    assert record["assignees"] == [{"login": "contributor"}]


def test_explicit_withdrawal_is_not_resurrected_by_old_approval():
    record = issue(("needs-triage", "kind/feature"))
    data = facts(
        (
            event("triage/accepted"),
            event("triage/accepted", time=T2, action="unlabeled"),
        )
    )
    result = policy.plan(record, data, CATALOG)
    assert "triage/accepted" not in final_labels(record, result)
    assert "needs-human" in final_labels(record, result)


def test_unreadable_edit_history_fails_closed():
    record, data = accepted()
    del data["last_edited_at"]
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


@pytest.mark.parametrize("overlay", ["blocked", "hold", "human-only"])
def test_negative_overlay_outweighs_human_acceptance(overlay):
    record, data = accepted((overlay, "needs-human"))
    result = policy.plan(record, data, CATALOG)
    assert {overlay, "needs-human", "triage/accepted"} <= final_labels(record, result)


def test_all_orthogonal_labels_and_both_overlays_survive_migration():
    preserve = {
        "blocked",
        "hold",
        "hive/hosted-projectbluefin-knuckle-gjvq",
        "agent/security",
        "security",
        "quality",
        "lgtm",
        "automerge",
    }
    record = issue((*preserve, "1-triage", "3-clanker-queue"))
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert preserve <= final_labels(record, result)
    assert final_labels(record, result) & set(CATALOG["stages"]) == {"needs-triage"}


def test_bot_reply_cannot_clear_information_request():
    record = issue(("triage/needs-information", "kind/bug"))
    data = facts(
        (event("triage/needs-information"),),
        (reply("Collected evidence", "agent[bot]", "Bot"),),
    )
    assert policy.plan(record, data, CATALOG)["stage"] == "triage/needs-information"


def test_reporter_reply_returns_to_triage_not_approval():
    record = issue(("triage/needs-information", "kind/bug"))
    data = facts(
        (event("triage/needs-information"),), (reply("Here are the requested details"),)
    )
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "needs-triage"
    assert "needs-human" in final_labels(record, result)


def test_unknown_kind_is_flagged_without_guessing_from_title():
    record = issue()
    record["title"] = "A bug and a feature"
    result = policy.plan(record, facts(), CATALOG)
    assert final_labels(record, result) == {"needs-triage", "needs-kind", "needs-human"}


def test_feature_request_does_not_demand_bootc_or_diagnostics():
    body = "### Problem to solve\nA task is difficult\n### Desired outcome\nMake it easier\n### Affected component\nujust\n"
    record = issue(body=body)
    result = policy.plan(record, facts(), CATALOG)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/feature",
        "needs-human",
    }
    assert "bootc status" not in result["comment"]


def test_missing_image_details_requests_actionable_command():
    body = "### What happened?\nAn update fails\n### What did you expect?\nSuccessful update\n### Steps to reproduce\nRun update\n### Image details\n_No response_\n"
    result = policy.plan(issue(body=body), facts(), CATALOG)
    assert result["stage"] == "triage/needs-information"
    assert "Run `bootc status` and paste the complete output" in result["comment"]


def test_standing_tracker_is_not_dispatched_or_forced_into_bug_form():
    record = issue(("3-clanker-queue",), number=245)
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert final_labels(record, result) == {
        "needs-triage",
        "kind/task",
        "tracking",
        "needs-human",
    }


def test_pr_cleanup_preserves_review_and_merge_labels_without_issue_stage():
    record = issue(("3-human-queue", "3-clanker-queue", "hold", "lgtm", "kind/feature"))
    record["pull_request"] = {
        "url": "https://api.github.com/repos/projectbluefin/common/pulls/10"
    }
    result = policy.plan(record, facts(), CATALOG)
    assert final_labels(record, result) == {"hold", "lgtm", "kind/feature"}
    assert result["stage"] is None
    assert not result["close"]


def test_closed_issue_is_not_reopened_or_posted_to():
    record = issue(("1-triage",))
    record["state"] = "closed"
    result = policy.plan(record, facts(), CATALOG)
    assert result["comment"] is None
    assert not result["close"]
    assert record["state"] == "closed"


def test_merged_fix_does_not_claim_image_delivery_or_close_report():
    record, data = accepted()
    record["body"] = "### Image details\nghcr.io/projectbluefin/utah:testing\n"
    data["linked_prs"] = [
        {
            "number": 20,
            "merged_at": T2,
            "body": "Refs #10",
            "html_url": "https://github.com/projectbluefin/common/pull/20",
        }
    ]
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "awaiting-release"
    assert not result["close"]
    assert "needs-human" in final_labels(record, result)


def test_cross_repo_same_number_is_not_local_implementation_link():
    assert policy.referenced_issues(
        "Closes projectbluefin/dakota#10\nRefs https://github.com/projectbluefin/utah/issues/10\nRefs #12"
    ) == {12}


def test_missing_delivery_receipt_does_not_request_verification():
    record = issue(("needs-verification", "kind/bug"))
    data = facts((event("needs-verification"),))
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "awaiting-release"
    assert not result["close"]


def test_bot_cannot_forge_published_delivery_state():
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts((event("needs-verification", "agent[bot]", "Bot"),))
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


def test_published_receipt_requests_specific_reporter_verification():
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts((event("needs-verification"),))
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "needs-verification"
    assert "repeat the original reproduction steps" in result["comment"]
    assert "sha256:" + "a" * 64 in result["comment"]
    assert not result["close"]


@pytest.mark.parametrize("actor,kind", [("outsider", "User"), ("agent[bot]", "Bot")])
def test_other_actor_cannot_confirm_on_reporters_behalf(actor, kind):
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts(
        (event("needs-verification"),), (reply("Confirmed fixed", actor, kind),)
    )
    assert not policy.plan(record, data, CATALOG)["close"]


def test_negative_confirmation_reopens_triage_without_restarting_work():
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts(
        (event("needs-verification"),), (reply("Still broken on the published image"),)
    )
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "needs-triage"
    assert not result["close"]


def test_explicit_reporter_confirmation_closes_verified_report():
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts(
        (event("needs-verification"),),
        (reply("Confirmed fixed in the release linked above"),),
    )
    assert policy.plan(record, data, CATALOG)["close"]


def test_earlier_confirmation_cannot_close_a_new_verification_request():
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    data = facts(
        (event("needs-verification", time=T2),), (reply("Confirmed fixed", time=T0),)
    )
    assert not policy.plan(record, data, CATALOG)["close"]


def test_write_client_rejects_every_other_repository():
    with pytest.raises(ValueError, match="only writes projectbluefin/common"):
        policy.GitHub("projectbluefin/dakota")


@pytest.mark.parametrize("pull_request", [False, True])
def test_collected_issue_and_pr_drive_the_public_policy(monkeypatch, pull_request):
    record = issue(("kind/bug",), "<!-- report-type: bug -->")
    record["html_url"] = "https://github.com/projectbluefin/common/" + (
        "pull/10" if pull_request else "issues/10"
    )
    if pull_request:
        record["pull_request"] = {
            "url": "https://api.github.com/repos/projectbluefin/common/pulls/10"
        }
    responses = {
        "repos/projectbluefin/common/issues/10": record,
        "repos/projectbluefin/common/issues/10/comments?per_page=100": [],
        "repos/projectbluefin/common/issues/10/timeline?per_page=100": [],
        "repos/projectbluefin/common/pulls/10": {"draft": True},
        "graphql": {
            "data": {
                "repository": {
                    "issue": {"lastEditedAt": None},
                    "pullRequest": {
                        "reviewDecision": "REVIEW_REQUIRED",
                        "mergeable": "MERGEABLE",
                    },
                }
            }
        },
    }
    client = policy.GitHub(policy.REPOSITORY)
    monkeypatch.setattr(
        client, "request", lambda method, path, body=None, **kwargs: responses[path]
    )
    collected, data = client.collect(10)
    result = policy.plan(collected, data, CATALOG)
    if pull_request:
        assert result["stage"] is None
        assert final_labels(collected, result) == {"kind/bug"}
        assert "finish the agreed changes" in result["comment"]
    else:
        assert result["stage"] == "needs-triage"
        assert final_labels(collected, result) == {
            "needs-triage",
            "kind/bug",
            "needs-human",
        }


def test_information_reply_is_not_lost_during_periodic_reconciliation():
    body = "### What happened?\nBroken\n### What did you expect?\nWorking\n### Steps to reproduce\nRun it\n### Image details\n_No response_\n"
    record = issue(("needs-triage", "kind/bug"), body)
    data = facts(
        (event("triage/needs-information"),), (reply("I cannot boot the machine"),)
    )
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


def test_unclassified_acceptance_stays_out_of_agent_dispatch():
    record = issue(("triage/accepted",))
    result = policy.plan(record, facts((event("triage/accepted"),)), CATALOG)
    assert {"needs-kind", "needs-human"} <= final_labels(record, result)


def test_client_cannot_write_other_repo_even_with_a_forged_api_path():
    client = policy.GitHub(policy.REPOSITORY)
    with pytest.raises(ValueError, match="Write outside common refused"):
        client.request(
            "POST",
            "repos/projectbluefin/dakota/issues/10/labels",
            {"labels": ["needs-triage"]},
        )


def test_repeated_migration_does_not_turn_managed_gate_into_human_only():
    record = issue(("needs-triage", "kind/feature", "needs-human"))
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert "human-only" not in final_labels(record, result)


@pytest.mark.parametrize(
    "native,actor",
    [
        ({"review_decision": "CHANGES_REQUESTED"}, "Contributor:"),
        ({"native_mergeable": "CONFLICTING"}, "Contributor:"),
        ({"review_decision": "APPROVED"}, "Contributor:"),
    ],
)
def test_pr_next_actor_follows_native_state(native, actor):
    record = issue()
    record["pull_request"] = {
        "url": "https://api.github.com/repos/projectbluefin/common/pulls/10"
    }
    data = facts()
    data["pull_request"] = native
    result = policy.plan(record, data, CATALOG)
    assert result["comment"].split("**Next actor and steps:** ")[1].startswith(actor)
    assert result["add"] == []


def test_code_only_fix_does_not_wait_for_an_image_release():
    record, data = accepted()
    record["body"] = "### Image details\nNot applicable: this is a repository script\n"
    data["linked_prs"] = [
        {
            "number": 20,
            "merged_at": T2,
            "body": "Refs #10",
            "html_url": "https://github.com/projectbluefin/common/pull/20",
        }
    ]
    assert policy.plan(record, data, CATALOG)["stage"] == "triage/accepted"


def test_stale_body_is_rejected_even_when_timestamp_has_not_advanced(monkeypatch):
    record = issue(("needs-triage",), "Original scope")
    record["html_url"] = "https://github.com/projectbluefin/common/issues/10"
    fresh = {**record, "body": "Changed scope"}
    client = policy.GitHub(policy.REPOSITORY)
    writes = []

    def request(method, path, body=None, **kwargs):
        if method == "GET":
            return fresh
        writes.append((method, path, body))

    monkeypatch.setattr(client, "request", request)
    with pytest.raises(RuntimeError, match="changed during reconciliation"):
        client.apply(record, facts(), policy.plan(record, facts(), CATALOG))
    assert writes == []


def test_snapshot_cannot_be_used_to_mint_live_acceptance(tmp_path):
    snapshot = tmp_path / "forged.json"
    snapshot.write_text("[]")
    with pytest.raises(SystemExit) as error:
        policy.main(["--snapshot", str(snapshot), "--apply"])
    assert error.value.code == 2


def test_editing_requested_information_returns_to_assessment():
    record = issue(("triage/needs-information", "kind/bug"), "Updated report details")
    data = facts((event("triage/needs-information"),), edited=T2)
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


@pytest.mark.parametrize(
    "author,actor_type", [("maintainer", "User"), ("github-actions[bot]", "Bot")]
)
def test_only_bot_history_is_upgraded_and_reporter_forgery_is_untouched(
    monkeypatch, author, actor_type
):
    record = issue(("1-triage", "kind/feature"))
    record["html_url"] = "https://github.com/projectbluefin/common/issues/10"
    old = reply(
        "This issue has been marked `status/discussing` as part of the factory issue pipeline.\nUse old approval commands.",
        actor=author,
        kind=actor_type,
    )
    old["id"] = 7
    original = old["body"]
    forged = reply(policy.COMMENT_MARKER + "Fake accepted state", actor="reporter")
    forged["id"] = 8
    data = facts(comments=(old, forged))
    client = policy.GitHub(policy.REPOSITORY)
    posted = []

    def request(method, path, body=None, **kwargs):
        if method == "GET":
            return record
        if method == "PATCH" and path.endswith("/comments/7"):
            old["body"] = body["body"]
        if method == "POST" and path.endswith("/comments"):
            posted.append(body["body"])

    monkeypatch.setattr(client, "request", request)
    client.apply(record, data, policy.plan(record, data, CATALOG, migrate=True))
    if actor_type == "User":
        assert old["body"] == original
        assert posted[0].startswith(policy.COMMENT_MARKER)
    else:
        assert old["body"].startswith(policy.COMMENT_MARKER)
        assert posted == []
    assert forged["body"] == policy.COMMENT_MARKER + "Fake accepted state"


def test_native_gate_is_installed_before_retiring_old_queue(monkeypatch):
    record = issue(("3-clanker-queue", "kind/feature"))
    record["html_url"] = "https://github.com/projectbluefin/common/issues/10"
    client = policy.GitHub(policy.REPOSITORY)
    writes = []

    def request(method, path, body=None, **kwargs):
        if method == "GET":
            return record
        writes.append((method, path, body))

    monkeypatch.setattr(client, "request", request)
    client.apply(record, facts(), policy.plan(record, facts(), CATALOG))
    assert writes[0][0] == "POST"
    assert "needs-human" in writes[0][2]["labels"]
    assert any(item[0] == "DELETE" for item in writes[1:])


def test_picker_information_request_supersedes_existing_stage():
    record = issue(("needs-triage", "triage/needs-information", "kind/bug"))
    data = facts((event("needs-triage", time=T0), event("triage/needs-information")))
    assert policy.plan(record, data, CATALOG)["stage"] == "triage/needs-information"


def test_picker_verification_supersedes_waiting_release_stage():
    record = issue(
        ("awaiting-release", "needs-verification", "kind/bug"), delivery_body()
    )
    data = facts((event("awaiting-release", time=T0), event("needs-verification")))
    result = policy.plan(record, data, CATALOG)
    assert final_labels(record, result) & set(CATALOG["stages"]) == {
        "needs-verification"
    }


def test_information_request_invalidates_old_acceptance_after_reporter_reply():
    record = issue(("triage/needs-information", "kind/feature", "needs-human"))
    data = facts(
        (event("triage/accepted", time=T0), event("triage/needs-information")),
        (reply("Here is the information"),),
    )
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "needs-triage"
    assert "needs-human" in final_labels(record, result)


def test_earlier_independent_human_gate_is_not_cleared_by_acceptance():
    record, data = accepted(("needs-human",))
    data["timeline"].insert(0, event("needs-human", time=T0))
    assert "needs-human" in final_labels(record, policy.plan(record, data, CATALOG))


def test_legacy_cli_image_report_enters_delivery_wait_not_dispatch():
    record = issue(
        ("triage/accepted",),
        "## Bluefin Bug Report\n### System\nImage: ghcr.io/projectbluefin/utah:testing\n",
    )
    data = facts(
        (event("triage/accepted"),),
        prs=(
            {
                "number": 20,
                "merged_at": T2,
                "body": "Refs #10",
                "html_url": "https://github.com/projectbluefin/common/pull/20",
            },
        ),
    )
    result = policy.plan(record, data, CATALOG)
    assert result["stage"] == "awaiting-release"
    assert "kind/bug" in final_labels(record, result)
    assert "needs-human" in final_labels(record, result)


def test_failed_verification_stays_in_assessment_on_next_sweep():
    record = issue(("needs-triage", "kind/bug", "needs-human"), delivery_body())
    data = facts(
        (
            event("triage/accepted", time=T0),
            event("needs-verification"),
            event("needs-triage", "github-actions[bot]", "Bot", time=T2),
        ),
        (reply("Still broken"),),
    )
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


def test_same_second_spec_edit_is_not_assumed_approved():
    record, data = accepted()
    data["last_edited_at"] = T1
    assert policy.plan(record, data, CATALOG)["stage"] == "needs-triage"


def test_local_user_token_cannot_apply_migration(monkeypatch):
    monkeypatch.delenv("GITHUB_ACTIONS", raising=False)
    with pytest.raises(SystemExit) as error:
        policy.main(["--migrate", "--apply"])
    assert error.value.code == 2


def test_old_discussing_label_does_not_invent_a_reporter_information_request():
    record = issue(("2-discussing", "kind/feature"))
    result = policy.plan(record, facts(), CATALOG, migrate=True)
    assert result["stage"] == "needs-triage"
    assert "Reporter: answer" not in result["comment"]


def test_action_request_notifies_reporter_once_and_keeps_one_status(monkeypatch):
    record = issue(("needs-verification", "kind/bug"), delivery_body())
    record["html_url"] = "https://github.com/projectbluefin/common/issues/10"
    data = facts((event("needs-verification"),))
    previous = reply(
        policy.COMMENT_MARKER + "\nOld passive status",
        actor="github-actions[bot]",
        kind="Bot",
    )
    previous["id"] = 7
    data["comments"].append(previous)
    client = policy.GitHub(policy.REPOSITORY)
    notifications = []

    def request(method, path, body=None, **kwargs):
        if method == "GET" and "/timeline" in path:
            return data["timeline"]
        if method == "GET":
            return record
        if method == "PATCH" and "/comments/7" in path:
            previous["body"] = body["body"]
        if method == "POST" and path.endswith("/comments"):
            notification = reply(body["body"], actor="github-actions[bot]", kind="Bot")
            notifications.append(notification)
            data["comments"].append(notification)

    monkeypatch.setattr(client, "request", request)
    result = policy.plan(record, data, CATALOG)
    client.apply(record, data, result)
    client.apply(record, data, result)
    assert len(notifications) == 1
    assert "@reporter" in notifications[0]["body"]
    assert "sha256:" + "a" * 64 in notifications[0]["body"]
    assert previous["body"].startswith(policy.COMMENT_MARKER)


def test_first_information_request_is_itself_the_notification(monkeypatch):
    body = "### What happened?\nBroken\n### What did you expect?\nWorking\n### Steps to reproduce\nRun it\n### Image details\n_No response_\n"
    record = issue(("triage/needs-information", "kind/bug"), body)
    record["html_url"] = "https://github.com/projectbluefin/common/issues/10"
    data = facts((event("triage/needs-information"),))
    client = policy.GitHub(policy.REPOSITORY)
    posted = []

    def request(method, path, body=None, **kwargs):
        if method == "GET" and "/timeline" in path:
            return data["timeline"]
        if method == "GET":
            return record
        if method == "POST" and path.endswith("/comments"):
            comment = reply(body["body"], actor="github-actions[bot]", kind="Bot")
            comment["id"] = 7
            data["comments"].append(comment)
            posted.append(comment)

    monkeypatch.setattr(client, "request", request)
    result = policy.plan(record, data, CATALOG)
    client.apply(record, data, result)
    client.apply(record, data, result)
    assert len(posted) == 1
    assert "@reporter" in posted[0]["body"]
    assert "bootc status" in posted[0]["body"]
