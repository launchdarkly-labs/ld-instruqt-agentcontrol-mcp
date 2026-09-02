# CLAUDE.md

This file is the operational spec for Claude Code working on this project. Read it before doing anything else. When in doubt about *why* a decision was made, see `DECISIONS.md`. For the story and voice used in learner-facing prose, see `NARRATIVE.md`. For the build sequence, see `PHASES.md`.

> **Note:** this is authoring documentation, not learner material — it describes how the labs are built and is effectively the answer key. `vm-image/build-image.sh` therefore *deletes* this file, `DECISIONS.md`, `PHASES.md`, `NARRATIVE.md`, and the operator checklist from the VM clone after cloning. A permissions denylist was the first attempt and was wrong: it only blocks the `Read` tool and fails open if a key name changes. `terraform/` and the track directory stay on disk because setup and solve scripts need them, and those keep deny entries.

## What we're building

A single **Instruqt track** teaching LaunchDarkly's **AgentControl** product through hands-on labs, aimed at developers evaluating LaunchDarkly and at existing customers expanding into AI use cases. Learners are assumed to already understand LaunchDarkly fundamentals (flags, contexts, environments); this workshop does **not** re-teach those.

**The premise, as of 2026-09-02: this is the original UI-driven track, with three creation steps done by a coding agent instead.** The learner works in the LaunchDarkly UI for almost everything — prompt edits, snippets, targeting rules, monitoring, the guarded rollout — exactly as `ld-agentcontrol-build` and `ld-agentcontrol-intro` teach it. Three resources are asked for rather than clicked: the Config, the variations, and the judge.

This reverses the 2026-08-14 "MCP server replaces the LaunchDarkly UI as the build interface" decision and everything built on it. See DECISIONS.md, "Restored to the original UI track". Do not re-derive the MCP-first version from this file's history without reading that entry first.

**Eight challenges plus a quiz, 7200s (2 hours).** The chapter set, timelimits and prose are the original's:

| Dir | Type | Beat | MCP? |
|---|---|---|---|
| `00-welcome` | challenge | Orientation, and connect `claude` to the MCP server. | connect only |
| `01-otto-is-born` | challenge | **Ask for** the `otto-assistant` Config and its `otto-born` variation, turn it on in Test via the UI, paste the SDK block into `server.py`, say hi. | Config + variation |
| `02-give-otto-personality` | challenge | Edit Otto's prompt in the UI, no redeploy. | — |
| `03-otto-on-brand` | challenge | Create the `brand-voice` and `safety-rules` prompt snippets, refactor Otto's prompt around them. | — |
| `04-quiz-configs-and-snippets` | quiz | Consolidation quiz. | — |
| `05-otto-for-everyone` | challenge | **Ask for** the `otto-premium` Sonnet variation, then build the `tier is premium` targeting rule in the UI. | variation |
| `06-how-is-otto-doing` | challenge | Read Otto's production data in the Monitoring view. | — |
| `07-trust-but-verify` | challenge | **Ask for** `otto-brand-voice-judge`, patch the app to call it, then start a guarded rollout on `otto-stiff` in the UI and watch it revert. | judge |
| `08-wrap-up` | quiz | Recap and one question. | — |

**Timelimits sum to exactly `track.yml`'s 7200** — 300 + 1200 + 600 + 900 + 600 + 900 + 900 + 1200 + 600. Adding anything means taking time from another chapter.

**Prompt snippets are back in scope** and are chapter 03's whole subject. `terraform/challenge-03` builds them for the solve path; the learner creates them in the UI.

**The `server.py` pastes are back, and must NOT be pre-baked.** `vm-image/check-image.sh` asserts the *stubs* are intact — inverted back on 2026-09-02 from the 2026-08-27 pre-bake. Two patches compose over the shipped stub, verified: `terraform/challenge-01/patch-server.py` (chapter 01's `/chat` wiring) then `terraform/evaluate-03/patch-server.py` (chapter 07's judge call, which lands on a marker the first paste leaves behind). Both are idempotent.

## What is ours, not the original's

Everything else is restored verbatim from `launchdarkly-labs/ld-instruqt`. These four things are not, and each exists for a reason:

- **`instruqt-agentcontrol-mcp/track_scripts/`** — a superset of the original's. Same project bootstrap and key export, plus minting the scoped `LD_API_TOKEN`, rendering `app/.mcp.json`, patching `/root/.claude.json`, and inviting the lab SSO user as Writer so UI writes work at all (see DECISIONS.md, "Invite the lab SSO user as Writer").
- **`vm-image/build-image.sh` and `check-image.sh`** — also a superset. The original's neither installs Claude Code nor deletes this file from the learner's VM.
- **`app/.mcp.json.example`** — has no counterpart upstream.
- **`terraform/evaluate-03` and `evaluate-07`** — lifted from the Evaluate track, because chapter 07 came from there. The `ld-agentcontrol-intro` platform track's version of that chapter references a `terraform/challenge-07` that exists in **no repository**; it was pushed from an uncommitted working copy and its setup would fail. Do not treat that track as a source of truth.

### Chapter-to-module mapping

The original's mapping is 1:1 and sorted, which is the point of restoring it — the two-scheme divergence documented here until 2026-09-02 is gone:

| Chapter | Terraform module |
|---|---|
| `01-otto-is-born` | `challenge-01` (+ `patch-server.py`, `server-paste.py`) |
| `02-give-otto-personality` | `challenge-02` |
| `03-otto-on-brand` | `challenge-03` (prompt snippets) |
| `04-quiz-configs-and-snippets` | none |
| `05-otto-for-everyone` | `challenge-05` |
| `06-how-is-otto-doing` | `challenge-06` |
| `07-trust-but-verify` | `evaluate-07` (Nova Pro + `otto-stiff`) and `evaluate-03` (judge + metric + `patch-server.py`) |
| `08-wrap-up` | none |

Chapter 07 is the one seam. It came from the Evaluate track, so it keeps that track's module names rather than being renumbered to `challenge-07` — renaming would diverge from the committed upstream for no gain, and `challenge-07` is precisely the name the unrestorable platform track used. Its setup applies `evaluate-07` in full and **only `launchdarkly_metric.brand_voice_score`** out of `evaluate-03`, with `-target`, because the learner asks the agent for the judge; solve applies `evaluate-03` in full instead.

`server.py` markers: `Challenge 01 paste block` and `Challenge 07 judge injects below this marker`. Patch scripts and `check-image.sh` match on those exact strings — changing one means changing `server.py`, the paste file, the patch script and the assignment together.

Learner-facing prose names chapters rather than numbering them, so a reorder can't make it wrong.

**Lecture content lives in slides, not in the tracks.** Don't embed conceptual exposition in `assignment.md` beyond what a self-paced learner needs.

## The reference track

This track mirrors the structure and conventions of an existing LaunchDarkly Instruqt track: the "01-release" basics track at `launchdarkly-labs/launchdarkly-workshops/launchdarkly-basics/instruqt/01-release`. If you can read it, do so before scaffolding. Otherwise follow the conventions documented here — they were extracted directly from it.

## Repository layout

```
<repo-root>/
├── CLAUDE.md / DECISIONS.md / PHASES.md / NARRATIVE.md / OPERATOR-CHECKLIST-mcp.md
├── instruqt-agentcontrol-mcp/      # the track — slug ld-agentcontrol-mcp
│   ├── track.yml (timelimit 7200) / config.yml
│   ├── track_scripts/{setup,cleanup}-workstation   # OURS: token, .mcp.json, SSO invite
│   ├── 00-welcome/ … 08-wrap-up/                   # the original's chapters
│   └── assets/
├── app/                            # ToggleWear — restored from ld-instruqt
│   ├── server.py                   # ships with BOTH paste stubs intact
│   ├── static/ requirements.txt .env.example
│   └── .mcp.json.example           # OURS
├── terraform/
│   ├── student-bootstrap/          # identical to upstream
│   ├── challenge-01/ 02/ 03/ 05/ 06/
│   └── evaluate-03/ evaluate-07/   # chapter 07's modules
├── gcp-federation/
├── traffic-generator/              # background_traffic.py, sabotage.py
└── vm-image/                       # OURS: build-image.sh, check-image.sh, README.md
```

## Instruqt conventions (extracted from the reference track)

Non-negotiable unless explicitly overridden in `DECISIONS.md`.

### File pairs: `.remote` mirrors

Every challenge has `assignment.md`, `setup-workstation`, `check-workstation`, `solve-workstation`, each with a `.remote` sibling. **The `.remote` files are auto-generated by the Instruqt CLI on publish. Author only the non-`.remote` version.** They're gitignored.

### Challenge folder structure

- `assignment.md` — learner-facing instructions, front-matter YAML at top
- `setup-workstation` — runs when the challenge starts
- `check-workstation` — runs on **Check**; exits non-zero with `fail-message` on failure
- `solve-workstation` — runs on **Skip**; must leave the workstation in the state a successful learner would

Quiz challenges have only `assignment.md` plus `exit 0` script stubs.

### `assignment.md` front-matter

Three tabs on every challenge, in this order, so tab indices are stable:

```yaml
tabs:
- id: <12-char random>   # LaunchDarkly, type: browser, hostname: launchdarkly
- id: <12-char random>   # ToggleWear, type: service, hostname: workstation, port: 3000
- id: <12-char random>   # Code Editor, type: service, hostname: workstation, port: 8080
```

Challenge and tab ids are random 12-character alphanumeric strings; generate fresh ones per challenge. Reference tabs by index: `[LaunchDarkly](#tab-0)`, `[ToggleWear](#tab-1)`, `[Code Editor](#tab-2)`.

All nine chapters use exactly those three tabs — there is no fourth-tab exception any more. The "Staff Review" tab belonged to the review-gate chapter, which is gone along with the `/review` page it pointed at.

### `assignment.md` body voice

Short directive prose. Exact text the learner types or pastes goes in fenced code blocks. Reasoning lives in section intros, not mid-step. Sections delimited by `# Heading`. See `NARRATIVE.md` for tone.

### Writing MCP prompts for learners

This is the part with no precedent in the reference track.

- **One copy-paste block per chapter**, preceded by a spec table so the learner can see what they're asking for before they ask.
- **Name every key explicitly** in the prompt. Downstream challenges and `check-workstation` depend on `otto-assistant`, `otto-born`, `otto-brand-voice-judge`, `otto-review-thresholds`. Tell the learner the keys matter and what to do if the agent picks something else.
- **Never name MCP tools.** The learner writes intent; tool selection is the agent's job. Tool names also change between server versions.
- **Say "my project," never a project key.** The lab token is scoped to exactly one project, so the agent resolves it. This is what lets identical prompt text work for every learner.
- **Don't assume the agent gets it right.** Every prompt-driven step needs a `check-workstation` assertion, and the assertion must be loose about what the agent gets to choose freely.
- **Follow every build prompt with a read-back prompt** asking the agent to describe what it created. It teaches the verification habit, gives the learner something to do while the agent works, and is the only place in the track where a resource's structure is described rather than merely asserted by a green check. Recovery guidance lives in `00-welcome`'s "When the agent gets it wrong" section rather than being duplicated per chapter.

### Check scripts

Check scripts hit the LaunchDarkly REST API with `curl` and `jq`, use `fail-message "..."` for specific guidance, then `exit 1`. Exit `0` for success. Two rules specific to this track:

- **Assert on keys, modes, and model families — not on display names or prompt wording.** An agent will reword a rubric and rename a variation. The keys are what the app and the next chapter depend on.
- **Retry briefly.** A learner can click Check while the agent's last write is still settling. The existing checks loop five times with a 2-second sleep.

`fail-message` text should tell the learner what to ask the agent for, not which button to click.

### Solve scripts

Solve applies the per-challenge Terraform module, then any `patch-server.py`, then restarts the service. Solve deliberately does **not** go through MCP — the operator's escape hatch must not depend on an LLM.

### The `server.py` paste blocks

Three pastes, but only the first is an inline block:

1. **Challenge 01** replaces the marked stub inside `/chat`.
2. **Challenge 02** replaces the body of `score_response(req, assistant_text, model_id) -> Optional[float]`.
(There is no third paste. The review gate's `gate_response()` went with the app restore.)

`/chat` calls both functions in order and then `_remember(session_id, user_message, final_text)`, so history always records the text the customer actually received.

Data flows through arguments and returns, deliberately. An earlier version had all three pastes as inline fragments sharing locals, and it shipped two coupling bugs that were invisible from inside the block being edited. If you add a step, give it a signature — do not reach for a shared local.

Each `patch-server.py` is idempotent via a `SIGNATURE` string, and the two function patches verify the expected stub `return` sits directly below the marker before touching the file. **Changing a marker or a stub return means changing it in `server.py`, the paste file, the patch script, and the assignment together.** After any change, compose all three and check the result parses — and check the *un*patched file still runs, since the stubs are what a learner who skips a chapter falls back to.

### `track.yml` and `config.yml`

`config.yml` declares the virtual browser (the LaunchDarkly IdP simulator lambda), the VM, and the required secrets: `LAUNCHDARKLY_ACCESS_TOKEN`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.

`track.yml` uses `default_layout: AssignmentRight` and `default_layout_sidebar_size: 25` to match the reference. Do not carry a `checksum` over from another track; the CLI regenerates it.

**VM size is `cpus: 4` / `memory: 16384`.** This track runs code-server, uvicorn, the evaluator-tracker traffic loop, and Claude Code on one box, and Claude Code alone wants 4 GB.

**Size the VM with `cpus` and `memory`, never `machine_type`.** `config.yml` version 3 does not have a `machine_type` field. `instruqt track validate` and `push` both accept it silently as an unknown key, and then the track fails to provision with nothing more specific than "Unable to start track, please try again." Removing it is what surfaces the real schema error: `virtualmachines: cpus: cannot be blank; memory: cannot be blank`. The upstream reference track carried a `machine_type` line and no size, which is worth knowing if you ever try to start it.

**Don't put comments in `config.yml`.** Instruqt strips them on push, which leaves a permanent local/remote delta and makes every subsequent `instruqt track push` fail the delta check until you pull. It also normalizes `track.yml` — expect it to append team members to `developers:`. Adopt those changes locally (`instruqt track pull`) rather than fighting them.

### Credential pathways

Four, deliberately separated by security boundary. Don't conflate them.

**AWS:**

- **Static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (Instruqt secrets)** — for VM-side infrastructure the participant never reaches. Never written into the participant's shell or `~/.aws/credentials`. Note that nothing currently consumes these; see the warning below.
- **`BedrockProfile`** — the boto3 profile the ToggleWear app and Claude Code both use for Bedrock. **Read the warning in `vm-image/README.md` before trusting this.** Nothing in this repo writes `~/.aws/config` or `~/.aws/credentials`, and the federated STS session it's documented to hold has a 1-hour lifetime, so it cannot survive from bake to lab time. This is unresolved and predates the MCP work.

**LaunchDarkly:**

- **`LAUNCHDARKLY_ACCESS_TOKEN` (Instruqt secret)** — the operator's master token. Available to `setup-workstation` / `check-workstation` / `solve-workstation` and Terraform `local-exec`. **Never** written into `app/.env` or anywhere the participant's app or shell can read it.
- **`LD_API_TOKEN` (minted per lab session)** — a scoped token created at track setup via `POST /api/v2/tokens`, with an inline role restricted to `proj/<key>` and `proj/<key>:*`. It does double duty: `app/.env` for the app's REST calls, and the bearer for the MCP server in `app/.mcp.json` and `/root/.claude.json`. Safe to expose because the blast radius is one sandbox project that's destroyed at cleanup, and the token itself is revoked by `cleanup-workstation`.

### Track-level setup script

`track_scripts/setup-workstation` runs once at lab start as root. It applies `terraform/student-bootstrap/`, pulls the SDK/client/project keys, mints `LD_API_TOKEN`, invites `instruqt+<project-key>@launchdarkly.com` as Writer (so the SAML tab does not JIT-provision a Reader), writes them into `~/.profile`, `~/.bashrc`, and `app/.env`, renders `app/.mcp.json` and patches the token into `/root/.claude.json`, then stop/starts `togglewear` (`restart` only sends SIGHUP, which the app doesn't handle, so env vars wouldn't refresh). `cleanup-workstation` revokes the token and deletes that member.

## Tech stack — pinned versions

When implementing, **verify the latest stable version** before pinning. Don't assume training-data knowledge is current.

- **Python** 3.12 (Ubuntu 24.04 system python)
- **FastAPI** + **uvicorn**, **boto3** for Bedrock
- **launchdarkly-server-sdk**, **launchdarkly-server-sdk-ai** (package `ldai`)
- **Vanilla JavaScript** for the frontend — no framework, no build step
- **Terraform** with `launchdarkly/launchdarkly` — features the provider doesn't cover (Config targeting, judge attachment, prompt snippets) go through `null_resource` + `local-exec curl` with the semantic-patch content type
- **Claude Code**, pinned in `vm-image/build-image.sh`. Treat a version bump as a change requiring a full sandbox test.

## Out of scope

- Re-teaching LaunchDarkly basics. Assume mastery.
- Prompt snippets, experiments, agent-mode Configs, agent graphs, tool management. Each is named in `06-wrap-up` as a next step; none is taught.
- **Human-in-the-loop review.** Cut 2026-08-27, and as of the 2026-09-02 restore its code is gone too: the app came back from upstream without `gate_response()`, the review queue, `/review`, `review.html` or `review.js`, and `terraform/challenge-03` is now the prompt-snippets module. Restoring that chapter is a genuine rebuild, not a rewrite. The last commit that had it is the parent of the restore — see DECISIONS.md, "Restored to the original UI track".
- **Guarded rollouts and targeting by user attribute were out of scope until 2026-08-27 and are now taught**, in `05-trust-but-verify` and `03-otto-knows-his-audience`.
- **Offline evaluations are an objective with no MCP path.** Not built. The public REST API has no dataset or evaluation endpoints at all, and the docs describe offline evals as a UI-only flow under Agents → Configs → Playgrounds. See DECISIONS.md before attempting a chapter.
- Lecture content. Presenters deliver that via slides.
- A cart, checkout, or authentication in ToggleWear.
- Any non-Bedrock LLM provider for the app.

## Things Claude Code does not own

- **The VM image build.** We produce the *inputs* in `vm-image/`. A human bakes the image and registers it with Instruqt.
- **AWS account provisioning and Bedrock model access**, including the IAM changes flagged in `vm-image/README.md`.
- **The LaunchDarkly IdP simulator lambda.** Already exists; URL is in `config.yml`.
- **Publishing to Instruqt.** Done via the Instruqt CLI by a human.

## Working agreement with the human operator

- **Work one phase at a time.** Read `PHASES.md`, complete the current phase, stop for review.
- **When a decision arises that isn't in `DECISIONS.md`, ask.** Don't invent product/UX/architectural decisions silently. Record the answer when you proceed.
- **Verify, don't assume.** Before writing code against a specific API, SDK, or product feature, check current docs. AgentControl and the MCP server both move.
- **Don't ship `.remote` files.**
- **Don't reformat the reference track's conventions for "consistency."**

## UI instructions in assignment.md are drafts pending operator verification

Claude Code cannot drive a browser. UI-specific instructions in `assignment.md` (button labels, menu paths, dialog field names) are **drafts based on reading the public docs**, not verified facts.

- Base them on current docs and mirror the reference track's voice. Be specific — the operator needs concrete drafts to verify, not hedges.
- **Do not invent UI elements.** If the docs don't make a step clear, write your best draft and add a `<!-- VERIFY: ... -->` comment saying what to confirm. The operator resolves and removes these.
- **Do not generate screenshots.** Reference filenames in `instruqt-agentcontrol-mcp/assets/` that the operator will populate.
- **API-driven checks are not UI-driven.** Write `check-workstation` scripts confidently from the API docs.

This track shifts most of the risk from UI drift to agent behavior. The MCP prompt blocks need the same treatment as UI steps: they're drafts until someone has watched an agent execute them.

## Definition of done

1. A presenter can deliver the full version with slide breaks and have every lab complete successfully.
2. A self-paced learner can finish in ~1 hour following only `assignment.md`.
3. Every `solve-workstation` produces the correct end state, without MCP.
4. Every `check-workstation` passes valid completions — including ones where the agent made reasonable different choices — and fails common mistakes with helpful `fail-message` output.
5. `vm-image/` produces a working image, and `claude` starts with zero prompts on it.
6. `DECISIONS.md` records every meaningful decision; `NARRATIVE.md` keeps Otto's voice consistent.
