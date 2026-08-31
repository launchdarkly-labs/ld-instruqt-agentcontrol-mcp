---
slug: otto-gets-graded
id: giadwdq0s1yv
type: challenge
title: Otto Gets Graded
teaser: Ask for a custom judge that grades every one of Otto's answers against ToggleWear's
  brand voice, and watch the scores land.
notes:
- type: text
  contents: Otto works, but nobody is checking whether he's any good. In this challenge
    you'll ask Claude Code for a custom judge — a Config in judge mode that scores
    each of Otto's answers from 0.0 to 1.0 on whether he sounds like ToggleWear wants
    him to sound. The app already knows how to invoke it — the moment the judge exists,
    the scores start arriving.
tabs:
- id: 4lxawjevq4ic
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: nbxdoutcwgb6
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: pijfxbdyrfxt
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 300
enhanced_loading: null
---
# Grading Otto

Otto answers questions. Whether he answers them *well* is currently a matter of opinion, and opinions don't scale — nobody is going to read every conversation.

LaunchDarkly ships built-in judges for accuracy, relevance, and toxicity. Useful, but generic: they have no idea what ToggleWear wants Otto to sound like. So write your own.

A judge is just another AgentControl Config, in **judge mode**. Its prompt takes the response being evaluated as a `{{response}}` template variable, grades it, and returns a number. You attach it to the variation you want graded, with a sampling rate — every graded response costs a second model call, so production would sample down. This lab uses 100%, because the guarded rollout in the last chapter needs a score on every answer to have anything to compare.

# Ask for the judge

Here's the spec:

| Thing | Value |
|---|---|
| Judge config key | `otto-brand-voice-judge` |
| Mode | Judge |
| Evaluation metric | `$ld:ai:judge:otto-brand-voice-score` |
| Variation key | `default` |
| Model | `anthropic.claude-haiku-4-5-20251001-v1:0` on Bedrock |
| Attached to | `otto-assistant` / `otto-born`, sampling 100% |
| Metric | `otto-brand-voice-score`, numeric, averaged, higher is better |

Back in your `claude` session in the [Code Editor](#tab-2) tab:

```
In my LaunchDarkly project, create an AgentControl config named "Otto Brand Voice Judge" with key otto-brand-voice-judge in judge mode, with evaluation metric key $ld:ai:judge:otto-brand-voice-score.

Give it one variation named "Default" with key default, using the Bedrock model anthropic.claude-haiku-4-5-20251001-v1:0, and this system message:

You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.

The brand voice is:

Otto is warm, helpful, and a little playful. He keeps answers short by default and he's honest when he doesn't know something.

Score the response on a scale of 0.0 to 1.0:
- 1.0: Strongly on-brand. Warm and a little playful, and it actually helps.
- 0.7: Mostly on-brand with minor issues.
- 0.4: Correct but cold. Accurate and useful, no warmth or personality.
- 0.2: Declines to help, or is warm but unhelpful.
- 0.0: Off-brand. Rude, off-topic, or contradicts the voice entirely.

Judge tone, not correctness — assume the facts are right. Saying "I don't know" honestly is fine but is not on its own a high score; a good response still helps the customer get somewhere.

Respond with ONLY a number between 0.0 and 1.0. No other text.

Response to evaluate:
{{response}}

Then set the default rule in the Test environment to serve that variation, and attach this judge to the otto-born variation of the otto-assistant config with a sampling rate of 100%.

Finally, create a custom numeric metric with key and event key otto-brand-voice-score, named "Otto Brand Voice Score", unit "score", averaged per user, where a higher value is better.
```

Two details are easy to lose:

- **`{{response}}` is load-bearing.** It's the slot Otto's answer gets substituted into. Without it the judge grades an empty string — and still returns confident-looking numbers. That's the failure that looks like success.
- **The judge needs its own default rule**, same as Otto did. A judge whose targeting still points at the disabled variation returns nothing, silently.

Read it back, and check the prompt specifically:

```
Show me the otto-brand-voice-judge config: its mode, its evaluation metric key, its variation's full prompt, and what Test is serving. Also show me which judges are attached to otto-assistant's otto-born variation and at what sampling rate.
```

Confirm `{{response}}` is still the last thing in the prompt it reads back.

# Watch the scores

You don't need to wire anything up. The app already invokes the judge on every answer — attaching it declared the intent, and `score_response()` in `server.py` does the work, because `ldai` can only run attached judges through a provider plugin and there's no Bedrock provider today. Same judge, same prompt, same score; the call just originates in the app.

Background traffic is running against Otto, so scores start landing within a minute.

```
Summarise the recent otto-brand-voice-score values for my project. What's the rough average, and what's the spread?
```

You should see scores clustered in the middle of the range rather than near 1.0. Otto's prompt tells him to be "accurate and concise" and says nothing about warmth, so he's being graded against a standard nobody asked him to meet. He knows the catalog; he just recites it.

Remember roughly where that average sits. It's the baseline the last chapter's guarded rollout measures a challenger against.

<!-- VERIFY: confirm the agent can summarise metric values, not just list event keys. If the MCP surface only exposes event keys and last-seen timestamps, replace this prompt with one that just confirms otto-brand-voice-score has recent events. -->

Click **Check** when the judge is live and scores are arriving.
