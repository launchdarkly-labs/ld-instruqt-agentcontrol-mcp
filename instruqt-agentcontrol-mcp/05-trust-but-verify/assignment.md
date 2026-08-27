---
slug: trust-but-verify
id: zx6httops1n8
type: challenge
title: Trust But Verify
teaser: Roll a risky new model out behind the judge you wrote, and let LaunchDarkly
  take it away again when the scores drop.
notes:
- type: text
  contents: A new model landed and someone wants Otto on it. You can't know whether
    it keeps him sounding like himself until real traffic hits it — and by then the
    damage is done. So don't decide. Ship it behind the brand-voice judge, give
    LaunchDarkly a threshold, and let the rollout revert itself if the scores fall.
    The judge you wrote two chapters ago is about to become a release gate.
tabs:
- id: m6cbm4xg6v7u
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: rkea5xu1jjvv
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: fdz8q99f7n6b
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: intermediate
timelimit: 1800
enhanced_loading: null
---

# The question you can't answer in advance

Amazon Nova Pro is cheaper than the Haiku model Otto runs on now, and someone in a meeting has noticed. The honest answer to "will it still sound like Otto?" is that nobody knows until customers are talking to it.

That's not a reason to refuse. It's a reason to not make the decision by hand.

You already have the instrument. The brand-voice judge scores every one of Otto's answers, and `otto-brand-voice-score` is a real metric with real values in it. A guarded rollout points that metric at a release: send a slice of traffic to the new model, watch the score, and roll back automatically if it regresses. Nobody has to be watching at 2am.

This chapter ships a model that is *going to fail*, on purpose, so you can watch the failure get handled.

# What you're rolling out

The candidate is deliberately bad. Its prompt is stiff, formal, and corporate — the precise opposite of what your judge grades for. In a real rollout you'd hope for a coin flip; here you want a landslide, because a subtle regression takes more traffic and more time than a lab has.

| Thing | Value |
|---|---|
| New variation key | `otto-stiff` |
| Model | Amazon Nova Pro — already in your project as `amazon.nova-pro-v1:0` |
| Control variation | `otto-born` |
| Metric to watch | `otto-brand-voice-score` |
| Rollback | Automatic, on regression |

The Nova Pro model config is already in your project — setup put it there, because the app resolves Bedrock model IDs from that exact name and a near-miss would just fail to answer. Everything else on this list, you're about to ask for.

# Ask for the rollout

One prompt creates the risky variation and starts the guarded rollout that will judge it. In your `claude` session:

```
In my LaunchDarkly project, add a new variation to the otto-assistant AI Config.

Key it otto-stiff, name it "Otto (Stiff)", and back it with the existing Nova Pro model config named amazon.nova-pro-v1:0.

Give it this system prompt:

You are a customer service representative for ToggleWear. Assist customers with their inquiries in a professional and formal manner. Always greet the customer formally, provide thorough and complete explanations, and conclude each response with a formal sign-off. Maintain a corporate tone at all times. Avoid contractions, humour, and informality.

Attach the otto-brand-voice-judge to this variation at 100% sampling, the same way otto-born has it.

Then start a guarded rollout in the Test environment with otto-stiff as the test variation and otto-born as the control. Watch the otto-brand-voice-score metric and roll back automatically if it regresses. Use short monitoring windows — about 90 seconds per stage — and start the first stage at 10% of traffic.
```

The keys matter here for the same reason they've mattered all track: `otto-stiff` is what the sabotage script below looks for, and `otto-brand-voice-score` is the metric your judge has been filling since the judge chapter. If the agent invents a new metric instead of reusing that one, the rollout will watch a metric with nothing in it and sit at stage one forever.

Short monitoring windows are a lab concession, and worth naming as one. Ninety seconds is far too short to trust in production — you'd want hours, and enough samples that a quiet Tuesday doesn't read as a regression. You're compressing the clock so the lesson fits in a lab.

# Check its work

```
Show me the guarded rollout on otto-assistant in Test: which variation is the test arm, which is the control, what metric it's watching, what it does on regression, and what stage it's currently in.
```

Four things to confirm:

- The test arm is `otto-stiff` and the control is `otto-born`. Backwards is a rollout that ramps traffic *away* from the bad model and never regresses.
- The metric is `otto-brand-voice-score`.
- On regression it **rolls back**, not just notifies. Notify-only is a pager at 2am; rollback is the point of this chapter.
- It's actually running, at the first stage.

If any of that is wrong, point it out and ask Claude to fix that specific thing.

# Watch it fail

The rollout is now sending about one in ten shoppers to a version of Otto that talks like a form letter. Background traffic has been running since the challenge started, and every session it generates gets scored by your judge, so the metric is already moving.

Talk to Otto in the [ToggleWear](#tab-1) tab and send a few messages. Most of the time you'll get the Otto you know. Once in a while you'll get something that opens with "Dear valued customer" — that's the Stiff arm, and that's a bad score being written to your metric.

Then ask for the status, and keep asking:

```
What stage is the otto-assistant guarded rollout at now, and what is the brand-voice score for each arm?
```

You're watching for the control and test means to separate. Born sits somewhere around 0.8; Stiff should be dragging along the bottom. When the gap is wide enough for long enough, the rollout calls it and reverts.

When it fires:

- The rollout's status changes to rolled back, with a regression recorded against `otto-brand-voice-score`.
- The Test environment goes back to serving `otto-born` to everyone.
- Nobody approved that. It's the part worth noticing.

If the [LaunchDarkly](#tab-0) tab signs you in, **Agents → Configs → Otto Assistant → Monitoring** draws the same story as a graph, with the dip and the recovery. Nice if it works; the read-back prompt is the reliable path.

# If it's taking too long

Background traffic is deliberately slow so the lab doesn't burn tokens. If the rollout is still sitting at stage one and you'd rather not wait, force it from a terminal in the [Code Editor](#tab-2):

```bash
/opt/ld/ai-configs-intro/app/.venv/bin/python3 \
  /opt/ld/ai-configs-intro/traffic-generator/sabotage.py
```

It evaluates 600 contexts, lets LaunchDarkly bucket each one into whichever arm the rollout assigns, and scores it accordingly — near-zero for Stiff, healthy for Born. That's a real regression signal delivered fast, not a fake one: the events are attributed to the arms the same way organic traffic is. The rollback usually fires within a minute of it finishing.

# What just happened

A model nobody had tested reached real users, got measured against a standard you wrote yourself, and was withdrawn — and the only human decision in that sequence happened before the rollout started.

That's the difference between a metric and a guardrail. For three chapters `otto-brand-voice-score` was something you looked at. Here it was something that acted. The judge didn't change at all; you just gave its output somewhere to go.

Worth sitting with: the thing that made this safe wasn't the rollback. It was having written down what "good" means, in a judge, before you needed it. The rollback is just plumbing attached to that definition.

Click **Check** when the guarded rollout is running.

<!-- VERIFY: the guarded-rollout read-back prompts assume the MCP server can report a rollout's current stage and per-arm metric values. If it only exposes create/start and not status, replace the two read-back prompts with the LaunchDarkly UI Monitoring path and demote the MCP prompt to a confirmation that the rollout exists. -->

<!-- VERIFY: confirm 90-second monitoring windows are accepted. The API takes monitoringWindowMilliseconds, but there may be a server-side minimum that silently rounds up — if so, state the real minimum here and adjust the sabotage guidance to match. -->
