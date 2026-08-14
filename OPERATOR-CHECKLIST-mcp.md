# OPERATOR-CHECKLIST-mcp.md

Verification items for `instruqt-agentcontrol-mcp/` that only an operator can complete — anything needing browser access to a live LaunchDarkly project, a real Instruqt sandbox, or a baked VM image. Claude Code can draft from docs but cannot drive a UI or watch an agent work (see "UI instructions in assignment.md are drafts pending operator verification" in `CLAUDE.md`).

This track shifts most of the verification burden from *UI drift* to *agent behavior*. The prompt blocks are drafts until someone has watched an agent execute them, in the same way the old track's click-by-click steps were.

---

## Blocking items — do these before anything else

- [ ] **Confirm the project-scoped LD token is sufficient for the hosted MCP server.** The lab token grants `actions: ["*"]` on `proj/<key>` only. If the MCP handshake or the smoke-test prompt needs an account-level read, widen the inline role in `track_scripts/setup-workstation` and note it in `DECISIONS.md`. This gates the entire design — see `PHASES.md` Phase 0a for the exact list of calls to try.
- [ ] **Confirm bearer-header auth against `https://mcp.launchdarkly.com/mcp/launchdarkly` is supported and won't be removed.** LaunchDarkly's own hosted-MCP docs describe OAuth only and tell you to remove token env vars; our evidence that headers work is one sibling workshop. This is a one-message question to the MCP team and it retires a real risk. The fallback is the local `npx @launchdarkly/mcp-server` stdio server with `--api-key`.
- [ ] **Resolve the `BedrockProfile` credential question.** Nothing in this repo writes `~/.aws/config` or `~/.aws/credentials`, and the federated session `gcp-federation/` describes has a 1-hour lifetime. Find out whether long-lived IAM keys are being hand-written at bake, or whether Bedrock calls have been failing. Claude Code makes this load-bearing twice over. See `PHASES.md` Phase 0b and the credentials section of `vm-image/README.md`.
- [ ] **Add `bedrock:ListInferenceProfiles` and `bedrock:GetInferenceProfile`** to the policy in `gcp-federation/aws-instruqt-role.tf`. Without them Claude Code can't resolve inference profiles and applies the `us.` prefix blind.
- [ ] **Fill in `/etc/bedrock-federation.env`** with `BEDROCK_ROLE_ARN` and `BEDROCK_JWT_AUDIENCE` from `gcp-federation/` outputs before baking. The `credential_process` fails closed without them.
- [ ] **Confirm Sonnet 4.6 is enabled in the account and allowed by the IAM policy.** Claude Code is pinned to it; the policy hardcodes inference-profile ARNs.
- [ ] **Set an AWS Budgets alarm with an action on the workshop account.** `LD_CHAT_TURN_LIMIT` caps Otto's spend and does nothing about Claude Code, which is the larger consumer by a wide margin.

---

## VM image

- [ ] **Point `REPO_URL` in `vm-image/build-image.sh` at this repo.** It still points at `launchdarkly-labs/ld-instruqt-ai-configs-intro`, where this track's content does not exist.
- [ ] Bake the image and run the scripted verification block the script prints.
- [ ] **Launch `claude` interactively once and confirm ZERO prompts** — no theme picker, no folder-trust dialog, no MCP approval. If any appears, diff `/root/.claude.json` afterwards and add the missing key to the heredoc. This is the single most likely silent failure in the whole track, and it strands the learner in challenge 00.
- [ ] Confirm `/mcp` inside `claude` lists **LaunchDarkly** as connected, not pending approval.
- [ ] **Test the Claude Code TUI in code-server, in a browser.** Confirm Escape cancels and Shift+Enter inserts a newline. `terminal.integrated.sendKeybindingsToShell` is set for this, but it needs seeing.
- [ ] `rm -rf /root/.claude/projects` before saving, so learners don't inherit operator session transcripts.
- [ ] Bump the image's name suffix in `instruqt-agentcontrol-mcp/config.yml` so in-flight labs don't pick up a new image mid-session.
- [ ] Confirm the machine-type bump to `n1-standard-4` is adequate with code-server, uvicorn, the traffic generator, and Claude Code all running.

---

## Cross-cutting

- [ ] **Live-fire end to end** against a fresh sandbox: bootstrap → all five chapters by hand → all five solves from fresh state → every check passes both ways.
- [ ] **Time the track-level `setup-workstation`.** It now also renders `.mcp.json` and patches `/root/.claude.json`; should still be well under 60s.
- [ ] **Confirm `cleanup-workstation` revokes the lab token.** `GET /api/v2/tokens` on the account afterwards should not list a `Lab token: <project>` entry for the destroyed sandbox. This is new — the old script leaked a live token on every run.
- [ ] Time a full self-paced run. Target ~1 hour.

---

## Per-chapter

For each: paste the assignment's prompt into Claude Code **verbatim** and see what the agent actually does; complete the lab as a learner and click Check (expect pass); run solve from a fresh state and Check again (expect pass); run Check *before* doing the chapter and confirm the `fail-message` tells the learner what to ask for; resolve any `<!-- VERIFY -->` markers; capture screenshots into `instruqt-agentcontrol-mcp/assets/`.

### 00 Welcome

- [ ] Verify the code-server terminal path in the assignment (**Terminal → New Terminal**) matches what the learner sees.
- [ ] Confirm `/mcp` output reads clearly enough that "connected" is unambiguous.
- [ ] Confirm `List my LaunchDarkly projects.` returns exactly one project and that the agent doesn't need the key spelled out.
- [ ] Confirm the check's failure messages point at the instructor rather than blaming the learner — every failure in this chapter is a setup problem.

### 01 Otto is born

- [ ] Confirm Otto can actually answer catalog questions ("what material is the Rollout Tote?", "what sizes do the socks come in?") from his challenge-01 prompt, flatly but correctly.
- [ ] **Run the config-creation prompt three or four times on fresh projects.** Note every place the agent diverges: variation display name, model-config key spelling, whether it sets the Test fallthrough unprompted, whether it creates the variation in the same call. Loosen the check or sharpen the prompt for each divergence.
- [ ] Confirm the agent reliably picks a Haiku 4.5 model config from `anthropic.claude-haiku-4-5-20251001-v1:0`, and that the resulting `modelConfigKey` matches the check's `haiku-4-5` substring test.
- [ ] Verify UI labels for the **Agents → Configs** navigation the assignment sends the learner to for inspection.
- [ ] Confirm the existing `assets/ch01-create-config.png` is still accurate or replace it — the assignment no longer walks the create-config dialog, so it may want a different shot (the created Config as the agent left it).
- [ ] Confirm pasting the Challenge 01 block and saving triggers a reload that wires Otto correctly, and that the marker line survives verbatim for challenge 02's patch.

### 02 Otto sounds like Otto

- [ ] **Confirm the agent creates the judge in judge mode.** Mode is fixed at creation, so an agent that defaults to completion mode leaves the learner needing to delete and recreate. If it gets this wrong often, the prompt needs to be blunter.
- [ ] **Confirm `{{response}}` survives into the saved prompt.** This is the silent-failure case: a judge without it grades an empty string and still returns plausible numbers.
- [ ] Confirm the agent attaches the judge to `otto-born` at 100% sampling, and that the attachment is visible in the variation's Judges panel.
- [ ] Confirm the agent creates the `otto-brand-voice-score` metric with the right kind and aggregation.
- [ ] **Resolve the VERIFY marker on the Monitoring tab:** confirm a custom numeric metric appears in the metric dropdown, and whether it sits alongside or separately from evaluator metrics. The assignment currently sends the learner to a dropdown that may only list evaluator metrics.
- [ ] Confirm scores actually land within a minute or two of the paste, with the traffic generator running.
- [ ] **Measure Otto's actual score distribution and set the bands to match.** `{auto: 0.8, review: 0.5}` are reasoned guesses, not measurements. Run traffic for a few minutes, look at the spread, and confirm a meaningful share lands between the two numbers. If it doesn't, move them — in `terraform/challenge-03/main.tf`, the ch03 assignment, and `DECISIONS.md`, together. This is the single most likely reason challenge 03 falls flat.
- [ ] Confirm the read-back prompt's output is accurate and readable. It's learner-facing now, so a confusing summary of a Config is a content bug.

### 03 Otto asks for help

- [ ] Confirm the agent creates a genuine **JSON** flag with both variations parsing as objects containing `auto` and `review`.
- [ ] Confirm it turns the flag on in Test and serves Balanced — a flag left off still serves `off_variation`, so the gate appears to work either way and the check has to catch it.
- [ ] Complete the full review loop as a learner: land a hold, see the placeholder in chat, find the item in the staff panel, approve unedited, approve edited, reject. Each must reach the customer's transcript within a poll cycle.
- [ ] Confirm `otto-review-outcome` records all three bands and `otto-review-decision` records all three human outcomes.
- [ ] **Break the judge deliberately** (point its targeting at the disabled variation) and confirm the gate fails open and ships, rather than holding everything.
- [ ] Switch to **Cautious** mid-session and confirm routing changes with no restart. This is the chapter's payoff; it has to be visible.
- [ ] **Confirm the Staff Review tab opens `/review` directly.** There's a `VERIFY` marker on the tab's `path:` key — if Instruqt service tabs don't honour it, the learner has to reach the page via the storefront's "Staff review" nav link, and the tab plus every `#tab-3` reference needs rewording.
- [ ] Check the Staff Review page's appearance in a browser — it's new UI and hasn't been seen rendered.
- [ ] Confirm the queue shows only the learner's own held responses, and that the "N more from other sessions" line reflects background traffic.
- [ ] Confirm a learner can reliably reach the middle band with a few messages. If not, adjust the suggested question in the assignment rather than the thresholds.

### 04 Wrap-up

- [ ] Confirm the quiz's correct answer (index 1, the attachment-plus-invocation one) is right, and that the three distractors are plausible but clearly wrong to someone who did chapter 02.
- [ ] Confirm no leftover references to Evaluate, Coordinate, or the deleted chapters.
