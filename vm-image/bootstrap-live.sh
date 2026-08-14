#!/bin/bash
#
# Install the tool half of the image into a RUNNING lab, so the track can be
# tested without baking first.
#
# Why this exists: `build-image.sh` does two different jobs — it lays down repo
# content, and it installs tools. Content is now refreshed at lab start by
# track_scripts/setup-workstation, so only the tools need an image. That means
# you can validate the whole track on an old image by running this once, and
# bake only after it works.
#
# Usage, in the workstation terminal of a running lab, as root:
#     curl -fsSL https://raw.githubusercontent.com/launchdarkly-labs/ld-instruqt-agentcontrol-mcp/main/vm-image/bootstrap-live.sh | bash
#   or paste the file.
#
# Idempotent: safe to re-run. Skips anything already present.
#
# NOT a substitute for baking. Every learner would pay this cost at lab start,
# which is minutes of npm and pip. Bake once this is proven.
#
set -uo pipefail

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
skip() { printf '    \033[33mskip\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32mok\033[0m   %s\n' "$*"; }
die()  { printf '\n\033[31mFAILED: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root (sudo -i)"

REPO_DIR=/opt/ld/ai-configs-intro
APP=$REPO_DIR/app

# Keep these in sync with build-image.sh. They are the reason a bake is needed
# at all, so a drift here is a drift in what you're testing.
CLAUDE_CODE_VERSION="2.1.232"
CLAUDE_BEDROCK_MODEL="us.anthropic.claude-sonnet-4-6"
CLAUDE_BEDROCK_SMALL_MODEL="us.anthropic.claude-haiku-4-5-20251001-v1:0"

# ---------------------------------------------------------------------------
say "Federation values (edit these before running, or export them first)"
# From the trust policy on RoleForAccessFromInstruqt. Not committed with real
# values because this repo is public — see vm-image/README.md.
BEDROCK_ROLE_ARN="${BEDROCK_ROLE_ARN:-}"
BEDROCK_JWT_AUDIENCE="${BEDROCK_JWT_AUDIENCE:-instruqt-agentcontrol}"
if [ -z "$BEDROCK_ROLE_ARN" ]; then
    printf '    \033[33mBEDROCK_ROLE_ARN is unset.\033[0m Bedrock will not work until you set it:\n'
    printf '      export BEDROCK_ROLE_ARN="arn:aws:iam::<account>:role/RoleForAccessFromInstruqt"\n'
    printf '    Continuing — everything else still installs.\n'
else
    ok "role $BEDROCK_ROLE_ARN"
fi

# ---------------------------------------------------------------------------
say "Node.js (needed by Claude Code)"
if command -v node >/dev/null 2>&1; then
    ok "node $(node --version) already present"
else
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_26.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list
    apt-get -qq update && apt-get -qq install -y nodejs || die "node install failed"
    ok "node $(node --version)"
fi

# ---------------------------------------------------------------------------
say "Claude Code ${CLAUDE_CODE_VERSION}"
if command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null | grep -q "$CLAUDE_CODE_VERSION"; then
    skip "already at ${CLAUDE_CODE_VERSION}"
else
    npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" >/dev/null 2>&1 \
      || die "npm install of claude-code failed"
    ok "$(claude --version)"
fi

# ---------------------------------------------------------------------------
say "AWS CLI v2 (the credential_process shells out to it)"
if command -v aws >/dev/null 2>&1; then
    ok "$(aws --version 2>&1 | cut -d' ' -f1) already present"
else
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
      || die "aws cli download failed"
    unzip -q -o /tmp/awscliv2.zip -d /tmp && /tmp/aws/install --update >/dev/null \
      || die "aws cli install failed"
    rm -rf /tmp/awscliv2.zip /tmp/aws
    ok "$(aws --version 2>&1 | cut -d' ' -f1)"
fi

# ---------------------------------------------------------------------------
say "Claude Code pre-seed (zero interactive prompts)"
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
    "${REPO_DIR}": {
      "hasTrustDialogAccepted": true,
      "hasCompletedProjectOnboarding": true,
      "enabledMcpjsonServers": ["LaunchDarkly"]
    },
    "${APP}": {
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
    "allow": ["mcp__LaunchDarkly__*", "Read", "Grep", "Glob", "Edit", "Write"],
    "deny": [
      "mcp__LaunchDarkly__create-project",
      "mcp__LaunchDarkly__delete-project",
      "mcp__LaunchDarkly__invite-members",
      "mcp__LaunchDarkly__find-members",
      "Read(${APP}/.env)",
      "Read(${REPO_DIR}/terraform/**)",
      "Read(${REPO_DIR}/instruqt-agentcontrol-mcp/**)"
    ]
  }
}
JSON
chmod 600 /root/.claude/settings.json
ok "wrote /root/.claude.json and /root/.claude/settings.json"

# If setup-workstation already ran, it put a real token in app/.env. Substitute
# it now so you don't have to restart the lab to get a working MCP connection.
if [ -f "$APP/.env" ]; then
    TOK=$(grep -m1 '^LD_API_TOKEN=' "$APP/.env" | cut -d= -f2-)
    if [ -n "${TOK:-}" ]; then
        TMP=$(mktemp)
        python3 -c "
import json,sys
d=json.load(open('/root/.claude.json'))
d['mcpServers']['LaunchDarkly']['headers']['Authorization']='Bearer '+sys.argv[1]
json.dump(d,open(sys.argv[2],'w'),indent=2)" "$TOK" "$TMP" && mv "$TMP" /root/.claude.json
        chmod 600 /root/.claude.json
        sed -e "s|__LD_API_TOKEN__|${TOK}|g" "$APP/.mcp.json.example" > "$APP/.mcp.json" 2>/dev/null || true
        chmod 600 "$APP/.mcp.json" 2>/dev/null || true
        ok "substituted the live lab token into the MCP config"
    else
        skip "no LD_API_TOKEN in app/.env yet — restart the lab or re-run track setup"
    fi
fi

# ---------------------------------------------------------------------------
say "Shell + code-server environment"
cat > /etc/profile.d/claude-code.sh <<SH
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=BedrockProfile
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL=${CLAUDE_BEDROCK_MODEL}
SH
chmod 644 /etc/profile.d/claude-code.sh
grep -q 'profile.d/claude-code.sh' /root/.bashrc || \
    echo '. /etc/profile.d/claude-code.sh' >> /root/.bashrc

CS=/root/.local/share/code-server/User/settings.json
if [ -f "$CS" ]; then
    cat > "$CS" <<JSON
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
    systemctl restart code-server 2>/dev/null || true
    ok "code-server settings written and service restarted"
else
    skip "code-server settings dir not found"
fi

# ---------------------------------------------------------------------------
say "Bedrock credential_process"
mkdir -p /opt/ld/bin /root/.aws
cat > /etc/bedrock-federation.env <<SH
export BEDROCK_ROLE_ARN="${BEDROCK_ROLE_ARN}"
export BEDROCK_JWT_AUDIENCE="${BEDROCK_JWT_AUDIENCE}"
SH
chmod 600 /etc/bedrock-federation.env

cat > /opt/ld/bin/bedrock-credential-process.sh <<'SH'
#!/bin/bash
set -euo pipefail
. /etc/bedrock-federation.env
: "${BEDROCK_ROLE_ARN:?BEDROCK_ROLE_ARN unset — see /etc/bedrock-federation.env}"
: "${BEDROCK_JWT_AUDIENCE:?BEDROCK_JWT_AUDIENCE unset}"
JWT="$(curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${BEDROCK_JWT_AUDIENCE}&format=full")"
aws sts assume-role-with-web-identity \
  --role-arn "$BEDROCK_ROLE_ARN" \
  --role-session-name "instruqt-$(hostname -s)" \
  --web-identity-token "$JWT" \
  --duration-seconds 3600 --region us-east-1 --output json \
| jq '{Version:1, AccessKeyId:.Credentials.AccessKeyId,
       SecretAccessKey:.Credentials.SecretAccessKey,
       SessionToken:.Credentials.SessionToken, Expiration:.Credentials.Expiration}'
SH
chmod 755 /opt/ld/bin/bedrock-credential-process.sh

cat > /root/.aws/config <<'INI'
[profile BedrockProfile]
region = us-east-1
credential_process = /opt/ld/bin/bedrock-credential-process.sh
INI
chmod 600 /root/.aws/config
ok "credential_process installed"

# ---------------------------------------------------------------------------
say "Smoke test"
if [ -n "$BEDROCK_ROLE_ARN" ]; then
    if aws sts get-caller-identity --profile BedrockProfile --region us-east-1 >/tmp/sts.json 2>/tmp/sts.err; then
        ok "STS: $(jq -r .Arn /tmp/sts.json)"
        if aws bedrock-runtime invoke-model --region us-east-1 --model-id "$CLAUDE_BEDROCK_MODEL" \
             --cli-binary-format raw-in-base64-out \
             --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":4,"messages":[{"role":"user","content":"hi"}]}' \
             /tmp/br.json >/dev/null 2>/tmp/br.err; then
            ok "Bedrock invoke succeeded for $CLAUDE_BEDROCK_MODEL"
        else
            printf '    \033[31mBedrock invoke FAILED\033[0m %s\n' "$(head -c 200 /tmp/br.err)"
        fi
    else
        printf '    \033[31mSTS exchange FAILED\033[0m %s\n' "$(head -c 200 /tmp/sts.err)"
        echo "    This VM's identity token sub (compare to accounts.google.com:sub in the trust policy):"
        T=$(curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${BEDROCK_JWT_AUDIENCE}&format=full" 2>/dev/null)
        [ -n "$T" ] && echo "      $(python3 -c "
import base64,json,sys
p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4)
print(json.loads(base64.urlsafe_b64decode(p)).get('sub','?'))" "$T" 2>/dev/null)" \
          || echo "      (no token — audience likely wrong)"
    fi
else
    skip "no role ARN, skipping the AWS smoke test"
fi

if [ -f "$APP/.mcp.json" ]; then
    TOK=$(python3 -c "
import json;print(json.load(open('$APP/.mcp.json'))['mcpServers']['LaunchDarkly']['headers']['Authorization'].removeprefix('Bearer '))" 2>/dev/null)
    if [ -n "${TOK:-}" ] && [ "$TOK" != "__LD_API_TOKEN__" ]; then
        if curl -fsS -X POST 'https://mcp.launchdarkly.com/mcp/launchdarkly' \
             -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
             -H 'Accept: application/json, text/event-stream' \
             -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' 2>/dev/null \
             | grep -q create-agentcontrol-config; then
            ok "LaunchDarkly MCP server reachable with the lab token"
        else
            printf '    \033[31mMCP tools/list FAILED\033[0m — check the token scope\n'
        fi
    fi
fi

say "Done"
cat <<EOF
    Next, in this terminal:
      claude          # confirm ZERO prompts, then /mcp shows LaunchDarkly connected
    Then work the four challenges from the assignment panel.

    Content edits do NOT need this script re-run — track setup refreshes the repo
    at lab start, so push to main and restart the lab. Re-run this only if the
    tool versions above change.
EOF
