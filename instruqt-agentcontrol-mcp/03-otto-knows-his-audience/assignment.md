---
slug: otto-knows-his-audience
id: icpxesnpl5mi
type: challenge
title: Otto Knows His Audience
teaser: Put premium shoppers on a stronger model and leave everyone else where they
  are — one targeting rule, no deploy.
notes:
- type: text
  contents: Not every customer is worth the same amount of inference. In this challenge
    you'll give Otto a second variation on a bigger model and route only premium shoppers
    to it. The variation is asked for; the targeting rule is a REST paste — the hosted
    MCP server cannot write a custom AI Config rule. The app doesn't change.
tabs:
- id: lncmuarxyqdc
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: ezi7hdhuavtv
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: mxzfcbjihqqg
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 360
enhanced_loading: null
---

# One Otto is not enough

Otto runs on Haiku — fast, cheap, fine for "do the socks come in large."

It's less obviously fine for a customer with a full cart and a complicated question about international returns. Those are the customers you'd happily spend more inference on, and right now they get the same model as everyone else.

The instinct is to branch in code: check the tier, pick a model. Don't. That puts a pricing decision inside a deploy cycle, and the person who wants to change it isn't the person who can ship it.

The app already tells LaunchDarkly who's asking — every request builds a context with a `tier` attribute:

```python
context = Context.builder(req.session_id).set("tier", req.user_tier).build()
```

That's all the app will ever need to know about this. Everything else happens in LaunchDarkly.

# What you're building

| Thing | Value |
|---|---|
| New variation key | `otto-premium` |
| Model | `anthropic.claude-sonnet-4-5-20250929-v1:0` on Bedrock |
| Rule | `tier` is `premium` → serve `otto-premium` |
| Everyone else | Falls through to `otto-born`, unchanged |

Otto's *personality* stays identical — same system prompt, same catalog, same voice. Only the model underneath changes. That's deliberate: it keeps this chapter about routing, and it means the judge in the next chapter is comparing models rather than prompts.

# Ask for the variation

In your `claude` session:

```
In my LaunchDarkly project, add a second variation to the otto-assistant AI Config.

Key it otto-premium, name it "Otto (Premium)", and back it with the Bedrock model anthropic.claude-sonnet-4-5-20250929-v1:0. Give it exactly the same system message as the otto-born variation — copy it across unchanged.
```

# Add the rule

The agent can create the variation. It cannot add a custom targeting rule on an AI Config — the hosted MCP server has no write for that. The same semantic patch the UI would send works over REST. Paste this in a terminal in the [Code Editor](#tab-2):

```bash
set -a && . /opt/ld/ai-configs-intro/app/.env && set +a

PREMIUM_ID=$(curl -sS \
  "https://app.launchdarkly.com/api/v2/projects/${LD_PROJECT_KEY}/ai-configs/otto-assistant" \
  -H "Authorization: ${LD_API_TOKEN}" \
  -H "LD-API-Version: beta" \
  | jq -r '.variations[] | select(.key=="otto-premium") | ._id')

curl -sS -X PATCH \
  "https://app.launchdarkly.com/api/v2/projects/${LD_PROJECT_KEY}/ai-configs/otto-assistant/targeting" \
  -H "Authorization: ${LD_API_TOKEN}" \
  -H "LD-API-Version: beta" \
  -H "Content-Type: application/json; domain-model=launchdarkly.semanticpatch" \
  --data-raw "{
    \"environmentKey\": \"test\",
    \"instructions\": [{
      \"kind\": \"addRule\",
      \"variationId\": \"${PREMIUM_ID}\",
      \"clauses\": [{
        \"contextKind\": \"user\",
        \"attribute\": \"tier\",
        \"op\": \"in\",
        \"values\": [\"premium\"],
        \"negate\": false
      }]
    }]
  }"
```

That adds a Test rule: `tier` is `premium` → `otto-premium`. The default rule is left alone, so everyone else still gets `otto-born`. If `PREMIUM_ID` prints empty, the variation from the previous step isn't there yet.

Then have the agent read it back:

```
Show me otto-assistant's targeting in the Test environment: every rule in order, what each one matches on, what it serves, and what the default rule serves.
```

Two things to confirm:

- There's a rule matching `tier` equals `premium`, serving `otto-premium`.
- The default rule still serves `otto-born`. A rule that accidentally replaces the fallthrough sends *everyone* to Sonnet, which works perfectly and quietly costs you money.

# Watch it route

This is the part worth actually doing, because a targeting rule you haven't seen fire is a hypothesis.

Open a terminal in the [Code Editor](#tab-2) and tail the app's log:

```bash
journalctl -u togglewear -f | grep 'chat session='
```

Now open the [ToggleWear](#tab-1) tab. Top right, there's a **Logged in as** switcher set to **Free user**. Ask Otto something:

```text
Do the Toggle Socks come in large?
```

The log line shows `tier=free` and a `model=` ending in `haiku`.

Switch the dropdown to **Premium user** and ask again. Same question, same app, same code path — and now `tier=premium` with a `model=` ending in `sonnet`.

Nothing was redeployed. Nothing was restarted. The app made the same call both times and LaunchDarkly answered it differently.

# One step further

You targeted an attribute the app happened to send. In production you'd more often match a **segment** — "is in the Enterprise Accounts list" — a reusable cohort maintained once and referenced by many flags and Configs. Same mechanism, better fit when the cohort is a business fact rather than a request attribute.

A rule can also serve a *split* rather than a single variation, which is how you'd try a model on a fraction of premium users. You'll do exactly that in the last chapter, with a guardrail attached.

Click **Check** when premium traffic is routing to `otto-premium`.

<!-- VERIFY: confirm the tier switcher in the ToggleWear header is visible and functional in the baked image, and that its two options are still labelled "Free user" and "Premium user". The prose names those labels exactly. -->
