---
slug: trust-but-verify
id: bof3dmko7nuj
type: challenge
title: Trust But Verify
teaser: Roll a risky new model out behind the judge you wrote, and let LaunchDarkly
  take it away again when the scores drop.
notes:
- type: text
  contents: A new model landed and someone wants Otto on it. You can't know whether
    it keeps him sounding like himself until real traffic hits it — and by then the
    damage is done. So don't decide. Ship it behind the brand-voice judge, give LaunchDarkly
    a threshold, and let the rollout revert itself if the scores fall. The judge you
    wrote in the last chapter is about to become a release gate.
tabs:
- id: cpjylmwnssyh
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: teld17ut9yvh
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 2homnxuspxnm
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: intermediate
timelimit: 600
enhanced_loading: null
---

# The question you can't answer in advance

Amazon Nova Pro is cheaper than the Haiku model Otto runs on, and someone in a meeting has noticed. The honest answer to "will it still sound like Otto?" is that nobody knows until customers are talking to it.

That's not a reason to refuse. It's a reason not to make the decision by hand.

You already have the instrument. `otto-brand-voice-score` is a real metric with real values in it. A guarded rollout points that metric at a release: send a slice of traffic to the new model, watch the score, roll back automatically if it regresses. Nobody has to be awake for it.

This chapter ships a model that is *going to fail*, on purpose, so you can watch the failure get handled. Its prompt is stiff, formal and corporate — the precise opposite of what your judge grades for. A real rollout is a coin flip; here you want a landslide, because a subtle regression needs more traffic than a lab has.

| Thing | Value |
|---|---|
| New variation key | `otto-stiff` |
| Model | Amazon Nova Pro — already in your project as `amazon.nova-pro-v1:0` |
| Control variation | `otto-born` |
| Metric to watch | `otto-brand-voice-score` |
| Rollback | Automatic, on regression |

The Nova Pro model config is already there — setup created it, because the app resolves Bedrock model IDs from that exact name and a near-miss just fails to answer. Everything else, you're about to ask for.

# Ask for the risky variation

The agent builds the variation and wires the judge to it. In your `claude` session:

```
In my LaunchDarkly project, add a new variation to the otto-assistant AI Config.

Key it otto-stiff, name it "Otto (Stiff)", and back it with the existing Nova Pro model config named amazon.nova-pro-v1:0.

Give it this system prompt:

You are a customer service representative for ToggleWear. Assist customers with their inquiries in a professional and formal manner. Always greet the customer formally, provide thorough and complete explanations, and conclude each response with a formal sign-off. Maintain a corporate tone at all times. Avoid contractions, humour, and informality.

Attach the otto-brand-voice-judge to this variation at 100% sampling, the same way otto-born has it.
```

The key matters for the same reason keys have mattered all track: `otto-stiff` is what the sabotage script below looks for. Read it back before moving on:

```
Show me the otto-stiff variation on otto-assistant: its model, its system prompt, and which judges are attached at what sampling rate.
```

# Start the guarded rollout

This part you click, and the reason is worth a sentence. The public API can put *weights* on a rollout — 10% here, 90% there — and that's all. Nothing in it attaches a metric, sets a monitoring window, or arms a rollback. The thing that makes a rollout *guarded* has no endpoint, so it has no MCP tool either. This is where the agent hands over.

Open the [LaunchDarkly](#tab-0) tab and go to **Agents → Configs → Otto Assistant → Targeting**. Confirm the environment picker says **Test**.

1. Click the **Default rule** — the fallthrough at the bottom of the targeting list. You should see **Start guarded rollout**.
2. **Test variation** is **Otto (Stiff)**; **Control variation** is **Otto (Born)**. Backwards ramps traffic *away* from the bad model and never regresses.
3. **Metric to watch**: **otto-brand-voice-score**. That's the one your judge has been filling since the judge chapter — point it at anything else and there's no data to regress on.
4. **Regression direction**: lower is worse. The metric's success criteria is HigherThanBaseline.
5. **Stages**: start at 10% and take whatever ramp the UI offers. Set each stage's monitoring window to the shortest length it accepts.
6. **On regression**: choose **Roll back**, not notify. Notify-only is a pager at 2am.
7. Click **Start**.

Short monitoring windows are a lab concession, and worth naming as one. A minute or two is far too short to trust in production — you'd want hours, and enough samples that a quiet Tuesday doesn't read as a regression. You're compressing the clock so the lesson fits in a lab.

<!-- VERIFY: this click-path is lifted from the UI-driven original at launchdarkly-labs/ld-workshop-ai-configs-intro, instruqt-evaluate/07-trust-but-verify, so the rollout dialog's fields ran in a real lab — but that track said "Configs → Otto Assistant" where this one says "Agents → Configs → Otto Assistant" (the wording 02 and 03 already use). Confirm the nav, and confirm the shortest monitoring window the dialog accepts; the original asked for 1-2 minutes without recording whether that was honoured. -->

<!-- VERIFY: if the sandbox sign-in is down there is no fallback — a guarded rollout cannot be started any other way, and solve-workstation produces only a plain percentage rollout. Decide with the operator whether that warrants a Skip instruction in the prose. -->

# Check its work

The rollout is a UI object, so read it back where you made it. On the **Targeting** tab you should see the default rule replaced by a running rollout at its first stage, 10% to Stiff.

The agent can confirm the shape of it, which is worth doing — it's the same targeting endpoint every other chapter has read:

```
Show me otto-assistant's default rule in the Test environment. Is it serving a single variation or a percentage rollout, and what are the weights?
```

Four things to confirm:

- Test arm is `otto-stiff`, control is `otto-born`.
- The metric is `otto-brand-voice-score`.
- On regression it **rolls back**, not just notifies.
- It's actually running, at the first stage.

# Watch it fail

The rollout is now sending about one in ten shoppers to a version of Otto that talks like a form letter. Talk to Otto in the [ToggleWear](#tab-1) tab and send a few messages — most will be the Otto you know, but once in a while you'll get something that opens with "Dear valued customer." That's the Stiff arm, and that's a bad score being written to your metric.

Background traffic has been running since the challenge started, so the metric is already moving. Left alone, the rollout would get there on its own — but "alone" means longer than this lab has. Compress it. In a terminal in the [Code Editor](#tab-2):

```bash
/opt/ld/ai-configs-intro/app/.venv/bin/python3 \
  /opt/ld/ai-configs-intro/traffic-generator/sabotage.py
```

That evaluates 600 contexts, lets LaunchDarkly bucket each one into whichever arm the rollout assigns, and scores it accordingly — near-zero for Stiff, healthy for Born. It's a real regression signal delivered fast, not a fake one: the events are attributed to the arms exactly the way organic traffic is. You're speeding up the clock, not rigging the result.

While it runs, watch the rollout on the **Targeting** tab, and the scores on **Monitoring** with **otto-brand-voice-score** selected.

You're watching for the two arms to separate. Born sits around 0.8 — roughly where you saw it in the judge chapter. Stiff drags along the bottom. When the gap is wide enough for long enough, the rollout calls it.

When it fires:

- A **regression detected** event appears on the rollout's timeline, against `otto-brand-voice-score`.
- Traffic snaps back to 100% `otto-born`. The Stiff arm is dropped.
- The Monitoring graph shows the dip during the rollout and the recovery after it.
- Nobody approved that. It's the part worth noticing.

You can confirm the end state through the agent too — the default rule is a single variation again:

```
Show me otto-assistant's default rule in the Test environment now. Single variation or rollout?
```

# What just happened

A model nobody had tested reached real users, got measured against a standard you wrote yourself, and was withdrawn — and the only human decision in that sequence happened before the rollout started.

That's the difference between a metric and a guardrail. Until now `otto-brand-voice-score` was something you looked at. Here it was something that acted. The judge didn't change at all; you just gave its output somewhere to go.

What made this safe wasn't the rollback. It was having written down what "good" means, in a judge, before you needed it. The rollback is plumbing attached to that definition.

Click **Check** when the guarded rollout is running.

<!-- Both of the VERIFY notes that used to sit here are resolved and removed. The
     first asked whether MCP could report a rollout's stage and per-arm scores;
     the question is moot now that the rollout is started and watched in the UI.
     The second asked whether 90-second monitoring windows were accepted; the
     prose no longer names a number, and what the dialog actually allows is
     folded into the VERIFY on the click-path above. -->

<!-- VERIFY: timing. This chapter's 600s limit was set when the rollout was one
     MCP prompt. It now includes a UI dialog, and the UI-driven original this
     click-path came from allowed 1200s. If a live run overshoots, the budget
     has to come from somewhere — CLAUDE.md records 2100s as fully spent. -->
