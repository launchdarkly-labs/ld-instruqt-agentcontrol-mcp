---
slug: otto-is-born
id: 49vhbkkoxhyb
type: challenge
title: Otto is Born
teaser: Ask for Otto's first AgentControl Config, then wire him into the ToggleWear
  app.
notes:
- type: text
  contents: Today is Otto's first day. You'll ask Claude Code for his first Config
    in AgentControl, with a starting prompt and a starting model, and then add the
    few lines of server code that bring him to life. By the end of this challenge,
    Otto will say his first words from the ToggleWear storefront.
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
timelimit: 1200
enhanced_loading: null
---

# Meet Otto

ToggleWear wants an AI shopping assistant on the storefront, and we're going to build it. We've named him Otto. Right now he's a placeholder — the chat widget on the [ToggleWear](#tab-1) tab returns a canned "not wired up yet" line. We're going to fix that.

By the end of this challenge:

- Otto exists as a **Config** in AgentControl.
- He has a starting prompt and a starting model (Claude Haiku 4.5 on Bedrock).
- The ToggleWear app evaluates the Config on each `/chat` call.
- Otto says his first real words.

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

You're looking for mode `completion`, one variation keyed `otto-born` on a Haiku 4.5 model, and Test serving that variation rather than the built-in disabled one. If any of this information is wrong, point it out and ask it to fix it specifically. Claude has the tools to correct its own work.

This is worth doing every time, not just here. Verifying is the habit; the prompt is the easy part.

# Wire Otto into the app

Open the [Code Editor](#tab-2) tab. Open `server.py`.

You could ask Claude Code to write this part too. We're pasting it by hand because the SDK calls are the part worth reading — this is the whole surface area of talking to AgentControl from an application, and it's about a dozen lines.

Find the block marked:

```python
# ─────────────────────────────────────────────────────────────────────
# Challenge 01 paste block — replace this stub with real Otto code.
```

Replace **everything between the opening marker and the** `# ─── End Challenge 01 paste block ────` **line** with:

```python
    # ─── Challenge 01: wire Otto to /chat ─────────────────────────────────
    # Build context, evaluate the otto-assistant Config.
    context = Context.builder(req.session_id).set("tier", req.user_tier).build()
    cfg = ai_client.completion_config(OTTO_CONFIG_KEY, context, FALLBACK_CONFIG)

    if not cfg.enabled or cfg.model is None:
        return JSONResponse(status_code=503, content={
            "response": "Otto isn't enabled. Check the Config targeting.",
            "turn": turn, "turn_limit": TURN_LIMIT,
        })

    # Translate the Config's messages into Bedrock Converse format.
    system_blocks = []
    seed_messages = []
    for m in cfg.messages or []:
        if m.role == "system":
            system_blocks.append({"text": m.content})
        else:
            seed_messages.append({"role": m.role, "content": [{"text": m.content}]})

    # Merge in this session's prior turns + the new user message.
    with _state_lock:
        prior = list(_history[req.session_id])
    history_blocks = [{"role": m.role, "content": [{"text": m.content}]} for m in prior]
    bedrock_messages = seed_messages + history_blocks + [
        {"role": "user", "content": [{"text": req.message}]}
    ]

    model_id = resolve_bedrock_model(cfg.model.name)
    tracker = cfg.create_tracker()

    try:
        response = tracker.track_bedrock_converse_metrics(
            bedrock.converse(modelId=model_id, messages=bedrock_messages, system=system_blocks)
        )
    except ClientError as e:
        err = e.response.get("Error", {})
        log.error("Bedrock ClientError code=%s model=%s message=%s",
                  err.get("Code"), model_id, err.get("Message"))
        return JSONResponse(status_code=502, content={
            "response": _bedrock_user_message(err.get("Code")),
            "turn": turn, "turn_limit": TURN_LIMIT,
        })

    assistant_text = _extract_text(response)

    usage = response.get("usage") or {}
    metrics = response.get("metrics") or {}
    log.info(
        "chat session=%s tier=%s turn=%d model=%s tokens_in=%s tokens_out=%s latency_ms=%s",
        req.session_id, req.user_tier, turn, model_id,
        usage.get("inputTokens"), usage.get("outputTokens"), metrics.get("latencyMs"),
    )
```


Save the file (⌘ + S/Ctrl + S). The ToggleWear service auto-reloads.

Now read it, because this is the whole AgentControl surface area:

```python
cfg = ai_client.completion_config(OTTO_CONFIG_KEY, context, FALLBACK_CONFIG)
```

One call, and `cfg` carries the prompt, the model, and the parameters that whoever edits the Config decided on — resolved fresh on every request, for this specific `context`. `ai_client` was built once at startup, further up the file: `ai_client = LDAIClient(ld_client)`.

Everything after that call is translation. `cfg.messages` becomes Bedrock's `system` and `messages` blocks, `cfg.model.name` becomes a Bedrock model ID, and `cfg.create_tracker()` gives you a tracker that reports tokens and latency back to LaunchDarkly so the Monitoring tab has something in it.

That's the shape worth remembering: LaunchDarkly decides *what* to send, your code decides *how* to send it. Nothing about the prompt or the model is in this file.

# Say hi to Otto

Open the [ToggleWear](#tab-1) tab. Click **Chat with Otto** in the bottom-right. Ask him something — try:

```text
Got any t-shirts?
```

Otto should answer for real this time. He'll be brief and a little robotic. That's by design: it gives the judge you're about to write something to actually complain about.

# Change his mind without shipping anything

Otto's prompt says free shipping starts at $50. Ask him:

```text
How much is shipping on a $40 order?
```

He'll quote you $6. Now suppose marketing drops the threshold to $35 — a one-word change to a fact a customer relies on, and in most architectures a code change, a review, and a deploy.

Here it isn't. In your `claude` session:

```
In the otto-assistant AI Config, update the otto-born variation's system message: change "free shipping over $50" to "free shipping over $35". Change nothing else about the prompt.
```

Go back to [ToggleWear](#tab-1), start a **new** chat, and ask the same question. Otto now says the $40 order ships free.

Nothing was rebuilt. Nothing restarted. You didn't touch `server.py` — go and look at it if you don't believe it. The prompt was never in the application; the application only ever knew how to go and ask for one.

That "start a new chat" instruction is the one caveat worth understanding. `completion_config()` resolves on every request, so the change is live immediately — but Otto's earlier replies are still in his conversation history, and he'll stay consistent with what he already told you. It's a stale conversation, not a stale config.

Put it back before you move on:

```
Change the otto-born system message back: free shipping over $50, not $35.
```

Leave it changed and Otto starts contradicting the storefront's own shipping copy, which is a confusing thing to debug three chapters from now.

When you're satisfied, click **Check** below.
