# PHASES.md

Build sequence for `instruqt-agentcontrol-mcp`. Work one phase at a time, stop for operator review at each gate.

The repo is not starting from zero — it was narrowed from a three-track workshop, so `app/`, `terraform/student-bootstrap/`, `terraform/challenge-01/`, `traffic-generator/`, `gcp-federation/`, and `vm-image/` are inherited and working (with the caveat in Phase 0). What's new is the MCP path, the review gate, and the track itself.

---

## Phase 0: De-risk the two things that gate everything

Do this before authoring anything. Both are yes/no questions with the power to change the design.

**0a. Is a project-scoped LD token enough for the hosted MCP server?**

The lab token's inline role grants `actions: ["*"]` on `proj/<key>` and `proj/<key>:*` and nothing account-level. Point Claude Code at `https://mcp.launchdarkly.com/mcp/launchdarkly` with such a token and confirm it can:

- list/resolve the project (this is the `00-welcome` smoke test, and it may need an account-level read)
- create a completion-mode Config with a variation and set a fallthrough
- create a judge-mode Config and attach it to a variation with a sampling rate
- create a JSON flag with two variations and turn it on
- create a custom numeric metric

If the handshake itself needs account reads, widen the inline role in `track_scripts/setup-workstation` and record the wider blast radius in `DECISIONS.md`. Never fall back to the operator master token.

Also confirm the raw bearer-header call works, since it's undocumented:

```sh
curl -X POST https://mcp.launchdarkly.com/mcp/launchdarkly \
  -H "Authorization: Bearer $LD_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

**0b. Do the Bedrock credentials actually work?**

`build-image.sh` now installs a `credential_process` that exchanges the GCE instance identity token for an STS session on demand, which is the durable fix. What's unverified is whether the exchange succeeds *in a real sandbox*: the trust policy pins a specific GCP service account, and the bake VM may not be the same one.

Test the exchange on a **real Instruqt sandbox**, not the bake VM — it will pass on the bake VM either way. Have the test print the decoded JWT's `sub` so a service-account mismatch is a one-line diagnosis rather than an afternoon.

Also settle what was happening *before*: `app/server.py` has always asked for `BedrockProfile` and nothing ever created it, so either undocumented long-lived IAM keys were hand-written at bake or Otto's Bedrock calls were failing. If it turns out to be the former, the "short-lived federated credentials" claim in `CLAUDE.md` was wrong and the fallback is a scoped IAM user delivered via the existing Instruqt secrets.

While in that file, add `bedrock:ListInferenceProfiles` and `bedrock:GetInferenceProfile`, and confirm the hardcoded inference-profile ARNs cover Sonnet 4.6 — Claude Code is pinned to it.

Also fill in `/etc/bedrock-federation.env` with the role ARN and JWT audience from `gcp-federation/` outputs. The credential process fails closed without them.

**Gate:** both answered, with any scope or IAM changes committed.

---

## Phase 1: Bake and prove the image

`vm-image/build-image.sh` already installs and pre-seeds Claude Code. Point `REPO_URL` at this repo, bake, and run the verification block in `vm-image/README.md`.

The step that matters most can't be scripted: launch `claude` interactively and confirm **zero** prompts. If one appears, diff `/root/.claude.json` and fold the missing key back into the heredoc. A learner who hits a trust dialog in challenge 00 has no way forward.

**Gate:** `claude` starts clean, `/mcp` lists LaunchDarkly as connected, and a real MCP call returns the project.

---

## Phase 2: Run the track end to end as a learner

Start a lab. Verify `app/.env` and `app/.mcp.json` both carry real values, then do all five chapters by hand, pasting each assignment's prompt verbatim into Claude Code.

Watch for the failure this design invites: the agent producing something reasonable that `check-workstation` rejects. Every mismatch is a check to loosen or a prompt to make more explicit, and this is the phase that finds them.

**Gate:** all five chapters pass their checks, done by hand, with no edits to the assignments mid-run.

---

## Phase 3: Prove the escape hatches

For each chapter, on a fresh lab: click **Skip**, then **Check**. Solve must produce a state the check accepts, without going through MCP.

Then the negative case: on a fresh lab, run each `check-workstation` *before* doing the chapter and confirm it fails with a `fail-message` that tells the learner what to ask for.

Pay attention to the paste structure. Challenge 01 replaces an inline block; 02 and 03 each replace a function body. **Skipping 02 and then doing 03 by hand must still work** — the judge stub returns `None`, so the gate should ship everything rather than raise. Verify that specific path; it's the one the stub defaults exist for.

**Gate:** every solve produces a passing state; every check fails usefully when it should.

---

## Phase 4: Verify the review gate behaves

The only chapter with genuinely new application code.

- **Measure the score distribution first.** `{auto: 0.8, review: 0.5}` are guesses. Run traffic, look at the spread, and move the numbers if a meaningful share doesn't land between them — in the terraform, the assignment, and `DECISIONS.md` together. Everything below depends on this.
- Force a mid-band score and confirm the response is held, the customer sees the placeholder, and the item appears in the Staff Review tab.
- Approve unedited, approve edited, and reject. Each must produce the right customer-visible result within a poll cycle, and emit `otto-review-decision`.
- Confirm `otto-review-outcome` records all three bands.
- Kill the judge (break the judge Config's targeting) and confirm the gate fails open and ships, rather than holding everything.
- Switch the flag to `Cautious` mid-session and confirm routing changes with no restart.

**Gate:** all five behaviors confirmed, plus `cleanup-workstation` destroying the project, revoking the token, and removing `.mcp.json`.

---

## Phase 5: Screenshots, VERIFY markers, and polish

Walk each chapter with the assignment open. Resolve every `<!-- VERIFY: ... -->` comment, correct UI wording, and capture the screenshots the assignments reference into `instruqt-agentcontrol-mcp/assets/`.

Then read all five assignments in one sitting for voice consistency against `NARRATIVE.md`, and time a self-paced run.

**Gate:** no VERIFY markers left, no placeholder image references, and a self-paced run inside the hour.

---

## Phase 6: Publish

Instruqt CLI push by a human. `track.yml` deliberately carries no `checksum` — the CLI generates it. Don't commit the `.remote` files it creates.
