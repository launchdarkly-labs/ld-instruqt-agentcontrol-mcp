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
    to it. You ask the agent for the variation and build the targeting rule yourself
    in the UI — the hosted MCP server cannot write a custom AI Config rule. The app
    doesn't change. It never learns there are two Ottos.
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

The agent creates the variation. It can't add a custom targeting rule on an AI Config — the hosted MCP server has no write for that — so you'll build this one yourself, which is no bad thing. A rule is a small pile of decisions, and the rule builder puts all of them in front of you at once.

Open the [LaunchDarkly](#tab-0) tab, go to **Agents → Configs → Otto Assistant**, and click the **Targeting** tab. Make sure the environment selector reads **Test**.

1. Above the **Default rule**, click **+** and select **Build a custom rule**.
2. Build the clause:
   1. **Context kind**: `user` — the app builds a user context, and a rule on any other kind matches nobody.
   2. **Attribute**: `tier` — type it exactly. `userTier` or `user_tier` produces a rule that matches nobody, and a rule that matches nobody looks exactly like a rule that's working.
   3. **Operator**: **is one of**
   4. **Values**: `premium`, then press **Enter**. The value isn't committed until you do.
3. In the variation dropdown at the end of the rule, select **Otto (Premium)**.
4. Leave the **Default rule** as **Otto (Born)** — free shoppers and anyone with no tier at all keep the Haiku Otto. If your new rule lands on the default instead, *everyone* goes to Sonnet, which works perfectly and quietly costs you money.
5. Click **Review and save**, then **Save changes**.

<!-- VERIFY: this click-path is copied from the live ld-agentcontrol-intro track, 05-otto-for-everyone, pulled with `instruqt track pull launchdarkly/ld-agentcontrol-intro` — same lesson, same rule, so the field labels and the two-step "Review and save" → "Save changes" confirm came from a track that ran. Two things to check: (a) the nav. Three spellings exist in the wild — that chapter says "AI → Configs", its own ch07 says "Configs", and this track says "Agents → Configs" in 02 and 05. Pick one and fix all three chapters together. (b) whether the variation dropdown shows display names ("Otto (Premium)") or keys; step 3 assumes names, and the docs call the control "Select...". -->

Then have the agent read it back — same object, other door:

```
Show me otto-assistant's targeting in the Test environment: every rule in order, what each one matches on, what it serves, and what the default rule serves.
```

Two things to confirm:

- There's a rule matching `tier` equals `premium`, serving `otto-premium`.
- The default rule still serves `otto-born`.

If the agent reports no rules at all, the save didn't take. Go back to the **Targeting** tab, check the environment selector was on **Test**, and make sure you clicked through both **Review and save** and **Save changes**.

# Watch it route

Open the [ToggleWear](#tab-1) tab. The header has a **Logged in as** dropdown, and it defaults to **Free user**.

1. With **Free user** selected, chat with Otto and ask:

```text
What's the difference between the Rocket Tee and the Feature Branch Crewneck?
```

That answer came from Haiku — the `otto-born` variation, same as it has all track.

2. Change the dropdown to **Premium user**, reset the chat, and ask the same question again.

This one came from Sonnet, because the context now carries `tier: "premium"` and the rule you just built matched it. Both Ottos run the same prompt, so he sounds like himself either way — what changed is the model underneath, not the personality.

Nothing was redeployed. Nothing was restarted. The app made the same call both times and LaunchDarkly answered it differently.

<!-- VERIFY: the reference tracks (ld-agentcontrol-build and ld-agentcontrol-intro, 05-otto-for-everyone) give their premium variation a richer premium prompt, so the two answers read visibly differently. This track deliberately keeps both prompts identical so the chapter is about routing rather than voice — which means the Haiku and Sonnet answers may look nearly the same to a learner. Confirm on a live run whether the difference is perceptible. If it isn't, the honest options are giving otto-premium a slightly richer prompt, or leaning on the agent read-back above as the proof and softening this section's claim. -->

# One step further

You targeted an attribute the app happened to send. In production you'd more often match a **segment** — "is in the Enterprise Accounts list" — a reusable cohort maintained once and referenced by many flags and Configs. Same mechanism, better fit when the cohort is a business fact rather than a request attribute.

A rule can also serve a *split* rather than a single variation, which is how you'd try a model on a fraction of premium users. You'll do exactly that in the last chapter, with a guardrail attached.

Click **Check** when premium traffic is routing to `otto-premium`.

<!-- VERIFY: confirm the tier switcher in the ToggleWear header is visible and functional in the baked image, and that its two options are still labelled "Free user" and "Premium user". The prose names those labels exactly. -->
