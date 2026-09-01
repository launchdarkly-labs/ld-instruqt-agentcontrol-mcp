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
timelimit: 900
enhanced_loading: null
---

# The question you can't answer in advance

Amazon Nova Pro is cheaper than the Haiku model Otto runs on, and someone in a meeting has noticed. The honest answer to "will it still sound like Otto?" is that nobody knows until customers are talking to it.

That's not a reason to refuse. It's a reason not to make the decision by hand.

You already have the instrument. `otto-brand-voice-score` is a real metric with real values in it, filled by the judge *you* wrote in the last chapter. A guarded rollout points that metric at a release: send a slice of traffic to the new model, watch the score, roll back automatically if it regresses. Nobody has to be awake for it.

This is the one chapter you do entirely in the LaunchDarkly UI, and not for want of trying. Starting a guarded rollout is the single thing in this track that has no API — the public REST surface can put *weights* on a rollout and nothing else, so there's no MCP tool for it either. Everything the agent could build here, setup has already built.

Setup has done three things for you:

1. **Created a third variation, `otto-stiff`, backed by Amazon Nova Pro** with a deliberately corporate prompt — formal greetings, formal sign-offs, no contractions. It's the precise opposite of what your judge grades for, and it's meant to fail. A real rollout is a coin flip; here you want a landslide, because a subtle regression needs more traffic than a lab has.
2. **Attached your `otto-brand-voice-judge` to it at 100% sampling**, so the arm being tested is graded exactly the way `otto-born` is. A rollout watching a metric that nothing writes to for the test arm never regresses — it just looks like it's passing.
3. **Started background traffic**, so the metric already has a baseline in it before you begin. A guarded rollout with no baseline sits at stage one indefinitely.

| Thing | Value |
|---|---|
| Test variation | `otto-stiff` — Amazon Nova Pro |
| Control variation | `otto-born` |
| Metric to watch | `otto-brand-voice-score` |
| Rollback | Automatic, on regression |

# Tour the pre-built pieces

Worth two minutes before you start, because the rollout is only as good as what it's watching. Open the [LaunchDarkly](#tab-0) tab.

1. **The Stiff variation.** Go to **Agents → Configs → Otto Assistant → Variations**. You should see three: Born, Premium, and **Otto (Stiff)**. Open Stiff and read its prompt — notice how corporate it is next to the brand voice you wrote a rubric for.
2. **The judge attachment.** Still on Stiff, find the judge configuration. `otto-brand-voice-judge` should be attached at 100% sampling, the same as on Born.
3. **The metric.** Go to **Metrics** in the left nav and open **otto-brand-voice-score**. It's a numeric custom metric with success criteria **HigherThanBaseline** — higher is better, so a drop is a regression. That definition is what the rollout will act on.

<!-- VERIFY: the intro track (slug ld-agentcontrol-intro, ch07) also has the learner confirm an **Evaluation metric** on the assistant Config's Settings tab, which is what pre-selects the metric in the rollout dialog. This track sets evaluation_metric_key on the *judge* Config, not on otto-assistant — see terraform/challenge-02. Confirm whether the rollout dialog therefore starts with no metric selected. If it does, either add the wiring to challenge-01 or keep step 3 of the rollout below explicit, which is why it is written out rather than described as "should already be selected". -->

# Start the guarded rollout

This is the part you do yourself, and it's the most important moment in the track.

Open **Otto Assistant → Targeting**, and confirm the environment picker says **Test**.

1. Click the **Default rule** — the one currently serving **Otto (Born)** to everyone.
2. Change the **Serve** option to **Guarded rollout**.
3. Set:
   - **Initial variation**: **Otto (Born)** — the control, the model you trust.
   - **New variation**: **Otto (Stiff)** — the one on trial. Backwards ramps traffic *away* from the bad model and never regresses.
   - **Metric**: **otto-brand-voice-score**.
   - **Roll back on regression**: **On**. Notify-only is a pager at 2am.
   - **Stages**: leave the defaults.
4. Click **Start rollout**.

<!-- VERIFY: this click-path is copied from the live ld-agentcontrol-intro track, ch07-trust-but-verify, pulled 2026-08-31 with `instruqt track pull launchdarkly/ld-agentcontrol-intro`. Its labels supersede the ones this chapter carried previously, which came from the older ld-agentcontrol-evaluate track and said "Start guarded rollout" / "Test variation" / "Control variation". Confirm the nav: the intro track says "Configs → Otto Assistant" where this one says "Agents → Configs → Otto Assistant", matching 02 and 03. -->

# Watch it fail

The rollout is now sending a slice of shoppers to a version of Otto that talks like a form letter. Talk to Otto in the [ToggleWear](#tab-1) tab and send a few messages — most will be the Otto you know, but once in a while you'll get something that opens with "Dear valued customer." That's the Stiff arm, and that's a bad score being written to your metric.

Background traffic has been running since the challenge started, so the metric is already moving. Left alone, the rollout would get there on its own — but "alone" means longer than this lab has. Compress it. In a terminal in the [Code Editor](#tab-2):

```bash
/opt/ld/ai-configs-intro/app/.venv/bin/python3 \
  /opt/ld/ai-configs-intro/traffic-generator/sabotage.py
```

That evaluates 600 contexts, lets LaunchDarkly bucket each one into whichever arm the rollout assigns, and scores it accordingly — near-zero for Stiff, healthy for Born. It's a real regression signal delivered fast, not a fake one: the events are attributed to the arms exactly the way organic traffic is. You're speeding up the clock, not rigging the result.

While it runs, watch the rollout on the **Targeting** tab and the scores under **Monitoring** with **otto-brand-voice-score** selected. You're watching for the two arms to separate. Born sits around 0.8 — roughly where you saw it in the judge chapter. Stiff drags along the bottom.

When the gap is wide enough for long enough, the rollout calls it:

- A **regression detected** event appears in the rollout's history, against `otto-brand-voice-score`.
- Traffic snaps back to 100% `otto-born`. The Stiff arm is dropped.
- The Monitoring graph shows the dip during the rollout and the recovery after it.
- Nobody approved that. It's the part worth noticing.

# What just happened

You shipped a known-bad model with the safety on. LaunchDarkly sampled a slice of traffic into it, watched your metric for that arm against the baseline, decided statistically that it was worse, and **rolled it back with no human in the loop**.

That's the difference between a metric and a guardrail. Until now `otto-brand-voice-score` was something you looked at. Here it was something that acted. The judge didn't change at all; you just gave its output somewhere to go.

What made this safe wasn't the rollback. It was having written down what "good" means, in a judge, before you needed it. The rollback is plumbing attached to that definition.

Click **Check** when the rollout has started.

<!-- VERIFY: timing. Raised to 900s on 2026-08-31 (track total 2100 → 2400) because this chapter now includes a UI tour and a rollout dialog, and the rollback needs clock to fire. The intro track allows 1200s for the same content. If a live run still overshoots, that is the next number to move. -->
