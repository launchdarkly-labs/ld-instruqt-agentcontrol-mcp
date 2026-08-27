#!/bin/bash
#
# Post-bake verification. Paste into the bake VM as root AFTER build-image.sh,
# BEFORE saving the image.
#
# Read-only except for one Bedrock invoke (a few tokens). Every check names the
# thing to fix rather than just failing, because a bad image doesn't announce
# itself — it strands a learner in challenge 00 with no way forward.
#
# Exit 0 = safe to save. Exit 1 = fix and re-run.
#
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n       -> %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n       -> %s\n' "$1" "$2"; WARN=$((WARN+1)); }
head2(){ printf '\n\033[1;36m== %s\033[0m\n' "$1"; }

REPO=/opt/ld/ai-configs-intro
APP=$REPO/app

head2 "Repo and app source"
[ -d "$REPO/.git" ] && ok "repo cloned at $REPO" \
  || bad "repo missing at $REPO" "build-image.sh's clone step failed; check REPO_URL is reachable and public"
[ -f "$APP/server.py" ] && ok "app/server.py present" || bad "app/server.py missing" "wrong REPO_REF?"
[ -f "$APP/.mcp.json.example" ] && ok "app/.mcp.json.example present (setup renders this)" \
  || bad "app/.mcp.json.example missing" "setup-workstation will abort on the sed; you baked an old commit"
for d in challenge-01 challenge-02 challenge-03 challenge-04 student-bootstrap; do
  [ -d "$REPO/terraform/$d" ] && ok "terraform/$d present" || bad "terraform/$d missing" "wrong REPO_REF"
done
[ -f "$APP/static/review.html" ] && ok "staff review page present" \
  || bad "app/static/review.html missing" "challenge 03's fourth tab will 404"

head2 "Authoring docs stripped (they spoil the labs)"
LEAK=0
for f in CLAUDE.md DECISIONS.md PHASES.md NARRATIVE.md OPERATOR-CHECKLIST-mcp.md; do
  [ -e "$REPO/$f" ] && { bad "$f still on disk" "build-image.sh should have deleted it"; LEAK=1; }
done
[ "$LEAK" = 0 ] && ok "authoring docs removed from the clone"

head2 "Symlink the track scripts depend on"
[ -d /opt/ld/terraform-ld-student ] && ok "/opt/ld/terraform-ld-student resolves" \
  || bad "/opt/ld/terraform-ld-student missing" "every track script cd's here; the ln -sfn step failed"

head2 "Services"
for s in togglewear code-server evaluatortracker; do
  systemctl is-enabled "$s" >/dev/null 2>&1 && ok "$s enabled" || bad "$s not enabled" "unit not installed"
done

head2 "Python venv"
[ -x "$APP/.venv/bin/python3" ] && ok "venv built" || bad "venv missing" "pip install step failed"
"$APP/.venv/bin/python3" -c 'import ldai, ldclient, boto3, fastapi' 2>/dev/null \
  && ok "ldai, ldclient, boto3, fastapi importable" \
  || bad "an SDK import failed" "check app/requirements.txt installed cleanly"
"$APP/.venv/bin/python3" -c "import ast,pathlib; ast.parse(pathlib.Path('$APP/server.py').read_text())" 2>/dev/null \
  && ok "server.py parses" || bad "server.py does not parse" "bad commit baked"
grep -q 'Challenge 02 judge: replace this body' "$APP/server.py" \
  && ok "score_response stub intact (challenge 02 patches this)" \
  || bad "score_response stub marker missing" "challenge 02's patch-server.py will refuse to run"
grep -q 'Challenge 03 review gate: replace this body' "$APP/server.py" \
  && ok "gate_response stub intact (challenge 03 patches this)" \
  || bad "gate_response stub marker missing" "challenge 03's patch-server.py will refuse to run"

head2 "Claude Code"
command -v claude >/dev/null 2>&1 && ok "claude on PATH ($(command -v claude))" \
  || bad "claude not on PATH" "npm global install failed, or PATH differs for non-login shells"
if command -v claude >/dev/null 2>&1; then
  V=$(claude --version 2>/dev/null | head -1)
  PINNED=$(grep -m1 '^CLAUDE_CODE_VERSION=' "$REPO/vm-image/build-image.sh" 2>/dev/null | cut -d'"' -f2)
  case "$V" in
    *"$PINNED"*) ok "version matches the pin ($PINNED)" ;;
    *) warn "claude reports '$V', pin is '$PINNED'" "unpinned install or a drifted pin" ;;
  esac
fi
for f in /root/.claude.json /root/.claude/settings.json; do
  if [ -f "$f" ]; then
    python3 -c "import json;json.load(open('$f'))" 2>/dev/null \
      && ok "$f is valid JSON" \
      || bad "$f is malformed JSON" "a malformed ~/.claude.json breaks Claude Code entirely"
  else
    bad "$f missing" "pre-seed step failed; the learner will hit interactive prompts"
  fi
done
python3 -c "
import json,sys
d=json.load(open('/root/.claude.json'))
sys.exit(0 if d.get('hasCompletedOnboarding') else 1)" 2>/dev/null \
  && ok "onboarding marked complete" \
  || bad "hasCompletedOnboarding not set" "learner sees the first-run wizard"
python3 -c "
import json,sys
d=json.load(open('/root/.claude.json'))
p=d.get('projects',{})
sys.exit(0 if all(p.get(k,{}).get('hasTrustDialogAccepted') for k in
  ['/opt/ld/ai-configs-intro','/opt/ld/ai-configs-intro/app']) else 1)" 2>/dev/null \
  && ok "both workspace paths pre-trusted" \
  || bad "workspace trust not seeded for both paths" "learner hits the folder-trust dialog"
python3 -c "
import json,sys
d=json.load(open('/root/.claude.json'))
s=d.get('mcpServers',{}).get('LaunchDarkly',{})
sys.exit(0 if s.get('type')=='http' and 'mcp.launchdarkly.com' in s.get('url','') else 1)" 2>/dev/null \
  && ok "LaunchDarkly MCP server registered at user scope with type=http" \
  || bad "user-scope MCP server entry wrong" "a url without type is a hard config error; server is skipped"
if grep -q '__LD_API_TOKEN__' /root/.claude.json 2>/dev/null; then
  ok "MCP token is still the placeholder (setup-workstation substitutes it at lab start)"
else
  warn "no __LD_API_TOKEN__ placeholder in /root/.claude.json" \
       "if a real token is baked in, EVERY learner shares it — re-run the pre-seed step"
fi

head2 "Bedrock credentials"
# Credentials themselves are written at LAB START from the AWS_* Instruqt
# secrets, not baked. So at bake time we only check that nothing broken is
# baked in — specifically that no credential_process survives, since the GCP
# federation it used cannot work here (metadata.google.internal is unreachable
# from an Instruqt workstation).
if grep -q credential_process /root/.aws/config 2>/dev/null; then
  bad "/root/.aws/config still has a credential_process" \
      "the GCP federation cannot work on Instruqt; track setup writes static keys instead"
else
  ok "no stale credential_process baked in (credentials arrive at lab start)"
fi
[ -d /root/.aws ] && ok "/root/.aws exists for lab-start credentials" \
  || bad "/root/.aws missing" "build-image.sh should mkdir it"
command -v aws >/dev/null 2>&1 && ok "aws CLI present ($(aws --version 2>&1 | cut -d' ' -f1))" \
  || bad "aws CLI missing" "the checks and smoke tests shell out to it"

echo
if [ ! -f /root/.aws/credentials ]; then
  warn "no BedrockProfile credentials on this image" \
       "EXPECTED at bake time — track setup writes them from the AWS_* Instruqt secrets. Verify Bedrock in a live lab, not here."
elif aws sts get-caller-identity --profile BedrockProfile --region us-east-1 >/tmp/sts.json 2>/tmp/sts.err; then
  ok "STS exchange works: $(python3 -c 'import json;print(json.load(open("/tmp/sts.json"))["Arn"])' 2>/dev/null)"
  MODEL=$(grep -m1 '^CLAUDE_BEDROCK_MODEL=' "$REPO/vm-image/build-image.sh" 2>/dev/null | cut -d'"' -f2)
  if aws bedrock-runtime invoke-model --region us-east-1 --model-id "$MODEL" \
       --cli-binary-format raw-in-base64-out \
       --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":4,"messages":[{"role":"user","content":"hi"}]}' \
       /tmp/br.json >/dev/null 2>/tmp/br.err; then
    ok "Bedrock invoke succeeded for $MODEL"
  else
    bad "Bedrock invoke failed for $MODEL" "$(head -c 200 /tmp/br.err)"
  fi
else
  bad "BedrockProfile credentials are present but rejected" "$(head -c 200 /tmp/sts.err)"
fi

head2 "Shell environment"
for v in CLAUDE_CODE_USE_BEDROCK AWS_PROFILE AWS_REGION; do
  grep -q "$v" /etc/profile.d/claude-code.sh 2>/dev/null && ok "$v exported in /etc/profile.d" \
    || bad "$v not in /etc/profile.d/claude-code.sh" "check scripts and ssh shells won't see it"
done
grep -q 'sendKeybindingsToShell' /root/.local/share/code-server/User/settings.json 2>/dev/null \
  && ok "code-server passes keybindings to the shell (Escape/Shift+Enter in the TUI)" \
  || bad "sendKeybindingsToShell not set" "xterm.js will swallow keys the Claude Code TUI needs"

head2 "Left to do by hand — cannot be scripted"
cat <<'EOF'
  1. Run `claude` interactively once. Confirm ZERO prompts: no theme picker, no
     folder-trust dialog, no MCP approval. If one appears, exit and diff
     /root/.claude.json against what build-image.sh wrote, then add the missing
     key to the heredoc. This is the most likely silent failure in the track.
  2. Inside claude, run /mcp. LaunchDarkly must read as connected, not pending.
     (It will fail auth here — the token placeholder is substituted at lab
     start. You are checking registration, not connectivity.)
  3. rm -rf /root/.claude/projects   # don't ship your session transcripts
EOF

printf '\n\033[1m%s\033[0m\n' "$PASS passed, $FAIL failed, $WARN warnings"
if [ "$FAIL" -gt 0 ]; then
  printf '\033[31mDo not save this image until the failures are fixed.\033[0m\n'; exit 1
fi
printf '\033[32mChecks passed. Do the three manual steps above, then save the image.\033[0m\n'
exit 0
