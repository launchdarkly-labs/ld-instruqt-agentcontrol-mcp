---
slug: wrap-up
id: bmdvjnc9v8df
type: quiz
title: Wrap-Up
teaser: Otto is built, graded, and governed. One question before you go.
notes:
- type: text
  contents: You started with an app that had nothing to read and ended with an AI
    assistant that routes by customer tier, grades its own answers, and can withdraw
    a bad model on its own — built entirely by asking, not clicking. One last question,
    then you're done.
answers:
- Attaching a judge to a variation makes LaunchDarkly run it automatically, so no
  application code is needed.
- Attaching the judge records the intent and the sampling rate in LaunchDarkly, but
  this app has to invoke the judge itself, because the AI SDK has no Bedrock provider
  to run it through.
- The judge runs inside the MCP server, which calls Bedrock on the app's behalf.
- Judges only run during offline evaluations against a dataset, never on live traffic.
solution:
- 1
difficulty: basic
timelimit: 120
enhanced_loading: null
---
# Otto's arc

Otto started as an app with nothing to read:

- **Otto is Born** — One prompt produced his Config, his variation, and a targeting rule. Then you changed his shipping policy mid-conversation without deploying anything.
- **Otto Knows His Audience** — Premium shoppers got routed to a stronger model, while the app carried on making exactly the same call.
- **Otto Gets Graded** — A custom judge now scores every one of his answers against ToggleWear's brand voice.
- **Trust But Verify** — That judge became a release gate. A risky model went out behind it, scored badly on real traffic, and LaunchDarkly took it back without anyone deciding to.

Two things are worth taking away, and neither is about shopping assistants.

**The resources were ordinary.** Nothing Claude Code created is a special kind of Config, flag, or metric. It's the same project you'd have built by clicking — which is the point. The MCP server is a different interface onto the same product, not a parallel one.

**The interesting decisions were still yours.** The agent wrote the Config, the variations and the judge; you set the targeting rule and armed the rollout yourself. Neither of you decided which customers deserve a more expensive model, or what "on-brand" means — those were judgement calls, and the second one is what the guarded rollout ultimately enforced on your behalf.

# One last question

You attached the brand-voice judge to Otto's variation in LaunchDarkly. But if you look in `server.py`, the app *also* contains code that calls that judge itself. Why both?

# Where to go from here

Things this track deliberately left out, each a reasonable next step:

- **Prompt snippets** — one definition of "on-brand" shared by Otto's prompt and his judge's criteria, instead of the duplicate you saw in the judge chapter.
- **Experiments** — compare two Otto variations on live traffic instead of eyeballing a chart.
- **Human-in-the-loop review** — instead of shipping or suppressing on the judge's score, hold the borderline answers in a queue for a person to approve or edit.
- **Offline evaluations** — grade a candidate prompt against a golden dataset before it ever meets a customer.

Plus:

- **AgentControl documentation:** [launchdarkly.com/docs/home/agentcontrol](https://launchdarkly.com/docs/home/agentcontrol)
- **The LaunchDarkly MCP server:** [launchdarkly.com/docs/home/getting-started/mcp-hosted](https://launchdarkly.com/docs/home/getting-started/mcp-hosted) — point your own coding agent at it.

# Otto says

> Thanks for shopping with us. Come back any time.
