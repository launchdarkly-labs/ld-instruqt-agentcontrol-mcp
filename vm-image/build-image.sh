#!/bin/bash
#
# Instruqt VM image build script — `ai-configs-intro`.
#
# Workflow:
#   1. In the Instruqt web console, start a fresh Ubuntu LTS base image.
#   2. Edit REPO_URL / REPO_REF below to point at the desired commit of this repo.
#   3. Paste this entire script into the terminal as root (or run with sudo).
#   4. When the script finishes, save the running VM as a new image from the console.
#
# Idempotent enough to run twice: re-running picks up the latest commit but does
# not touch services that are already enabled.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Edit these before pasting:
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/launchdarkly-labs/ld-instruqt-agentcontrol-mcp.git"
REPO_REF="main"
TERRAFORM_VERSION="1.15.2"
NODE_VERSION="26.x"
# Pin Claude Code. An unpinned install bakes whatever shipped that day, and
# recent releases have changed both the Bedrock default model and how project
# MCP servers are approved. Bump deliberately, then re-run the smoke test.
CLAUDE_CODE_VERSION="2.1.232"
# Bedrock models Claude Code runs on. Both must be enabled in the workshop AWS
# account AND allowed by the IAM policy in gcp-federation/.
#
# Sonnet for the primary: the track's prompts ask for five chained tool calls
# with fiddly arguments against a ~150-tool surface, and a miss lands on the
# learner as a failed check. Haiku may well be enough — measure it in Phase 0
# and downgrade with evidence, not before. Do NOT leave this unset: Claude
# Code's Bedrock default is Opus 5, which is not in the IAM allowlist.
CLAUDE_BEDROCK_MODEL="us.anthropic.claude-sonnet-4-6"
CLAUDE_BEDROCK_SMALL_MODEL="us.anthropic.claude-haiku-4-5-20251001-v1:0"
# ---------------------------------------------------------------------------

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive

say "Updating apt"
apt-get -y update

say "Installing apt packages (system tools + python3)"
# Ubuntu 24.04 (noble) ships python3.12 as the system python — both ldai and
# launchdarkly-server-sdk require >=3.10, so the system python is fine.
apt-get -y install \
    software-properties-common \
    unzip jq git curl wget gnupg ca-certificates lsb-release vim \
    build-essential \
    python3 python3-venv python3-dev python3-pip

say "Installing Node.js ${NODE_VERSION} (via NodeSource)"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION} nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt -y update
apt install -y nodejs
npm install -g npm@latest

say "Installing Claude Code ${CLAUDE_CODE_VERSION} (pinned)"
# npm global rather than the native installer: NodeSource's prefix is under
# /usr, so the binary is on PATH for login shells, non-login shells, and
# code-server's integrated terminal alike. The native installer lands in
# /root/.local/bin, which only login shells see.
npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"
claude --version

say "Installing the AWS CLI v2"
# Required by the credential_process below (it calls `aws sts
# assume-role-with-web-identity`) and by the Bedrock reachability check in
# the operator smoke test. Not on the Ubuntu base image.
AWS_ARCH="$(uname -m)"
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip
unzip -q -o /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws
aws --version

say "Installing terraform ${TERRAFORM_VERSION} (direct binary; HashiCorp's apt repo has gaps on noble)"
TF_ARCH="$(dpkg --print-architecture)"
TF_ZIP="terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TF_ZIP}" -o "/tmp/${TF_ZIP}"
unzip -o "/tmp/${TF_ZIP}" -d /usr/local/bin
chmod +x /usr/local/bin/terraform
rm "/tmp/${TF_ZIP}"
terraform version

say "Cloning app source from ${REPO_URL}@${REPO_REF}"
mkdir -p /opt/ld
rm -rf /opt/ld/ai-configs-intro
git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /opt/ld/ai-configs-intro

say "Stripping authoring docs from the clone"
# These describe how the labs are built and effectively spoil them. Claude Code
# auto-loads CLAUDE.md from the repo root into every learner session, and a
# permissions denylist is the wrong tool — it only blocks the Read tool, leaves
# the files on disk, and fails open if a key name changes. Delete them instead.
# The track dir and terraform stay: setup/solve scripts need them.
rm -f /opt/ld/ai-configs-intro/CLAUDE.md \
      /opt/ld/ai-configs-intro/DECISIONS.md \
      /opt/ld/ai-configs-intro/PHASES.md \
      /opt/ld/ai-configs-intro/NARRATIVE.md \
      /opt/ld/ai-configs-intro/OPERATOR-CHECKLIST-mcp.md

say "Building Python venv for the ToggleWear app ($(python3 --version))"
APP_DIR=/opt/ld/ai-configs-intro/app
python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/pip" install --upgrade pip
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

say "Seeding .env from .env.example (real values are sed'd in at lab start)"
if [ ! -f "${APP_DIR}/.env" ]; then
    cp "${APP_DIR}/.env.example" "${APP_DIR}/.env"
fi

say "Linking /opt/ld/terraform-ld-student -> the student-bootstrap module"
# Every track script cd's to /opt/ld/terraform-ld-student. Nothing in the repo
# created that path, so it had to be a hand-made symlink on the old image.
# Make it explicit here so a fresh bake is self-sufficient.
ln -sfn /opt/ld/ai-configs-intro/terraform/student-bootstrap /opt/ld/terraform-ld-student

say "Pre-initializing student-bootstrap terraform module"
cd /opt/ld/ai-configs-intro/terraform/student-bootstrap
terraform init

say "Pre-initializing per-challenge terraform modules"
for ch in challenge-01 challenge-02 challenge-03; do
    (cd "/opt/ld/ai-configs-intro/terraform/${ch}" && terraform init -input=false)
done

say "Pre-seeding Claude Code so the learner's first run has no prompts"
# Two files, two jobs:
#   ~/.claude.json          state: onboarding done, workspace trusted, and the
#                           LaunchDarkly MCP server registered at USER scope.
#   ~/.claude/settings.json settings: Bedrock env, permissions.
#
# The MCP server is registered at user scope on purpose. A project .mcp.json
# approved only by the repo's own .claude/settings.json stays pending approval
# in an untrusted folder; a user-scope server needs no approval anywhere.
# app/.mcp.json is still written at lab start, as the visible teaching artifact.
#
# Trust is keyed on the git repository root, so seed both the repo root and the
# app dir that code-server opens.
mkdir -p /root/.claude
cat > /root/.claude.json <<JSON
{
  "hasCompletedOnboarding": true,
  "lastOnboardingVersion": "${CLAUDE_CODE_VERSION}",
  "installMethod": "npm-global",
  "autoUpdates": false,
  "mcpServers": {
    "LaunchDarkly": {
      "type": "http",
      "url": "https://mcp.launchdarkly.com/mcp/launchdarkly",
      "headers": { "Authorization": "Bearer __LD_API_TOKEN__" }
    }
  },
  "projects": {
    "/opt/ld/ai-configs-intro": {
      "hasTrustDialogAccepted": true,
      "hasCompletedProjectOnboarding": true,
      "enabledMcpjsonServers": ["LaunchDarkly"]
    },
    "/opt/ld/ai-configs-intro/app": {
      "hasTrustDialogAccepted": true,
      "hasCompletedProjectOnboarding": true,
      "enabledMcpjsonServers": ["LaunchDarkly"]
    }
  }
}
JSON
chmod 600 /root/.claude.json

cat > /root/.claude/settings.json <<JSON
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_PROFILE": "BedrockProfile",
    "AWS_REGION": "us-east-1",
    "ANTHROPIC_MODEL": "${CLAUDE_BEDROCK_MODEL}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${CLAUDE_BEDROCK_SMALL_MODEL}",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_UPDATES": "1",
    "MAX_MCP_OUTPUT_TOKENS": "16000"
  },
  "enableAllProjectMcpServers": true,
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "mcp__LaunchDarkly__*",
      "Read",
      "Grep",
      "Glob",
      "Edit",
      "Write"
    ],
    "deny": [
      "mcp__LaunchDarkly__create-project",
      "mcp__LaunchDarkly__delete-project",
      "mcp__LaunchDarkly__invite-members",
      "mcp__LaunchDarkly__find-members",
      "Read(/opt/ld/ai-configs-intro/app/.env)",
      "Read(/opt/ld/ai-configs-intro/terraform/**)",
      "Read(/opt/ld/ai-configs-intro/instruqt-agentcontrol-mcp/**)"
    ]
  }
}
JSON
chmod 600 /root/.claude/settings.json

say "Installing the federated Bedrock credential_process"
# Nothing previously wrote ~/.aws at all, and the federated STS session the repo
# documents lasts an hour — so a credential baked at image time is dead long
# before a lab runs. Resolve on demand instead: exchange the GCE instance
# identity token for an STS session when boto3, the AWS CLI, or Claude Code asks
# for credentials. One mechanism, three consumers, no expiry mid-lab.
#
# BEDROCK_ROLE_ARN and BEDROCK_JWT_AUDIENCE come from gcp-federation/ outputs and
# must be filled in before baking. The audience must match accounts.google.com:oaud
# in the role's trust policy.
mkdir -p /opt/ld/bin /root/.aws
cat > /etc/bedrock-federation.env <<'SH'
# Fill these in from `terraform output` in gcp-federation/ before baking.
export BEDROCK_ROLE_ARN=""
export BEDROCK_JWT_AUDIENCE=""
SH
chmod 600 /etc/bedrock-federation.env

cat > /opt/ld/bin/bedrock-credential-process.sh <<'SH'
#!/bin/bash
# Emits AWS credential_process JSON. No secret is stored on disk.
set -euo pipefail
. /etc/bedrock-federation.env
: "${BEDROCK_ROLE_ARN:?BEDROCK_ROLE_ARN unset — see /etc/bedrock-federation.env}"
: "${BEDROCK_JWT_AUDIENCE:?BEDROCK_JWT_AUDIENCE unset — see /etc/bedrock-federation.env}"

# --max-time is not optional: Claude Code aborts the whole credential chain
# after 60s, and a hung metadata call looks like a broken model, not a broken
# credential.
JWT="$(curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${BEDROCK_JWT_AUDIENCE}&format=full")"

aws sts assume-role-with-web-identity \
  --role-arn "$BEDROCK_ROLE_ARN" \
  --role-session-name "instruqt-$(hostname -s)" \
  --web-identity-token "$JWT" \
  --duration-seconds 3600 \
  --region us-east-1 \
  --output json \
| jq '{Version: 1,
       AccessKeyId: .Credentials.AccessKeyId,
       SecretAccessKey: .Credentials.SecretAccessKey,
       SessionToken: .Credentials.SessionToken,
       Expiration: .Credentials.Expiration}'
SH
chmod 755 /opt/ld/bin/bedrock-credential-process.sh

cat > /root/.aws/config <<'INI'
[profile BedrockProfile]
region = us-east-1
credential_process = /opt/ld/bin/bedrock-credential-process.sh
INI
chmod 600 /root/.aws/config

say "Exporting the Bedrock env for plain shells too"
# settings.json above is what Claude Code itself reads. These copies exist so
# the aws CLI, check-workstation scripts, and an operator's ssh session agree
# with it. /etc/profile.d is login-shell only, hence the .bashrc source.
cat > /etc/profile.d/claude-code.sh <<SH
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=BedrockProfile
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL=${CLAUDE_BEDROCK_MODEL}
SH
chmod 644 /etc/profile.d/claude-code.sh
grep -q 'profile.d/claude-code.sh' /root/.bashrc || \
    echo '. /etc/profile.d/claude-code.sh' >> /root/.bashrc

say "Installing togglewear.service (FastAPI on :3000)"
cat <<'UNIT' > /etc/systemd/system/togglewear.service
[Unit]
Description=ToggleWear (FastAPI)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
WorkingDirectory=/opt/ld/ai-configs-intro/app
EnvironmentFile=/opt/ld/ai-configs-intro/app/.env
ExecStart=/opt/ld/ai-configs-intro/app/.venv/bin/uvicorn server:app --host 0.0.0.0 --port 3000 --reload --reload-dir /opt/ld/ai-configs-intro/app

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable togglewear

say "Installing Evaluator Tracker service"
cat <<'UNIT' > /etc/systemd/system/evaluatortracker.service
[Unit]
Description=Evaluator Tracker
After=togglewear.service
Wants=togglewear.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=root
WorkingDirectory=/opt/ld/ai-configs-intro/traffic-generator
ExecStart=/opt/ld/ai-configs-intro/app/.venv/bin/python3 /opt/ld/ai-configs-intro/traffic-generator/realchat_traffic.py

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable evaluatortracker

say "Installing code-server (:8080)"
mkdir -p /root/.local/share/code-server/User
cat > /root/.local/share/code-server/User/settings.json <<JSON
{
    "workbench.colorTheme": "Default Dark+",
    "workbench.startupEditor": "none",
    "security.workspace.trust.enabled": false,
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.sendKeybindingsToShell": true,
    "terminal.integrated.env.linux": {
        "CLAUDE_CODE_USE_BEDROCK": "1",
        "AWS_PROFILE": "BedrockProfile",
        "AWS_REGION": "us-east-1",
        "ANTHROPIC_MODEL": "${CLAUDE_BEDROCK_MODEL}"
    }
}
JSON
# sendKeybindingsToShell matters: without it xterm.js swallows Escape and
# Shift+Enter, which the Claude Code TUI needs for cancel and newline.
curl -fsSL https://code-server.dev/install.sh | sh

cat <<'UNIT' > /etc/systemd/system/code-server.service
[Unit]
Description=Code Server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStart=/usr/bin/code-server --host 0.0.0.0 --port 8080 --auth none /opt/ld/ai-configs-intro/app

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable code-server

say "Cleaning up apt caches"
apt-get -y autoremove
apt-get -y clean

say "Done. Save this VM as your image from the Instruqt console."
say "Verify before saving:"
say "  systemctl is-enabled togglewear code-server"
say "  claude --version                      # must print ${CLAUDE_CODE_VERSION}"
say "  jq -e .hasCompletedOnboarding /root/.claude.json"
say "  aws sts get-caller-identity --profile BedrockProfile   # see README: this is the known-fragile step"
say ""
say "Then launch 'claude' once interactively and confirm ZERO prompts (no theme,"
say "no trust, no MCP approval). If a prompt appears, diff /root/.claude.json"
say "afterwards to find the key that was missing and add it above."
say "Finally, 'rm -rf /root/.claude/projects' so learners don't inherit your"
say "session history, and only then save the image."
