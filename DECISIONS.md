# DECISIONS.md

This file records every meaningful decision made during planning, with the reasoning behind it. When Claude Code (or any contributor) is tempted to reopen a decision, they should read the rationale here first.

Format: one decision per section, dated, with options considered and reason for the chosen path. Add new decisions to the bottom as they arise.

---

## Track scope and audience

**Decision:** Three substantive hands-on labs (plus welcome and wrap-up = five challenges total) covering Config creation, a custom judge, and a human-in-the-loop review gate — all driven through the LaunchDarkly MCP server.

**Audience:** Developers — both LaunchDarkly evaluators and existing LD customers expanding into AI use cases. Assumes LD fundamentals are known.

**Rationale:** This is a 100-level introduction to AgentControl that answers "what does this look like in my workflow" rather than touring the feature list. Targeting developers rather than mixed audiences lets us assume technical literacy and skip foundational LD content.

**Superseded:** an earlier version of this decision specified six labs across nine challenges, and later three sibling tracks totalling thirty. See "Scope cut to one track" at the bottom of this file for why that was narrowed and what it cost.

---

## Track length and cadence

**Decision:** ~1 hour self-paced; presenter-led delivery interleaves slide-based lecture between labs. 3 labs + welcome + wrap-up quiz = 5 total Instruqt challenges. `track.yml` allows 5400s.

**Rationale:** Matches the reference track's pattern. The wrap-up quiz serves as consolidation for self-paced learners and a natural closing beat for presenters.

---

## App architecture: single Python process serving frontend + API

**Decision:** One FastAPI process serves both the HTML/JS frontend (as static files) and the `/chat` API endpoint on port 3000. Config evaluation and Bedrock calls happen server-side in Python; the JS frontend only handles UI.

**Rationale:**
- The reference track's app is a single process on port 3000; matching this means learners' muscle memory carries over.
- Config evaluation belongs server-side regardless — prompts and SDK keys shouldn't be in the browser.
- Single repo, single language to edit per challenge (server-side Python for AgentControl concepts; the JS exists but learners barely touch it).
- One process = simpler VM image, fewer ports, fewer ways to break.

**Options considered:**
- *Separate Python API + static JS frontend on different ports.* Rejected: more moving parts for no learning gain.
- *Node/Next.js stack matching the reference track exactly.* Rejected: the operator chose Python for server-side, and that's the more idiomatic stack for AgentControl SDK usage anyway.

---

## Tech stack: Python (FastAPI) + vanilla JavaScript

**Decision:** Server is FastAPI. Client is vanilla JS — no framework, no build step.

**Rationale:** The operator specified Python and "plain JavaScript" for simplicity, given learners will copy/paste code in some challenges. Vanilla JS is easier to read and modify in a code editor without tooling. FastAPI was chosen over Flask because of native async support (Bedrock calls benefit) and cleaner type-hint ergonomics.

---

## LLM provider: AWS Bedrock

**Decision:** AWS Bedrock is the sole LLM provider. Models used: Claude Haiku 4.5 for Otto and for the brand-voice judge. (Earlier versions of this workshop also used Sonnet for a premium variation and Nova Pro for a guarded-rollout regression; both chapters are out of scope now, and `app/server.py`'s `BEDROCK_MODEL_IDS` map still carries the rows.)

**Rationale:**
- Single AWS account with IAM-controlled access means easier credential management for Instruqt's secrets system.
- Bedrock's catalog lets us tell the "swap models without redeploying" story credibly with three distinct options.
- Mixing Anthropic Claude (Haiku, Sonnet) with Amazon Nova in challenge 7 gives the cross-family demo real teeth — the judge catches a regression from a genuinely different model family, not just a different size.

**Options considered:**
- *Direct Anthropic API.* Rejected: only one model family available, weaker variation story.
- *Cross-family from the start (e.g. Haiku vs Nova in challenge 5).* Rejected: in challenge 5 we want to show "premium variation with better model"; same-family-different-size (Haiku → Sonnet) tells that story more clearly. Save the family swap for challenge 7 where it serves the judge/guarded-rollout narrative.

---

## Retail-shop fiction: ToggleWear, single page, no commerce

**Decision:** The site is "ToggleWear," a fictional retailer selling LaunchDarkly-branded apparel. Single page: header (logo + user-tier dropdown), product grid of 6-8 items, Otto the shopping-assistant chat widget. No cart, checkout, auth, or commerce.

**Rationale:**
- A retail shop is instantly legible — every learner understands the use cases (recommendations, support, brand voice).
- LaunchDarkly-branded apparel keeps the demo "in-family" — the brand reference is amusing without being distracting.
- Single page minimizes UI surface area; the app exists to host Otto, not to be a real store.
- No commerce functionality avoids scope creep into payment forms, user accounts, etc.
- ToggleWear is deliberately *not* a fork of the legacy Toggle Outfitters app — fresh codebase, no library-rot inheritance.

---

## Otto: a shopping assistant chatbot

**Decision:** The AI surface is a chat widget named "Otto" embedded on the ToggleWear page. Otto can answer questions about products, ToggleWear policies, sizing, etc.

**Rationale:** Naming the AI gives the narrative a character. Each lab is a beat in Otto's development — born, given voice, branded, personalized, measured, governed. This carries the learner through the track with a story rather than a checklist.

---

## Cost protection: configurable turn cap per session

**Decision:** Python server enforces a turn cap per chat session, configurable via env var. Default to a value generous enough to complete the track comfortably. When exceeded, Otto returns a graceful "demo limit reached" message instead of calling Bedrock.

**Rationale:** Bedrock costs scale linearly with usage; an unattended Instruqt track being run by many learners in parallel could rack up bills via runaway loops, accidental retries, or curious learners spamming the chat. Per-session cap with env-var control gives operators a knob without redeployment.

**Open knob:** The specific default value should be set during implementation based on a realistic walkthrough of the track. Err high initially; tune down with real data.

---

## Cost protection at the model level

**Decision:** Haiku 4.5 everywhere — Otto, the brand-voice judge, and Claude Code. The traffic generator sends short messages to keep token counts low.

**Rationale:** Stacking architectural choices for cost control: cheapest viable model + tight turn cap + short generated traffic.

**Caveat added 2026-08-14:** the turn cap protects Otto and does nothing about Claude Code, which is by far the larger consumer — the LaunchDarkly MCP server's tool block alone ships on every request. An AWS Budgets alarm on the workshop account is the only real ceiling. See "Claude Code as the MCP client".

---

## Lecture content: out of scope for the track

**Decision:** The track contains no lecture content. Presenters deliver conceptual framing via slides between labs. The `notes` field in each challenge's front-matter contains only a one-paragraph orientation, mirroring the reference track.

**Rationale:** The operator delivers the lecture content via PowerPoint. Embedding lectures in the track would duplicate effort, force the self-paced flow to read material a presenter would deliver verbally, and make the track harder to update.

---

## Lecture-lab split delivers the same content at 2hr or 1hr

**Decision:** Labs stand alone — they're written so a self-paced learner can complete them without the lecture preamble. The 2hr format adds slide-based lecture between labs; the 1hr format skips lecture and runs labs back-to-back.

**Rationale:** Two delivery modes, one source of truth. The constraint this places on labs: `assignment.md` prose must carry enough conceptual context that an unsupervised learner can follow it without a presenter setting up each lab.

---

## File pairing convention: `.remote` files are not authored

**Decision:** Claude Code creates only the non-`.remote` versions of each file. The Instruqt CLI generates `.remote` mirrors on publish.

**Rationale:** Extracted from inspection of the reference track — all `.remote` files were byte-identical to their counterparts, indicating CLI-generated mirrors. Authoring both creates merge conflicts on publish.

---

## VM image inputs in repo, image build done by humans

**Decision:** Claude Code produces the *inputs* for VM image building (app source, Dockerfile or Packer config, install scripts, systemd unit files) in `vm-image/`. The actual image build is performed by a human operator and registered with Instruqt.

**Rationale:** Image builds require AWS/GCP credentials and Instruqt registry access that Claude Code doesn't have. Separating "what goes in the image" (Claude Code's job) from "build and register the image" (human's job) makes the handoff explicit.

---

## Terraform provider vs. REST API for Config resources

**Decision:** Prefer the `launchdarkly/launchdarkly` Terraform provider for Config resources where supported. Where the provider lacks Config support, fall back to REST API calls via `null_resource` + `local-exec curl`.

**Rationale:** AgentControl is a relatively new product. The Terraform provider may not yet cover every resource type. Provider-native is preferred (cleaner code, drift detection), but the REST fallback is unblocked while waiting for provider updates.

**Verification step:** During Phase 1, check the current Terraform provider documentation for Config resource support and record findings in `PHASES.md` Phase 1 notes.

---

## SDK version pinning

**Decision:** Pin specific versions of `launchdarkly-server-sdk`, `launchdarkly-server-sdk-ai` (`ldai`), `boto3`, `fastapi`, and `uvicorn` in `requirements.txt`. Verify latest stable versions at implementation time via web search; do not guess from training data.

**Rationale:** AgentControl SDK is evolving rapidly. Unpinned versions cause non-reproducible failures when learners run the track months after authoring.

---

## Narrative consistency owned by NARRATIVE.md

**Decision:** A separate `NARRATIVE.md` file holds Otto's story arc, voice guide, ToggleWear brand details, and product list. All `assignment.md` files should be consistent with it.

**Rationale:** Across 9 challenges authored over multiple sessions, voice drift is a real risk. A single source of truth for narrative concerns prevents it.

---

## Phase-by-phase build with operator review gates

**Decision:** Claude Code works one phase at a time per `PHASES.md`. After each phase, work pauses for operator review before the next phase begins.

**Rationale:** Catching architecture or convention drift early is much cheaper than catching it after 9 challenges are written. Phase gates also let the operator validate against real Instruqt deployment between phases if desired.

---

## UI instructions in assignment.md: drafts subject to operator verification

**Decision:** Claude Code drafts click-by-click LaunchDarkly UI instructions in `assignment.md` files based on reading the public AgentControl docs. The operator then walks through each flow with the draft open, corrects UI specifics (button labels, menu paths, step ordering), captures screenshots, and removes `<!-- VERIFY: ... -->` markers. Phase done-when conditions require this operator verification pass before sign-off.

**Rationale:** Claude Code cannot drive a browser in this environment — it can't click through the LaunchDarkly UI to verify flows itself. Options considered:

- *Operator screen-records each flow first, Claude Code transcribes.* Higher first-draft accuracy, but expensive operator time upfront and dependent on flow being known before authoring.
- *Operator gives Claude Code an LD account.* Doesn't help in this environment — Claude Code still can't drive a browser from a chat session. Would only help with a separate browser-agent product (e.g. Claude in Chrome), which is a workflow change.
- *Claude Code hedges in prose ("navigate to roughly the configs area").* Rejected — produces unusable instructions. Learners need specifics.
- *Hybrid: confident drafts from docs + operator click-through pass.* Chosen. Lowest total operator time, highest first-draft quality given the tooling constraint.

This decision is enforced in `CLAUDE.md` ("UI instructions in assignment.md are drafts pending operator verification") and in every UI-touching phase's done-when in `PHASES.md`.

---

## LD model name → Bedrock model ID lives in the app, not the Config

**Decision:** LaunchDarkly's model config registry stores vendor-neutral model names like `claude-haiku-4-5`, `nova-pro`. The app's `server.py` maintains a `BEDROCK_MODEL_IDS` dict that maps each to the corresponding Bedrock model or inference-profile ID (e.g. `us.anthropic.claude-haiku-4-5-20251001-v1:0`). Adding a new model means a row in that dict — no Config changes needed.

**Rationale:** Discovered the hard way during Phase 3: the `modelName` passed when creating a variation is a hint, but what `cfg.model.name` returns from the SDK is the model config's vendor-neutral `modelId`. Bedrock needs the full model/profile ID. The cleanest place for that translation is the boundary where we leave LD-land and enter AWS-land — in the app's Bedrock client wrapper.

**Side benefit:** The LD Config stays vendor-agnostic. If we ever swap Bedrock for OpenAI direct, only `BEDROCK_MODEL_IDS` (or its OpenAI equivalent) changes — the Configs and variations don't.

---

## Per-challenge Terraform modules are independent and hybrid

**Decision:** Each challenge has its own `terraform/challenge-NN/` module with its own state. Modules use:

- `launchdarkly_*` resources for NEW resources introduced by that challenge (e.g. challenge-01 creates the Haiku model_config, the Config, and the first variation; challenge-02 creates the judge config, its variation, and the score metric; challenge-03 creates the thresholds flag).
- `null_resource` + `local-exec curl` for: updates to resources owned by earlier challenges' modules (which Terraform can't touch from a different module without `terraform import`), and for resources the provider doesn't yet expose (snippets, Config targeting rules, guarded rollouts, Config `evaluationMetricKey`).

**Rationale:** Each challenge's solve must produce the END STATE of that challenge regardless of whether prior challenges were completed in code or skipped. Terraform's per-module state model doesn't share resources across modules, so updates to "already-managed" resources need to go through either `terraform import` (operationally heavy) or REST API (lightweight). REST via `null_resource` won.

**Side effect:** Some idempotency is on us — for example, challenge-03's snippet POST has `|| echo "(may already exist)"` because the second apply would 409. Worth the trade-off for state simplicity.

---

## server.py BEFORE state + marker-based paste pattern

**Decision:** `server.py` ships from the VM image in a BEFORE state: imports/init/helpers/turn-cap pre-wired, but `/chat`'s body is a clearly-marked stub block returning a canned "not wired yet" response. Challenge 01 has the learner replace the stub with ~30 lines of Config + Bedrock eval logic. The solve script applies the same paste programmatically using a Python script that finds the markers and substitutes the block.

**Amended 2026-08-14 — challenges 02 and 03 replace function bodies, not inline fragments.** The chained-inline-fragment version shipped two coupling bugs: the gate read a `brand_voice_score` local that the judge block bound only inside a `try`, and it rewrote `assistant_text` after the Bedrock block had already written the original into `_history`, so Otto remembered answers the customer never saw. Neither was visible from inside the block being edited, because three fragments sharing mutable locals is a contract with no signature.

`server.py` now ships two stubs — `score_response(req, assistant_text, model_id) -> Optional[float]` and `gate_response(req, assistant_text, score, model_id) -> tuple[str, str]` — and `/chat` calls them in order, then `_remember()`. Each patch script replaces one function body, verifying the expected stub `return` is directly below the marker before touching anything. Data flows through arguments and returns, so a future block cannot silently desynchronize state it has no access to. The stub defaults (`None`, and `(assistant_text, "ship")`) mean the app is correct at every stage: un-wired behaves exactly like pre-challenge-02 Otto rather than raising.

Challenge 01 still replaces an inline block, because it genuinely is the handler body.

**Rationale:** Two-step staged code injection keeps each challenge's setup self-contained while making it possible for later challenges to extend the same file. Pure Python `find/replace` on stable comment markers is more robust than line-number-based patching and survives the learner doing the paste manually vs. via solve.

**Trade-off:** The marker comments persist in the final server.py code. Acceptable — they're inert single-line comments with clear purpose.

---

## Judge invocation: SDK eval + manual Bedrock call

**Decision:** The judge integration in `server.py` (added by Challenge 02's paste) calls `ai_client.judge_config(...)` to evaluate the `otto-brand-voice-judge` Config (which interpolates the `{{response}}` template variable with Otto's answer), then calls `bedrock.converse()` manually with the resulting model and messages. The 0.0-1.0 score is parsed from the response text and emitted via raw `ld_client.track("otto-brand-voice-score", ...)` rather than `tracker.track_judge_result(...)`.

**Rationale:** The `ldai` SDK supports a higher-level judge flow via `create_judge()` + `judge.evaluate()`, but it relies on an AI Provider plugin system (langchain, openai). There's no `ldai_bedrock` provider as of authoring. Writing a custom provider was scoped out. Manual Bedrock invocation works fine and stays transparent to the workshop's audience — the code reads exactly like the regular Otto eval.

---

## Traffic generator skips Bedrock entirely

**Decision:** `traffic-generator/generate_traffic.py` and `background_traffic.py` evaluate the Config to get a real tracker, then emit synthetic `track_duration`, `track_tokens`, `track_success`, and `track_feedback` events with values weighted per model. They do NOT call Bedrock.

**Rationale:** Real Bedrock calls would make 120 sessions take ~10 minutes and cost real money per learner. The monitoring view only consumes the LD-side metric events, so skipping Bedrock costs nothing in terms of what the lab shows. Weights are tuned so Sonnet looks visibly better than Haiku in the dashboard, and Nova Pro Stiff looks worse — the comparison is what matters, not the absolute numbers.

**Note:** a companion `sabotage.py` existed to force guarded-rollback demos by emitting low scores. It was deleted with the guarded-rollout chapter.

---

## Custom judges score 0.0–1.0, not 1–5 (2026-06-01)

**Decision:** Every custom judge in Evaluate scores responses on a 0.0–1.0 scale. The score parsing in each judge's server.py paste reads `float(text.split()[0])` with a try/except fallback. The legacy Build ch07 used a 1–5 integer scale; that was changed when ch07 lifted into Evaluate.

**Rationale:**
- LD's built-in judges (Accuracy, Relevance, Toxicity) score 0.0–1.0. Mixing 1–5 custom judges with 0.0–1.0 built-ins in the same monitoring view was inconsistent.
- Float scoring gives the LLM judge more resolution to express degrees of correctness ("borderline" = 0.5) without retraining learners on what a "3" means versus a "4".
- The threshold values for guarded rollouts and adaptive switching are simpler in 0.0–1.0 ("watch for the mean dropping below 0.5") than they would be in 1–5 ("below 3.0").

**Side effect:** `traffic-generator/background_traffic.py` emits floats rather than ints, against the `otto-brand-voice-score` metric key.

**Later consequence:** the 0.0-1.0 scale is what makes challenge 03's three-band review gate readable. `{"auto": 0.8, "review": 0.5}` is legible at a glance in a way that thresholds on a 1-5 integer scale would not be.

---

---

## Scope cut to one track: config, judge, human-in-the-loop (2026-08-14)

**Decision:** The three-track workshop (Build / Evaluate / Coordinate, 30 challenges) is replaced by a single four-challenge track in `instruqt-agentcontrol-mcp/`. New slug `ld-agentcontrol-mcp` and a new track id; the old `ld-agentcontrol-build` track and its siblings are deleted rather than archived.

**Rationale:** The three tracks were breadth-first — every AgentControl feature got a chapter. What was missing was a short, sharp answer to "what does this look like in my workflow." Four chapters that go deep on one path beat thirty that tour the product.

**What went, and where it's acknowledged:** prompt snippets, targeting by user attribute, prompt experiments, guarded rollouts, offline evaluations against datasets, adaptive switching, and the whole multi-agent Coordinate arc. Each is named in `04-wrap-up` as a next step, so a learner leaves knowing what exists rather than believing the product is smaller than it is.

**Cost:** git history is the only record of the deleted tracks. Anyone reviving Evaluate or Coordinate starts from `git log`, not from a branch.

---

## MCP server replaces the LaunchDarkly UI as the build interface (2026-08-14)

**Decision:** Every resource the learner creates — Config, variation, targeting rule, judge, judge attachment, metric, flag — is created by prompting Claude Code against the hosted LaunchDarkly MCP server at `https://mcp.launchdarkly.com/mcp/launchdarkly`. The LaunchDarkly UI is used only for inspecting results and reading Monitoring charts.

**Rationale:**
- It's how a growing number of developers actually work, and a workshop that only teaches clicking teaches a workflow the audience is leaving.
- It removes the workshop's single largest maintenance cost. Click-by-click UI instructions rot on every UI change, and `CLAUDE.md` had a whole section admitting they ship unverified. Prompts describing intent are far more stable.
- The resources produced are indistinguishable from clicked ones, which is itself the lesson: the MCP server is another interface onto the same product, not a parallel one.

**Precedent:** the AWS SDLC workshop at `aws-sldc-v2` does exactly this with Kiro CLI, including the "your token reaches one project, so just say *my project*" framing that we adopted verbatim in spirit.

**Cost, and it's real:** an LLM is non-deterministic and `check-workstation` is not. Every check had to be loosened to assert on keys, modes, and model families rather than display names or prompt wording, and each retries briefly to avoid racing the agent's last write. Prompts also have to name every key explicitly, because downstream chapters and the app depend on them.

**Options considered:**
- *Teach both, UI and MCP.* Rejected: doubles chapter length and the comparison isn't interesting enough to pay for.
- *Keep UI instructions, mention MCP in the wrap-up.* Rejected: that's the version that already existed.

---

## Claude Code as the MCP client, running on Bedrock (2026-08-14)

**Decision:** Claude Code is installed on the VM image at a pinned version and run from the code-server terminal in the existing "Code Editor" tab. It authenticates to a model via Bedrock (`CLAUDE_CODE_USE_BEDROCK=1`), reusing `AWS_PROFILE=BedrockProfile`, with `ANTHROPIC_MODEL` pinned to a Haiku 4.5 inference profile.

**Rationale:**
- No new credential type. `DECISIONS.md` already committed to Bedrock as the sole LLM provider, and an `ANTHROPIC_API_KEY` Instruqt secret would have been a fifth credential pathway.
- The code-server tab already exists in the three-tab layout, so config-building and `server.py` editing happen side by side without a new tab.
- `ANTHROPIC_MODEL` must be pinned. Claude Code's Bedrock default is now Opus 5, which is neither in the IAM allowlist nor priced for a workshop, and an unpinned session fails on the learner's first prompt rather than at startup.

**Consequences to watch:**
- Claude Code is a much heavier Bedrock consumer than Otto. `LD_CHAT_TURN_LIMIT` caps the app's spend and does nothing here; an AWS Budgets alarm on the workshop account is the only real ceiling.
- The machine type went from `n1-standard-2` to `n1-standard-4`. Claude Code alone wants 4 GB, and the box already runs code-server, uvicorn, and the traffic generator.
- `terminal.integrated.sendKeybindingsToShell` is set in code-server's settings, because xterm.js otherwise swallows Escape and Shift+Enter, which the Claude Code TUI needs.

---

## MCP auth: bearer header with the scoped lab token, not OAuth (2026-08-14)

**Decision:** `app/.mcp.json` and the user-scope entry in `/root/.claude.json` both carry `Authorization: Bearer <LD_API_TOKEN>`, rendered at lab start from committed templates with a `__LD_API_TOKEN__` placeholder. The learner performs no MCP setup and sees no OAuth flow.

**Rationale:** OAuth in an Instruqt sandbox means a browser round-trip and a real LaunchDarkly login inside a VM whose LD access is a simulator lambda. It would be the most fragile step in the track, and it would be step one. Header auth makes the connection a fact of the environment.

**Known risk, stated plainly:** LaunchDarkly's hosted-MCP documentation describes OAuth only and tells you to remove token env vars. Header auth against the hosted URL is undocumented — our evidence is that the AWS workshop does it and it works. If it's ever tightened, `.mcp.json` header auth does **not** fall back to OAuth; the server just fails to connect. `00-welcome/check-workstation` therefore asserts it directly with a raw `tools/list` curl, so the failure surfaces at setup with an operator-actionable message rather than as a confused learner. The documented fallback is the local `npx @launchdarkly/mcp-server` stdio server with `--api-key`.

**Sub-decision — the server is registered at user scope.** A project `.mcp.json` approved only by the repo's own `.claude/settings.json` stays pending approval in an untrusted folder, so the authoritative registration lives in `/root/.claude.json`. `app/.mcp.json` is still written, as the visible teaching artifact.

**Sub-decision — the token is written literally, not as `${LD_API_TOKEN}`.** code-server runs from systemd as root and does not inherit the exports appended to `~/.bashrc`. An unset variable with no default doesn't fail loudly: the config still loads and the literal string `${LD_API_TOKEN}` is sent as the bearer.

**Accepted exposure:** the learner can read the token. code-server is `--auth none` and everything runs as root. The blast radius is one sandbox project, and `cleanup-workstation` now revokes the token by id — which the old script couldn't do, because it discarded the `._id` at mint time and leaked a live token on every lab run.

---

## Judge attachment is declarative; the app does the invoking (2026-08-14)

**Decision:** The learner attaches `otto-brand-voice-judge` to the `otto-born` variation with a 25% sampling rate **and** pastes a block into `server.py` that invokes the judge itself. The assignment says outright that attachment does not cause the judge to fire.

**Rationale:** `ldai` 0.20.1 can run attached judges only through a provider plugin, and there is no Bedrock provider. Attachment is what populates the Judges panel and records the sampling rate in LaunchDarkly; the paste block is what actually calls the model. Pretending the attachment is sufficient would leave the learner unable to explain why their code exists — so `04-wrap-up`'s quiz question is exactly this.

**Sampling is 100%, not 25% (amended 2026-08-14).** The first draft attached at 25% while the app's judge call graded every response, so the declared rate was decorative — a detail a sharp learner would catch. Honouring the rate would have been worse: with only a quarter of responses scored, challenge 03's gate would ship the rest ungraded via its fail-open branch, teaching that a review gate mostly doesn't apply. Both the attachment and the code are now 100%, and the assignment says why: sampling is a real cost lever, and this lab needs a score on every answer.

**Alternative rejected:** switching the app to an `ldai`-supported provider (openai or langchain) to get automatic evaluation. That would break the Bedrock-only decision and rewrite `server.py`'s Bedrock path for a pedagogical convenience.

---

## Review thresholds live in a JSON flag, not in code (2026-08-14)

**Decision:** The review gate's two thresholds are one JSON flag value, `otto-review-thresholds`, serving `{"auto": 0.8, "review": 0.5}`. `server.py` reads the flag on every turn with `REVIEW_DEFAULTS` as the fallback.

**Rationale:**
- One JSON value rather than two numeric flags: a threshold change is one atomic edit, and two flags can disagree with each other in a way that silently disables the middle band.
- Nobody guesses these numbers right the first time. Putting them in LaunchDarkly turns "we picked the wrong band" from a deploy into a click, and gives the chapter its payoff — the learner switches to `Cautious` and watches routing change with no restart.
- It applies the flag pattern to a governance decision rather than a feature, which is the more interesting version of the same story.

**Sub-decision — a missing judge score ships rather than holds.** The judge is a second model call inside the customer's request. When it fails, the code serves Otto's answer ungraded. Making a customer wait on a human because our judge timed out is the worse outcome, and a hold that nobody is staffed to clear is just a dropped response. This is a defensible choice rather than an obviously correct one, and the assignment says so and tells the learner to reread that branch.

**Sub-decision — the review queue is in memory.** It shares `_turns` and `_history`'s fate: a lab-length lifetime, lost on restart, capped at `REVIEW_QUEUE_LIMIT` entries. A durable queue would be honest engineering and pure distraction.

---

## `evaluationMetricKey` convention: bare metric name (2026-08-14)

**Decision:** A judge Config's `evaluation_metric_key` is the bare name (`otto-brand-voice-score`), not the prefixed form (`$ld:ai:judge:otto-brand-voice-judge`). LaunchDarkly applies the `$ld:ai:judge:` prefix itself.

**Rationale:** The repo previously carried both spellings — `terraform/evaluate-03` set the prefixed form while `evaluate-07`'s check expected the bare one, and the resource that would have reconciled them was commented out. Nothing set it, so a check asserted a state no code path produced. One convention, written down, and the dead commented block deleted rather than carried forward.

**Note:** the judge's own metric surfaces as `$ld:ai:judge:otto-brand-voice-score`, while the custom metric the app emits directly is the plain `otto-brand-voice-score`. Those are two different things that read almost identically in the UI. The learner is pointed at the custom one.

---

## Otto knows the catalog; he just has no manners (2026-08-14)

**Decision:** Otto's challenge-01 system prompt includes the eight products, sizes, and store policies. It still says nothing about tone.

**Rationale:** The first draft gave him two bland sentences and no product data, then asked a brand-voice judge to grade his answers to questions like "what material is the Rollout Tote?". He could only decline, and a rubric that scores declining-to-help low would have pushed most responses *below* challenge 03's suppress threshold — so the review queue, which is that chapter's entire point, would have starved while the storefront looked broken.

Competent-but-cold is the artifact the track actually needs. The judge's complaint becomes purely about voice, which is what it's named for. And "approve with an edit" becomes meaningful work — warming up a correct answer — rather than rubber-stamping an apology.

**Do not "improve" this prompt.** Otto never gets the warm version in this track. The gap between what he says and how ToggleWear wants him to say it is what challenges 02 and 03 are built on; closing it empties both. `terraform/challenge-01/main.tf` carries this warning inline.

**Related rubric fix:** the judge's scale listed "honest when you don't know something" as a 1.0 trait while an answer consisting entirely of not knowing is obviously not a 1.0. That contradiction left every borderline score to the model's mood. The rubric now scores cold-but-correct at 0.4, declining-to-help at 0.2, and says explicitly to judge tone rather than correctness.

**Still unvalidated:** the actual score distribution. `{auto: 0.8, review: 0.5}` are reasoned guesses. Measure them in Phase 4 and move the numbers in `terraform/challenge-03/main.tf`, the assignment, and `NARRATIVE.md` together.

---

## The reviewer gets its own surface (2026-08-14)

**Decision:** The review queue is a separate page at `/review`, opened as a fourth Instruqt tab ("Staff Review") in challenge 03 only. It is not a panel on the storefront.

**Rationale:** The chapter's one idea is that a different person, with different authority, sees a response before the customer does. Two tabs make that structural — you change context by changing tabs, which is what actually happens in a support org. A panel below the product grid says "same person, same screen, same authority" and undercuts the thing being taught. It also replaced the role switch with a scroll.

**Cost:** it breaks the "three tabs on every challenge so indices are stable" convention in `CLAUDE.md`, which is now amended to "three tabs, plus a fourth on challenge 03". Indices 0-2 are unchanged, so no existing `#tab-N` reference moved. The poll loop was factored out of `app.js` into `review.js` rather than duplicated; the storefront keeps only the half that drains a reviewer's decision into the chat transcript.

**Open:** whether an Instruqt service tab honours a `path:` key to deep-link `/review`. A `VERIFY` marker sits on that line, and the storefront has a "Staff review" nav link as the fallback.

---

## The queue is scoped to the learner's session (2026-08-14)

**Decision:** `GET /review/queue` takes a `session_id` and returns only that session's held responses, plus a count of the rest.

**Rationale:** `realchat_traffic.py` drives `/chat` every 2-4 seconds for the whole lab with a fresh session per request, and all of it flows through the gate. An unscoped queue buries the learner's own held response under bot items within a minute and evicts it at the 50-item cap. The count of other sessions keeps the queue reading as a real one — a reviewer's queue with exactly one item in it looks staged — without making the learner hunt.

**Consequence:** the learner only ever adjudicates their own responses, so the role separation is a role-play rather than a real division. Accepted: the alternative was a queue where the demo doesn't work.

---

## Authoring docs are deleted from the VM clone (2026-08-14)

**Decision:** `vm-image/build-image.sh` deletes `CLAUDE.md`, `DECISIONS.md`, `PHASES.md`, `NARRATIVE.md`, and `OPERATOR-CHECKLIST-mcp.md` from `/opt/ld/ai-configs-intro` after cloning.

**Rationale:** Claude Code auto-loads `CLAUDE.md` from the repository root into every session. These files describe how the labs are built, including the exact resources each challenge expects — they are the answer key, and they'd also burn several thousand tokens on every request.

A `permissions.deny` entry was the first attempt and is the wrong tool: it only blocks the `Read` tool, leaves the files on disk for any other access path, and fails open if a key name changes. Deleting them is unconditional. `terraform/` and the track directory stay on disk because setup and solve scripts need them, and those keep their deny entries.

---

## Bedrock credentials resolve on demand via credential_process (2026-08-14)

**Decision:** `/root/.aws/config` defines `BedrockProfile` with a `credential_process` that exchanges the GCE instance identity token for an STS session at resolution time. `/opt/ld/bin/bedrock-credential-process.sh` does the exchange; role ARN and JWT audience come from `/etc/bedrock-federation.env`, filled in from `gcp-federation/` outputs before baking.

**Rationale:** Nothing in this repo previously wrote `~/.aws` at all, while `app/server.py` and now Claude Code both ask for a profile named `BedrockProfile`. The federated session the repo documents lasts an hour, so a credential baked at image time is dead before the image is even saved — meaning either undocumented long-lived IAM keys were being hand-written at bake, or Bedrock calls were failing. `credential_process` resolves on demand, honours `Expiration` so boto3 and Claude Code both refresh, and serves boto3, the AWS CLI, and Claude Code from one mechanism with one failure mode to test.

A refresh at track setup was rejected: a 1-hour maximum session against a lab that can run three hours dies mid-lab, probably during the most expensive chapter.

**The AWS CLI is now installed at bake**, because the credential process shells out to `aws sts assume-role-with-web-identity`.

**Unverified and it matters:** the IAM trust policy pins `accounts.google.com:sub` to a specific GCP service account. If the bake VM and the runtime sandbox run under different service accounts, this succeeds in testing and fails at lab time with an opaque `AccessDenied`. Must be tested on a real Instruqt sandbox. The `--max-time 5` on the metadata call is not optional: Claude Code aborts the whole credential chain after 60 seconds, and a hung metadata call presents as a broken model rather than a broken credential.

---

## Every prompt-driven step gets a read-back (2026-08-14)

**Decision:** Each chapter follows its build prompt with a verification prompt asking the agent to describe what it created, and `00-welcome` carries a "When the agent gets it wrong" section covering the four failures that actually happen.

**Rationale:** An agent reports success from its own intent, not from re-reading the result. Checking its work is the skill that transfers to the learner's real job, and it's the only point in the track where a Config's structure is described in plain language rather than merely asserted by a green check — which matters, because the failure mode of a prompt-driven workshop is teaching "type wish, get check mark."

Recovery guidance previously lived only in `fail-message` strings, which a learner sees only after failing. One section they can reach at any time is better and keeps the fail-messages short.

**Rejected:** deliberately under-specifying a prompt so the learner must catch the agent. Staging a failure requires determinism we don't have — if the agent gets it right, the beat evaporates and the learner is left wondering what they missed.

---

## Spike results: the scoped token, corrected (2026-08-14)

**Ran against a live trial account.** Everything below is verified, not inferred. Three tokens minted and revoked, a throwaway project created and deleted.

**Bearer-header auth against the hosted MCP server works.** `POST https://mcp.launchdarkly.com/mcp/launchdarkly` with `Authorization: Bearer <token>` returns a normal `initialize` result and an `Mcp-Session-Id`, and `tools/list` returns **120 tools** including every one this track needs. The risk that this path is unsupported is retired for now; it remains undocumented, so the fallback note stands.

**The inline role in `setup-workstation` was broken and would have failed the lab at startup.** `proj/<key>:*` is not a valid resource specifier — the API returns 400 "Error parsing resource specifier". Since the script runs under `set -euo pipefail` with `curl -fsS`, the whole track-level setup would have aborted. Corrected form, all of it established by probing:

- There is no "everything under a project" wildcard. Each resource kind needs its own specifier.
- **One kind per statement.** Mixing `proj/<key>` and `proj/<key>:env/*` in a single statement is 400: "Resource specifiers in a single statement must represent the same kind of resource."
- Flags, AgentControl configs, and segments are children of an **environment**: `proj/<key>:env/*:flag/*`, not `proj/<key>:flag/*`.
- The AgentControl kind is spelled **`aiconfig`**, lowercase. Without it, creating a Config is 403 and challenge 01 is impossible. `aiConfig`, `ai-config`, `agentConfig` are all rejected by the parser.
- `ai-model-config` is documented but the parser rejects it. Omitted; model configs still resolve.
- `prompt-snippet` and `metric` are project-level children.

**Allow statements do not restrict — a deny is required, and its absence was a data-exposure bug.** With allows only, the token could `list-projects` and see *every* project in the account, and `get-project` on an unrelated project returned its **SDK keys**. In the 729-project account this workshop runs in, that is a serious leak from a token handed to every learner. Fixed with the containment statement the sibling AWS workshop uses:

```json
{"effect": "deny", "actions": ["viewProject"], "notResources": ["proj/<key>"]}
```

Verified after: `list-projects` returns exactly one, `get-project` on another project is 403. That also makes challenge 00's "you should see exactly one project" true — it was false before, which would have undermined the "just say *my project*" convention the whole track relies on.

**`evaluationMetricKey` must carry the `$ld:ai:judge:` prefix.** The API rejects a bare name outright: `evaluationMetricKey must start with "$ld:ai:judge:"`. This reverses the earlier "bare metric name" decision above, which was wrong. Fixed in `terraform/challenge-02/main.tf`, the challenge-02 prompt and spec table, and asserted in that chapter's check.

**Verified working with the corrected scoped token:** creating a completion-mode Config; creating a variation (stores `modelConfigKey` exactly as the check asserts); creating a judge-mode Config; creating a JSON flag with two object variations; creating a custom numeric metric; attaching a judge via `PATCH .../variations/<key>` with `judgeConfiguration`; and setting the AgentControl fallthrough via the semantic-patch `updateFallthroughVariationOrRollout` instruction — which is exactly what `terraform/challenge-02` already does.

**MCP tool quirks worth knowing, none blocking.** These affect the agent's job rather than ours, and an agent will iterate past them, but they explain retries a learner may see:

- Most AgentControl tools take `env`, not `environmentKey`.
- `create-agentcontrol-config-variation` requires **both** `modelName` and `modelConfigKey`.
- `create-metric` takes `measureType` (`count`/`occurrence`/`value`), not `isNumeric`.
- `update-agentcontrol-config-rollout` matches a variation by **name**, not key.
- **`toggle-agentcontrol-config` is broken for Configs**: it sends `turnFlagOn`, which the AgentControl targeting endpoint rejects with "invalid instruction 'turnFlagOn'". Only `updateFallthroughVariationOrRollout` works. Every assignment therefore says "set the default rule" rather than "turn it on" — keep it that way.

**Still unverified:** whether an agent reliably produces the exact keys from these prompts. That needs Claude Code driving the server, not raw JSON-RPC, and it's Phase 2 work.

---

## Platform traps found by actually running the track (2026-08-14)

Everything here was found by `instruqt track test` or a live lab, not by reading docs. Each one presented as something other than what it was.

**`machine_type` is not a field in `config.yml` version 3.** Both `instruqt track validate` and `push` accept it silently as an unknown key. The VM then has no size and the track fails to provision with only "Unable to start track, please try again." Removing it surfaces the real schema error: `virtualmachines: cpus: cannot be blank; memory: cannot be blank`. Size VMs with `cpus` and `memory`. Note the upstream reference track carries a `machine_type` line and no size, so it has the same latent problem.

**The operator's LaunchDarkly secret is a service token, and service tokens cannot create personal tokens.** `POST /api/v2/tokens` creates a *personal* token unless you pass `serviceToken: true`. The error is a bare 403, which reads exactly like a permissions problem — I asserted "Writer, not Admin" twice on that basis while the token was in fact Admin. The response body said `Service tokens cannot create personal tokens` the whole time. A service token is also the right type here: not tied to a member, so it doesn't inherit a member's role and doesn't break when someone leaves.

**Lead with the API's response body in error handling, not your interpretation of the status code.** The 403 branch printed my hypothesis and dropped the body. That cost several wrong turns. Print what the service said first, then your guess.

**`/bin/sh` is dash on Ubuntu, and dash's builtin `echo` interprets backslash escapes.** `echo "$JSON" | jq` converts escaped `\n` inside JSON strings into real newlines, and jq fails with `Invalid string: control characters from U+0000 through U+001F must be escaped`. Always `printf '%s' "$JSON" | jq`. This lay dormant until challenge 01's prompt became multi-line: with a single-line prompt there were no escapes to mangle. `bash -c 'echo "a\nb"'` prints one line; `dash -c` prints two.

**LaunchDarkly reports a JSON flag's `kind` as `multivariate`, not `json`.** The variation *values* are what make it JSON. A check asserting `kind == "json"` fails on every correctly built flag.

**A judge's `evaluationMetricKey` must start with `$ld:ai:judge:`.** A bare metric name is rejected with 400. It is returned at the top level of `GET /ai-configs/{key}` (verified), so a check can assert it directly.

**Pin `LD-API-Version` on every call.** Requests without the header inherit whatever version the operator's token pins — the team's pins `20240415`, which predates AgentControl. Only 2 of 12 call sites were pinned; the unpinned `ai-configs` calls would have returned the wrong shape or failed for reasons that look nothing like a version problem. AgentControl endpoints need `beta`.

---

## Checks must assert behaviour, not file contents (2026-08-14)

**Decision:** Every challenge's `check-workstation` exercises the running app, not just the LaunchDarkly API and a `grep` of `server.py`.

**What prompted it:** a learner whose Bedrock credentials were missing got **"Success! Click next to start the next challenge"** on challenge 01 — the chapter whose stated goal is "Otto says his first words." The check confirmed the Config existed and the right code was on disk. Otto could not reach a model at all. The learner would have carried a broken Otto into challenge 02 with no signal.

**Now:** ch01 POSTs to `/chat` and reads the reply; ch02 requires a brand-voice score in the service log; ch03 requires a logged gate decision and non-default thresholds.

**A detail that matters:** the failure messages distinguish *"you haven't finished"* from *"this is a lab credentials problem, tell your instructor."* Those need opposite responses from the learner, and a check that conflates them sends people to debug something they cannot fix.

**ch02 deliberately reads the log rather than the response.** Judge failures are swallowed so a broken judge never poisons a customer's chat — which means Otto replies normally and the response body cannot reveal the failure. The log is the only honest signal. That is a general lesson: when the app is designed to fail open, the check has to look where the failure is actually recorded.

**Cost:** each Check press makes real model calls. Accepted. A green check should mean the chapter works.

---

## Bedrock uses static AWS keys; GCP federation cannot work on Instruqt (2026-08-14)

**Decision:** `track_scripts/setup-workstation` writes a `[BedrockProfile]` into `/root/.aws/credentials` from the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` Instruqt secrets. No `credential_process`, no role assumption, no GCP identity token.

**Why the federation cannot work, measured rather than assumed:** the credential process has to fetch a GCE instance identity token from `metadata.google.internal`. On a live Instruqt workstation that request times out:

```
curl: (28) Operation timed out after 5002 milliseconds with 0 bytes received
```

The metadata endpoint is simply not reachable from the sandbox. No role ARN, audience, or trust-policy change can fix that, because the token can never be obtained in the first place. This also explains a red herring: `RoleForAccessFromInstruqt` had a `RoleLastUsed` of a week earlier, which I read as evidence the federation worked from these labs. Something else was using that role.

**What this cost:** most of a day. I ranked the STS exchange as the top risk and then built `credential_process` plumbing, a JWT-`sub` diagnostic, and operator documentation around it — all for a path that could never work here. The check that settled it took one command in a live lab. Reach for that first when a claim is about *the environment* rather than about code.

**Trade-off, accepted deliberately:** long-lived keys land on a box the learner has a root shell on, so a learner can read them. Federated short-lived credentials would be better. Mitigations: scope the IAM user to Bedrock invoke on the workshop's inference profiles and nothing else, and treat the keys as rotatable. `gcp-federation/` stays in the repo as documentation of the intended posture and for any environment where metadata *is* reachable.

**Consequence:** `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are now load-bearing rather than declared-but-unused, and `app/server.py`'s `profile_name="BedrockProfile"` finally resolves to something real.

---

## The LaunchDarkly UI tab is provisioned by writing two DynamoDB rows, with boto3 rather than the AWS CLI (2026-08-17)

**Decision:** `track_scripts/setup-workstation` writes a row to `instruqt-workshop-production-users` and one to `instruqt-workshop-production-sandbox`; `cleanup-workstation` deletes both. Both use **boto3 via the app venv's python**, not `aws` CLI subcommands, and both clear `AWS_PROFILE` with `env -u AWS_PROFILE` rather than `AWS_PROFILE=`.

**How the tab actually works,** since nothing documented it: the virtual browser opens a redirector lambda with `?sandboxId=${_SANDBOX_ID}`. That lambda polls the sandbox table for a matching row, then `301`s to the `LoginUrl` stored in it. The login lambda validates `token` as `HMAC-SHA256(LoginSecret, "<ProjectId>.<expires>")`, looks the project up in the users table, and returns a page that auto-POSTs a signed SAML assertion. **On a missing row it polls for a full 60 seconds and then returns a 502** — measured at `1:00.39`.

**Two things this makes load-bearing:**

- **`LoginExpiresAt` must be unix *seconds*.** Milliseconds fail.
- **The SAML recipient is hardcoded** to account `652d7d3060d93a12fccd6e2e` (cert: "LaunchDarkly Workshop IdP", issued 2023-10-16). The assertion carries *only* an email — no role or project attributes — so LaunchDarkly auto-provisions the member into that one account. The tab therefore only works while `LAUNCHDARKLY_ACCESS_TOKEN` belongs to that same account. It does: the secret was created 2023-10-16, hours after the cert, and is described as "Specific to the workshops@launchdarkly.com account." **Repointing that secret at another account — a trial account, say — silently signs learners into an account with no project in it.** That is the constraint to check first if the tab ever shows a logged-in-but-empty LaunchDarkly.

**Why boto3 and not the CLI:** nothing else in this lab shells out to `aws` — Bedrock goes through boto3 — so the CLI is not guaranteed to be on the image. A missing binary fails *both* writes identically, which is exactly the symptom observed: a live lab with neither row present. boto3 is guaranteed; `check-image.sh` asserts `import boto3`. `env -u` rather than `AWS_PROFILE=` because the image exports `AWS_PROFILE=BedrockProfile` and botocore does not reliably treat an empty-string profile as unset.

**A diagnostic trap worth naming:** the 502 body is `Internal Server Error`, and Firefox's JSON viewer renders that on a dark background. Read as "the tab is black," it looks like the *login* page, which is genuinely `background-color:black` with a "Logging in..." spinner. Those two states are one keystroke apart in appearance and opposite in meaning — one is "no row was written," the other is "everything worked." Check the URL bar's `sandboxId` against the tables before theorising.

**A wrong turn, recorded:** `aws-bedrock-workshop` looked like the workstation's IAM principal and holds a Bedrock-only policy, so "the writes are being denied" was an attractive story. `iam get-access-key-last-used` disproved it — the key that had hit Bedrock that day belonged to `instruqt-api`, which has `AdministratorAccess`. Permissions were never involved. One read-only API call beat the inference.
