# CLAUDE.md

This file is the operational spec for Claude Code working on this project. Read it before doing anything else. When in doubt about *why* a decision was made, see `DECISIONS.md`. For the story and voice used in learner-facing prose, see `NARRATIVE.md`. For the build sequence, see `PHASES.md`.

> **Note:** this is authoring documentation, not learner material — it describes how the labs are built and is effectively the answer key. `vm-image/build-image.sh` therefore *deletes* this file, `DECISIONS.md`, `PHASES.md`, `NARRATIVE.md`, and the operator checklist from the VM clone after cloning. A permissions denylist was the first attempt and was wrong: it only blocks the `Read` tool and fails open if a key name changes. `terraform/` and the track directory stay on disk because setup and solve scripts need them, and those keep deny entries.

## What we're building

A single **Instruqt track** teaching LaunchDarkly's **AgentControl** product through hands-on labs, aimed at developers evaluating LaunchDarkly and at existing customers expanding into AI use cases. Learners are assumed to already understand LaunchDarkly fundamentals (flags, contexts, environments); this workshop does **not** re-teach those.

The distinguishing premise: **the learner drives LaunchDarkly through the hosted MCP server, not the UI.** Claude Code runs on the workstation, already connected, and the learner creates Configs, judges, and flags by describing what they want in plain language. The LaunchDarkly UI is used for *looking at* what was built and for reading scores, not for building.

**Two chapters no longer hold to that, both because AI Config targeting cannot be written from an agent.**

- **`03-otto-knows-his-audience`** creates the variation through MCP and the targeting rule through a REST paste. The hosted MCP server has no write tool for a custom AI Config rule (flag `update-targeting-rules` returns `401: AI flags may not be modified directly`; `update-agentcontrol-config-targeting` is named in the getter and not registered). The LaunchDarkly tab is not reliable enough to gate the chapter. The paste is the same `addRule` semantic patch `terraform/challenge-05` uses.
- **`05-trust-but-verify`** creates the variation through MCP and starts the guarded rollout **in the UI**, because a guarded rollout has no endpoint at all. Verified against the spec: AI Config and flag targeting `PATCH` both expose only `rolloutWeights` / `rolloutContextKind` / `rolloutBucketBy`, and `ReleaseGuardianConfiguration` / `GuardedReleaseConfig` are referenced from other schemas but from no path. Unlike `03` there is **no fallback** — if the sandbox sign-in is down the chapter cannot be completed.

See DECISIONS.md for both. The upstream fix is a typed add-rule tool and a guarded-rollout endpoint; until then, don't write prose that promises a learner never touches the UI.

Five challenges, **40 minutes** self-paced. The chapter set is driven by six learning objectives — see DECISIONS.md, "Track rebuilt around six learning objectives".

| Dir | Type | Beat |
|---|---|---|
| `01-meet-togglewear` | challenge | Orientation, then connect to the MCP server and prove it with a real call. |
| `02-otto-is-born` | challenge | One prompt creates the `otto-assistant` Config, its `otto-born` variation, and the Test targeting rule. A read-only walkthrough of the six SDK lines, then a live prompt edit changes a shipping policy mid-session with no deploy. |
| `03-otto-knows-his-audience` | challenge | One prompt adds `otto-premium` on Sonnet; a terminal paste adds the `tier is premium` targeting rule via REST. No app change at all — the chapter's point. |
| `04-otto-gets-graded` | challenge | One prompt creates `otto-brand-voice-judge` in judge mode, attaches it at 100% sampling, and creates the metric. The app already invokes it. |
| `05-trust-but-verify` | challenge | Setup pre-builds the `otto-stiff` Nova Pro variation and the judge attachment. The learner tours them and starts the guarded rollout **in the UI** — it has no API. No agent prompt in the chapter at all. |
| `06-wrap-up` | quiz | Recap and one question. |

**The budget is 40 minutes and it is fully spent** — 240 + 480 + 360 + 300 + 900 + 120 = 2400, exactly `track.yml`'s `timelimit`. It was 35 minutes / 2100s until 2026-08-31, when `05-trust-but-verify` went from 600s to 900s: it became a UI chapter with a tour and a rollout dialog, and the rollback needs clock to fire. The operator chose to extend the track rather than take the time from another chapter — the alternatives, and why each was worse, are in DECISIONS.md. Adding anything now means taking the time from another chapter or extending again.

**There are no `server.py` pastes any more.** Both were pre-baked into the VM image on 2026-08-27 to buy the time — see DECISIONS.md, "Cut to 35 minutes". The learner touches LaunchDarkly only. Consequences worth knowing before you edit anything:

- `app/server.py` ships with `/chat` wired and `score_response()` implemented. `terraform/challenge-01` and `challenge-02`'s `patch-server.py` are now idempotent no-ops on a correctly baked image, and are kept so solve still works if someone bakes from an older commit.
- `vm-image/check-image.sh` asserts the *implementations* are present. It used to assert the stubs were. Inverting that back would silently ship an unwired app.
- The paste assertions in `02`'s and `04`'s `check-workstation` are retained but their `fail-message` text now blames the image, not the learner — because that's the only thing that can cause them to fire.

**The tightest chapter is still `05-trust-but-verify`**, even at 900s: a UI tour, a rollout dialog, and then waiting for a regression detector we do not control. The comparable chapter in the `ld-agentcontrol-intro` track allows 1200s for the same content. If a live run overshoots, that is the next number to move.

### Two numbering schemes, deliberately

**Directory index** is presentation order only: `01`..`06`.

**Terraform modules and code markers** are numbered by *substantive* chapter, and do not shift — including when a chapter is cut or a new one lands in the middle. The mapping is therefore no longer sorted, and that is the intended behaviour, not drift:

| Module | Chapter | Directory |
|---|---|---|
| `challenge-01` | Otto's Config | `02-otto-is-born` |
| `challenge-02` | brand-voice judge | `04-otto-gets-graded` |
| `challenge-03` | review gate | **none — chapter cut, module retained** |
| `challenge-04` | guarded rollout | `05-trust-but-verify` |
| `challenge-05` | tier-based routing | `03-otto-knows-his-audience` |

The `server.py` markers (`Challenge 01 paste block`, `Challenge 02 judge: replace this body`, `Challenge 03 review gate: replace this body`) match that scheme, because patch scripts and checks match on those exact strings. The third marker is now unreachable from any chapter but stays in `server.py` — it's the stub a learner falls back to, and removing it would break `terraform/challenge-03/patch-server.py`. The routing and guarded-rollout chapters add no markers: neither touches the app.

Learner-facing prose names chapters rather than numbering them, so a reorder can't make it wrong.

**Lecture content lives in slides, not in the tracks.** Don't embed conceptual exposition in `assignment.md` beyond what a self-paced learner needs to make sense of each step.

## The reference track

This track mirrors the structure and conventions of an existing LaunchDarkly Instruqt track: the "01-release" basics track at `launchdarkly-labs/launchdarkly-workshops/launchdarkly-basics/instruqt/01-release`. If you can read it, do so before scaffolding. Otherwise follow the conventions documented here — they were extracted directly from it.

## Repository layout

```
<repo-root>/
├── CLAUDE.md                       # this file
├── DECISIONS.md                    # why decisions were made
├── PHASES.md                       # build sequence
├── NARRATIVE.md                    # Otto's story + voice guide
├── OPERATOR-CHECKLIST-mcp.md       # pre-delivery checklist
├── instruqt-agentcontrol-mcp/      # the track
│   ├── track.yml                   # slug ld-agentcontrol-mcp
│   ├── config.yml
│   ├── track_scripts/{setup,cleanup}-workstation
│   ├── 01-meet-togglewear/ … 06-wrap-up/
│   └── assets/                     # images referenced from assignment.md
├── app/                            # ToggleWear app, baked into the VM image
│   ├── server.py                   # FastAPI server + review queue + static
│   ├── static/{index.html,app.js,style.css,images/}
│   ├── requirements.txt
│   ├── .env.example
│   └── .mcp.json.example           # rendered to .mcp.json at lab start
├── terraform/
│   ├── student-bootstrap/          # LD project + test env (track setup)
│   ├── challenge-01/               # Otto's Config + SDK paste
│   ├── challenge-02/               # brand-voice judge + metric + attachment
│   ├── challenge-03/               # thresholds flag + review-gate paste
│   ├── challenge-04/               # Nova Pro + otto-stiff + rollout fallback
│   └── challenge-05/               # Sonnet + otto-premium + tier targeting rule
├── gcp-federation/                 # AWS IAM role + GCP OIDC trust for Bedrock
├── traffic-generator/              # background traffic so scores populate
└── vm-image/                       # inputs for baking the VM image
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

**Exception:** `03-otto-asks-for-help` adds a fourth tab, "Staff Review" (`#tab-3`), pointing at the app's `/review` page. Indices 0-2 are unchanged, so no existing reference moves. See the reviewer-surface entry in `DECISIONS.md` for why the review queue is its own page rather than a panel on the storefront.

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
3. **Challenge 03** replaces the body of `gate_response(req, assistant_text, score, model_id) -> tuple[str, str]`.

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
- **Human-in-the-loop review.** Was `04-otto-asks-for-help`; cut 2026-08-27 because it maps to none of the six objectives. The chapter is gone but `terraform/challenge-03`, `gate_response()`, the review queue, `/review`, and the Staff Review page all remain in the repo unreferenced, so restoring it is a chapter rewrite rather than a rebuild. Do not delete them without checking DECISIONS.md first.
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
