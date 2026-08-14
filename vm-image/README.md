# VM image — `agentcontrol-mcp`

This directory contains the inputs for the Instruqt VM image used by the `instruqt-agentcontrol-mcp` track. Images are built **manually through the Instruqt web console**, not by an external image pipeline. The `build-image.sh` script here is the artifact you paste into a fresh Ubuntu base to produce the image.

## How to build

1. **Spin up a base VM in the Instruqt console.** Ubuntu 24.04 LTS. The script uses whatever `python3` ships with the base, which must be ≥3.10.
2. **Open the terminal on that VM and become root** (`sudo -i`, or run `sudo bash` before pasting the script).
3. **Check `REPO_URL` and `REPO_REF` at the top of `build-image.sh`.** They point at `launchdarkly-labs/ld-instruqt-agentcontrol-mcp` on `main`. Pin `REPO_REF` to a specific commit SHA for a delivery you want reproducible — `main` moves.
4. **Paste the entire script.** It echoes progress at each step and `set -e`s on the first failure.
5. **Run the verification block** the script prints at the end (see below).
6. **Save the running VM as a new image**, named to match the `image:` field in `instruqt-agentcontrol-mcp/config.yml` (currently `launchdarkly/workshop-ai-configs`). Bump a trailing `-N` when re-baking so labs in flight don't get pulled out from under their learners.

## Verification before you save the image

Paste `check-image.sh` into the same VM after `build-image.sh` finishes. It runs ~30 assertions across the repo clone, the stripped authoring docs, services, the venv, the paste-block stubs, the Claude Code pre-seed, the Bedrock credential chain, and the shell environment — and each failure names the fix rather than just reporting red.

It exits non-zero if anything is wrong, so it's safe to treat as a gate. One expected warning: the STS exchange may fail *on the bake VM* if that VM runs under a different GCP service account than the sandbox does. The script prints the JWT's `sub` so you can compare it against `gcp_sub` in the trust policy, and the real test is in a live lab.

It finishes by printing **three manual steps that cannot be scripted:** launch `claude` once interactively and confirm there are **zero prompts** — no theme picker, no folder-trust dialog, no MCP approval. If any prompt appears, exit, diff `/root/.claude.json` against what the script wrote, and add the missing key to the heredoc in `build-image.sh`. A learner who hits a prompt in challenge 00 is stuck with no way forward.

The most important is launching `claude` once interactively to confirm there are zero prompts. Then `rm -rf /root/.claude/projects` so learners don't inherit your session transcripts, and only then save the image.

## What the script installs

| Component | Path | Notes |
|---|---|---|
| System tools | `apt` | `jq`, `git`, `curl`, `wget`, `vim`, `unzip`, `gnupg`, `ca-certificates`, `build-essential`, `lsb-release`, `software-properties-common` |
| Node.js | `apt` via NodeSource | Pinned in `NODE_VERSION`. Needed for Claude Code and code-server. |
| Claude Code | `npm install -g @anthropic-ai/claude-code@$CLAUDE_CODE_VERSION` | **Pinned deliberately.** npm global rather than the native installer: NodeSource's prefix is under `/usr`, so the binary is on PATH for login shells, non-login shells, and code-server's integrated terminal alike. The native installer lands in `/root/.local/bin`, which only login shells see. |
| System Python 3 + venv | `/usr/bin/python3` | Ubuntu 24.04's system python is 3.12; `ldai` and `launchdarkly-server-sdk` require ≥3.10. |
| Terraform | `/usr/local/bin/terraform` | Direct binary download, pinned in `TERRAFORM_VERSION`. HashiCorp's apt repo has gaps on noble. |
| App source | `/opt/ld/ai-configs-intro/` | `git clone --depth 1`. |
| Python venv | `/opt/ld/ai-configs-intro/app/.venv/` | `pip install -r app/requirements.txt`. Shared by the FastAPI server and the traffic generators. |
| Seeded `.env` | `/opt/ld/ai-configs-intro/app/.env` | From `.env.example`; real values `sed`'d in at lab start. |
| `terraform-ld-student` symlink | `/opt/ld/terraform-ld-student` | Points at `terraform/student-bootstrap/`. Every track script `cd`s here. Previously a hand-made symlink that no script created — now explicit. |
| Terraform init | `student-bootstrap/`, `challenge-{01,02,03}/` | Run at bake so lab start is fast. |
| Claude Code state | `/root/.claude.json` | Onboarding marked complete, both the repo root and `app/` marked trusted, and the LaunchDarkly MCP server registered at **user scope** with a `__LD_API_TOKEN__` placeholder. |
| Claude Code settings | `/root/.claude/settings.json` | Bedrock env vars, permission allow/deny lists. |
| Shell env | `/etc/profile.d/claude-code.sh` | Same Bedrock vars for plain shells and check scripts. Sourced from `/root/.bashrc` because `/etc/profile.d` is login-shell only. |
| `togglewear.service` | `/etc/systemd/system/` | uvicorn on :3000, `--reload` scoped to `app/`. |
| `evaluatortracker.service` | `/etc/systemd/system/` | Runs `traffic-generator/realchat_traffic.py` for the lab's duration, so judge scores have traffic to grade. |
| `code-server.service` | `/etc/systemd/system/` | Port 8080, `--auth none`, workspace `/opt/ld/ai-configs-intro/app`. Terminal env and `sendKeybindingsToShell` are set so the Claude Code TUI works in the browser. |

## Credentials

**Arrives at lab start** via Instruqt secrets and `track_scripts/setup-workstation`: the LD project (created by `terraform/student-bootstrap/`), the SDK and client keys, the scoped `LD_API_TOKEN`, the rendered `app/.mcp.json`, and that same token substituted into `/root/.claude.json` for the MCP server.

**Bedrock, baked:** `/root/.aws/config` defines `BedrockProfile` with a `credential_process` pointing at `/opt/ld/bin/bedrock-credential-process.sh`, which exchanges the GCE instance identity token for an STS session on demand. One mechanism serving boto3 (the app), the AWS CLI (check scripts), and Claude Code, with no credential stored on disk and no expiry mid-lab.

This replaced a real gap: nothing in this repo previously wrote `~/.aws` at all, while `app/server.py` has always asked for a profile named `BedrockProfile`, and the federated session `gcp-federation/` describes lasts an hour — so either undocumented long-lived IAM keys were being hand-written at bake, or Bedrock calls were failing.

**Two things you must do before baking:**

1. Fill in `/etc/bedrock-federation.env` with `BEDROCK_ROLE_ARN` (from `terraform output role_arn` in `gcp-federation/`) and `BEDROCK_JWT_AUDIENCE` (the `gcp_aud` value passed to that module). The credential process fails closed without them.
2. ~~Add `bedrock:ListInferenceProfiles` and `bedrock:GetInferenceProfile`~~ — **done 2026-08-14.** Applied to the live `RoleForAccessFromInstruqt` and reflected in `gcp-federation/aws-instruqt-role.tf`. Sonnet 4.6 was already in the resource list, so the model pin needed no change.

Note that `gcp-federation/` has **no Terraform state**, so the `.tf` is documentation of intent rather than something you can `apply` — the role predates it and a plain apply would collide. Changes go in via `aws iam put-role-policy` and get mirrored into the `.tf` by hand.

**Largely de-risked as of 2026-08-14.** The role exists and its `RoleLastUsed` was 2026-08-07 in `us-east-1`, so something has been completing this exchange successfully and recently — the Instruqt sandboxes do run under the pinned service account. The values you need:

```sh
export BEDROCK_ROLE_ARN="arn:aws:iam::<account>:role/RoleForAccessFromInstruqt"
export BEDROCK_JWT_AUDIENCE="instruqt-agentcontrol"
```

The audience is the `accounts.google.com:oaud` claim in the trust policy; the account id and pinned `sub` are in the live role (deliberately not committed here, since this repo is public). What remains unverified is only whether *our* bake produces a VM in that same pool — `check-image.sh` prints the decoded JWT's `sub` on failure so a mismatch is a one-line diagnosis.

## When to re-bake

- `app/requirements.txt` changes.
- A systemd unit changes.
- `CLAUDE_CODE_VERSION` or `CLAUDE_BEDROCK_MODEL` changes. Treat a Claude Code version bump as a change needing a full sandbox test, not a one-line edit — recent releases have changed both the Bedrock default model and how project MCP servers get approved.
- Any new apt tool.

**Source-of-truth note:** `setup-workstation` does *not* `git pull` at lab start, so any change to `instruqt-agentcontrol-mcp/` or `terraform/challenge-NN/` *also* requires a re-bake.

## Paths the per-challenge scripts assume exist post-bake

- `/opt/ld/ai-configs-intro/app/server.py` and `app/.venv/bin/python3`
- `/opt/ld/ai-configs-intro/app/.mcp.json.example` — the template `setup-workstation` renders
- `/opt/ld/ai-configs-intro/terraform/challenge-{01,02,03}/*.tf`
- `terraform/challenge-01/{patch-server.py,server-paste.py}` — challenge 01's solve
- `terraform/challenge-02/{patch-server.py,judge-server-paste.py}` — the judge block
- `terraform/challenge-03/{patch-server.py,review-server-paste.py}` — the review gate
- `/opt/ld/ai-configs-intro/traffic-generator/{realchat_traffic.py,generate_traffic.py,background_traffic.py,messages.txt}`
- `/var/log/togglewear-realchat.log` — writable by root

The three `patch-server.py` scripts chain: challenge 01's paste leaves a marker that challenge 02 injects below, and challenge 02's paste leaves the marker challenge 03 injects below. Changing a marker string means changing it in the paste file, the patch script, and the assignment together.
