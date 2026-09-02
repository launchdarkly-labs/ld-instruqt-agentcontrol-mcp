---
slug: wrap-up
id: hnlirgubshf1
type: quiz
title: Wrap-Up
teaser: Otto is up and being watched. So are you.
notes:
- type: text
  contents: You started with a placeholder line in server.py and ended with a targeted,
    monitored AI assistant running in production. One last question to close the loop,
    then you're done with Build.
answers:
- The Python `launchdarkly-server-sdk-ai` package detects prompt edits on disk and
  restarts the app.
- LaunchDarkly evaluates the Config at runtime on every chat call, so prompts, models,
  and targeting rules picked up from the UI take effect without a redeploy.
- The systemd service watches the LaunchDarkly UI over a websocket and rebuilds the
  app when anything changes.
- The ToggleWear server caches each variation's prompt on first use and never reloads
  it.
solution:
- 1
difficulty: basic
timelimit: 600
enhanced_loading: null
---
# Otto's arc

Otto started as a placeholder line in `server.py`. From there:

- **Challenge 01** — born. First Config, first prompt, first words from the storefront.
- **Challenge 02** — got a personality. Changed his voice without restarting the server.
- **Challenge 03** — got reusable. Brand voice and safety rules pulled into snippets shared across variations.
- **Challenge 05** — got tier-aware. Premium shoppers met a more capable Sonnet-backed Otto, free shoppers stayed with Haiku.
- **Challenge 06** — got measured. Tokens, latency, feedback all visible per variation in production.

The point of the track wasn't to build a shopping assistant. It was to show that **AI behavior can be treated the same way you already treat features** — runtime-configurable, observable, and safe to change.

# One last question

Otto launched, gained a voice, learned to talk differently to premium customers, and got monitored in production — all without an emergency code change. What enabled prompt and model changes to take effect without restarting the app or redeploying it?

# Where to go from here

This is Track 1 of three. Otto is built — he's not yet **tested**, **judged**, **experimented on**, or **guarded**. That's what's next:

- **Evaluate (L2)** — golden datasets, online judges (built-in + custom), prompt experiments, guarded rollouts, adaptive switching.
- **Coordinate (L3)** — Otto grows from a solo assistant into a team. Multi-agent graphs, specialist routing, per-agent rollouts, self-healing.

Plus:

- **AgentControl documentation:** [launchdarkly.com/docs/home/agentcontrol](https://launchdarkly.com/docs/home/agentcontrol)
- **Your own use case.** The pattern transfers: prompts you can iterate on, models you can swap, audiences you can target.

# Otto says

> Thanks for shopping with us. Come back any time.
