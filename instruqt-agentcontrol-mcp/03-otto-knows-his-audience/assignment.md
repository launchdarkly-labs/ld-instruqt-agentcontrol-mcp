---
slug: otto-knows-his-audience
id: j1zmpwqg927i
type: challenge
title: Otto Knows His Audience
teaser: Put premium shoppers on a stronger model and leave everyone else where they
  are — one targeting rule, no deploy.
notes:
- type: text
  contents: Not every customer is worth the same amount of inference. In this challenge
    you'll give Otto a second variation on a bigger model and route only premium
    shoppers to it, using the same targeting rules you'd use on any LaunchDarkly
    flag. The app doesn't change. It never learns there are two Ottos.
tabs:
- id: bqts141cvpml
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: kgcvo84rh0mh
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 8gbkebqxgzfb
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

# Ask for the rule

In your `claude` session:

```
In my LaunchDarkly project, add a second variation to the otto-assistant AI Config.

Key it otto-premium, name it "Otto (Premium)", and back it with the Bedrock model anthropic.claude-sonnet-4-5-20250929-v1:0. Give it exactly the same system message as the otto-born variation — copy it across unchanged.

Then, in the Test environment, add a targeting rule to otto-assistant: when the user context's tier attribute is "premium", serve otto-premium. Leave the default rule serving otto-born so everyone else is unaffected.
```

Then read it back:

```
Show me otto-assistant's targeting in Test: every rule in order, what each one matches on, what it serves, and what the default rule serves.
```

Three things to confirm, and the third is the one that bites:

- There's a rule matching `tier` equals `premium`, serving `otto-premium`.
- The default rule still serves `otto-born`. A rule that accidentally replaces the fallthrough sends *everyone* to Sonnet, which works perfectly and quietly costs you money.
- The attribute is `tier`, not `userTier` or `user_tier`. The app sets `tier`. An agent guessing a plausible-looking variant produces a rule that matches nobody, and a rule that matches nobody looks exactly like a rule that's working.

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
