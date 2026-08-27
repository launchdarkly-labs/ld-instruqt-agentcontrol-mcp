---
slug: otto-is-born
id: 49vhbkkoxhyb
type: challenge
title: Otto is Born
teaser: Ask for Otto's first AgentControl Config, then change his mind mid-conversation
  without a deploy.
notes:
- type: text
  contents: Today is Otto's first day. You'll ask Claude Code for his first Config
    in AgentControl — a starting prompt and a starting model — and then change that
    prompt while he's running, without deploying anything.
tabs:
- id: it1g4gasa915
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: jc5dtsgchozh
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: lz0tawrr8h1c
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 480
enhanced_loading: null
---
# Meet Otto

ToggleWear wants an AI shopping assistant on the storefront. We've named him Otto, and right now he doesn't exist. Try the chat widget on the [ToggleWear](#tab-1) tab and he'll tell you he isn't enabled — the app is asking LaunchDarkly what to say and getting nothing back.

The app is already built and already knows how to talk to AgentControl. What it doesn't have is a Config to read. That's what you're about to create, and you'll create it by asking.

# Ask for Otto's Config

Otto needs three things in LaunchDarkly: a Config to live in, a variation holding his prompt and model, and a targeting rule that actually serves that variation.

You could click all of that together in the UI. Instead, describe it once and let Claude Code do it. Here's what we're asking for:

| Thing | Value |
|---|---|
| Config key | `otto-assistant` |
| Config mode | Completion |
| Variation key | `otto-born` |
| Model | `anthropic.claude-haiku-4-5-20251001-v1:0` on Bedrock |
| Default rule, Test env | serve `otto-born` |

Go back to your `claude` session in the [Code Editor](#tab-2) tab and paste this:

```
In my LaunchDarkly project, create an AgentControl config named "Otto Assistant" with key otto-assistant in completion mode.

Give it one variation named "Otto (Born)" with key otto-born, using the Bedrock model anthropic.claude-haiku-4-5-20251001-v1:0, and this system message:

You are a customer service assistant for ToggleWear, an online retailer of LaunchDarkly-branded apparel. Answer questions from customers about products and store policies. Be accurate and concise.

Products:
- Rocket Tee, $28. Classic crew-neck t-shirt with the LaunchDarkly rocket. Heather grey. Runs true to size.
- Feature Flag Hoodie, $58. Pullover hoodie, embroidered flag logo. Midnight navy. Heavyweight cotton blend.
- Dark Mode Cap, $24. Six-panel dad cap, tone-on-tone black logo. Adjustable strap, one size.
- Ship It Mug, $16. 12oz ceramic. Dishwasher safe.
- Toggle Socks, $14. Crew socks with a small rocket at the ankle. Sizes S/M and L/XL.
- Release Notes Notebook, $18. A5 hardcover, dot grid, 160 pages.
- Rollout Tote, $22. 12oz canvas with reinforced handles.
- Feature Branch Crewneck, $52. Heavyweight crewneck sweatshirt. Sage green.

Apparel comes in XS through 3XL unless noted. Wash cold, tumble dry low.

Policies: free shipping over $50, otherwise $6 flat. Domestic delivery 3-5 business days, international 7-14. Returns accepted within 30 days on unworn items. Gift cards are available in $25, $50, and $100.

If a customer asks something these notes don't cover, say you don't know and point them to the product page or support.

Then set the default rule in the Test environment to serve otto-born.
```

The keys matter. The app looks up `otto-assistant` by key, and later chapters add a variation and attach a judge to `otto-born` by key. If the agent picks something different, tell it to use the exact keys above.

Two things worth noticing when it finishes:

- That last instruction is the one people forget. A new Config serves a built-in "disabled" variation until you point the default rule somewhere, so a Config with a perfectly good variation still returns nothing.
- Nothing it built is special because an agent built it. It's an ordinary Config, the same one you'd get by clicking — which is the point. If the [LaunchDarkly](#tab-0) tab signs you in, you can see it under **Agents → Configs**; that tab relies on a sandbox sign-in service that isn't always up, so the next section reads the Config back through the agent instead.

# Check its work

An agent will tell you it succeeded either way. Run the following command to see details of the Config:

```
Show me the otto-assistant config: its mode, its variations and their keys and models, and what the Test environment is serving.
```

You're looking for mode `completion`, one variation keyed `otto-born` on a Haiku 4.5 model, and Test serving that variation rather than the built-in disabled one. If any of this information is wrong, point it out and ask Claude to fix it specifically.

Verifying is the habit. Do it after every prompt in this track.

# Say hi to Otto

Open the [ToggleWear](#tab-1) tab and click **Chat with Otto** in the bottom-right. Ask him something:

```text
Got any t-shirts?
```

He answers for real now. He'll also be brief and a little robotic — that's deliberate, and it gives the judge you'll write later something to complain about.

# The six lines that did that

You didn't touch the app, so it's worth seeing what it's doing. Open `app/server.py` in the [Code Editor](#tab-2) and find the `/chat` handler. The part that matters is one call:

```python
cfg = ai_client.completion_config(OTTO_CONFIG_KEY, context, FALLBACK_CONFIG)
```

`cfg` now carries the prompt, the model, and the parameters that whoever edits the Config decided on — resolved fresh on this request, for this `context`. Everything after it is translation: `cfg.messages` becomes Bedrock's `system` and `messages` blocks, `cfg.model.name` becomes a Bedrock model ID, and `cfg.create_tracker()` reports tokens and latency back to LaunchDarkly.

That's the whole integration surface. **LaunchDarkly decides *what* to send; your code decides *how* to send it.** Nothing about Otto's prompt or his model is in that file — which is what makes the next section possible.

# Change his mind without shipping anything

Otto's prompt says free shipping starts at $50. Ask him:

```text
How much is shipping on a $40 order?
```

He'll quote you $6. Now marketing drops the threshold to $35 — a one-word change to a fact customers rely on, and in most architectures a deploy.

```
In the otto-assistant AI Config, update the otto-born variation's system message: change "free shipping over $50" to "free shipping over $35". Change nothing else about the prompt.
```

Back in [ToggleWear](#tab-1), start a **new** chat and ask again. The $40 order now ships free.

Nothing rebuilt, nothing restarted, and `server.py` is byte-for-byte what it was a minute ago. The prompt was never in the application — the application only ever knew how to go and ask for one.

The "new chat" detail is the one caveat. `completion_config()` resolves on every request, so the change is live immediately, but Otto's earlier replies are still in his history and he'll stay consistent with what he already told you. Stale conversation, not stale config.

Put it back before moving on — leave it and Otto starts contradicting the storefront's own shipping copy:

```
Change the otto-born system message back: free shipping over $50, not $35.
```

Click **Check** below.
