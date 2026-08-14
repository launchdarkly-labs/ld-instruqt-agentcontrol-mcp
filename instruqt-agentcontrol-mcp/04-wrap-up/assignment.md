---
slug: wrap-up
id: hnylkffksunn
type: quiz
title: Wrap-Up
teaser: Otto is built, graded, and governed. One question before you go.
notes:
- type: text
  contents: You started with a placeholder line in server.py and ended with an AI
    assistant that grades its own answers and knows when to hand one to a human —
    and you built almost all of it by asking, not clicking. One last question, then
    you're done.
answers:
- Attaching a judge to a variation makes LaunchDarkly run it automatically, so no
  application code is needed.
- Attaching the judge records the intent and the sampling rate in LaunchDarkly, but
  this app invokes the judge itself, because the AI SDK has no Bedrock provider to
  run it through.
- The judge runs inside the MCP server, which calls Bedrock on the app's behalf.
- Judges only run during offline evaluations against a dataset, never on live traffic.
solution:
- 1
difficulty: basic
timelimit: 600
enhanced_loading: null
---
# Otto's arc

Otto started as a placeholder line in `server.py`. From there:

- **Challenge 01** — born. One prompt to Claude Code produced his Config, his variation, and a targeting rule, and a few lines of SDK code gave him his first words.
- **Challenge 02** — graded. A custom judge in judge mode now scores every one of his answers against ToggleWear's brand voice.
- **Challenge 03** — governed. High scores ship, middling scores wait for a human, low scores never reach a customer — with the thresholds in a flag you retuned live.

Two things are worth taking away, and neither is about shopping assistants.

**The resources were ordinary.** Nothing Claude Code created is a special kind of Config, flag, or metric. It's the same project you'd have built by clicking, which is exactly why this works: the MCP server is a different interface onto the same product, not a parallel one.

**The interesting decisions were still yours.** The agent wrote the Config. It didn't decide where the review band sits, or that a failed judge should ship rather than hold. Those are the parts that needed a person, and they're the parts that will differ for your use case.

# One last question

You attached the brand-voice judge to Otto's variation, and then you also pasted a block of code into `server.py` that calls the judge. Why both?

# Where to go from here

Things this track deliberately left out, each a reasonable next step:

- **Prompt snippets** — one definition of "on-brand" shared by Otto's prompt and his judge's criteria, instead of the duplicate you saw in challenge 02.
- **Guarded rollouts** — roll a new model out behind the brand-voice metric and let LaunchDarkly revert it automatically when scores drop.
- **Experiments** — compare two Otto variations on live traffic instead of eyeballing a chart.
- **Offline evaluations** — grade a candidate prompt against a golden dataset before it ever meets a customer.

Plus:

- **AgentControl documentation:** [launchdarkly.com/docs/home/agentcontrol](https://launchdarkly.com/docs/home/agentcontrol)
- **The LaunchDarkly MCP server:** [launchdarkly.com/docs/home/getting-started/mcp-hosted](https://launchdarkly.com/docs/home/getting-started/mcp-hosted) — point your own coding agent at it.

# Otto says

> Thanks for shopping with us. Come back any time.
