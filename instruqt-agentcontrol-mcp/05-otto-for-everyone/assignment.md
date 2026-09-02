---
slug: otto-for-everyone
id: u0xw6n6n3m37
type: challenge
title: Otto for Everyone
teaser: Free shoppers and premium shoppers want different things. Give them different
  Ottos with variations and targeting.
notes:
- type: text
  contents: Premium ToggleWear members get the white-glove treatment everywhere else
    on the site — Otto should be no exception. In this challenge you'll add a second
    variation backed by a more capable model, then target it to premium shoppers.
tabs:
- id: tp154eoclghk
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: qhpyj8da8q41
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: m6f7hkmq5oph
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Two audiences, two Ottos

Free shoppers and premium ToggleWear members get different treatment everywhere else on the site. Otto should be no exception. Premium customers get more time, more detail, and a more capable model behind the answers.

We're going to:

1. Add a second variation backed by **Claude Sonnet 4.5** with a richer premium-tier prompt.
2. Add a **targeting rule** that routes premium customers to that variation. Free shoppers keep getting the Haiku-backed Otto from the earlier challenges.
3. Test by flipping the user-tier dropdown on ToggleWear.

# Add the premium variation

Same as Otto's first variation — ask for it. In your `claude` session:

```
Add a second variation to the otto-assistant AI Config.

Name it "Otto v2 (Premium)" and key it otto-premium. Back it with Claude Sonnet 4.5, and give it a system message that starts from the same brand voice as otto-born and then adds:

You work at ToggleWear and you're talking to a premium customer. Take a little more time with them. Offer thoughtful recommendations, mention complementary items when relevant, and share interesting product details (materials, care, the story behind a design). You can be a bit warmer and more conversational.
```

Then read it back:

```
Show me the otto-assistant variations: for each one, the key, the model, and the system message.
```

You should have two — `otto-born` on Haiku and `otto-premium` on Sonnet.

**One thing the agent can't do for you.** In the previous challenge you refactored Otto's prompt to pull in the `brand-voice` and `safety-rules` snippets. The premium prompt should reuse them too, so that a change to the brand voice tomorrow reaches both Ottos. Open the variation in the [LaunchDarkly](#tab-0) tab — **Agents → Configs → Otto Assistant**, edit **Otto v2 (Premium)** — and use **Load snippet** to add **Brand voice** above the premium text and **Safety rules** below it, then **Review and save** and **Save changes**.

<!-- VERIFY: snippet references in a variation prompt are inserted with the UI's "Load snippet" control, and the MCP server has no tool for composing a prompt out of snippets. Confirm on a live run whether an agent asked to "reuse the brand-voice snippet" can emit the reference token itself (the original's check looks for {{snippet.brand-voice#1}} or similar) — if it can, this manual step collapses into the prompt above and should. -->

# Route premium shoppers to the premium Otto

Click the **Targeting** tab. Make sure the environment selector reads **test**.

1. Above the **Default rule**, click **+** and select **Build a custom rule**.
2. Build the clause:
	1. Context kinds: **user**
	2. Attribute: **tier**
	3. Operator: **is one of**
	4. Values: **premium** _&lt;ENTER&gt;_
3. For the variation dropdown, select **Otto (Premium)**.
4. Leave the **Default rule** as **Otto (Born)** — free shoppers and anyone without a tier still get the Haiku Otto.
6. Click **Review and save**, then **Save changes**.

# See it work

Open the [ToggleWear](#tab-1) tab. The header has a **Logged in as** dropdown. It defaults to **Free user**.

1. With **Free user** selected, click **Chat with Otto** and ask a question:
```text
What's good for cold weather?
```
Otto should be brief and friendly — that's the Haiku-backed Born variation.

2. Close the chat. At the top right of the page, change the dropdown to **Premium user**.

3. Re-open and reset the chat and ask the same question. Otto should answer at more length, mention complementary items, and feel a bit warmer — that's the Sonnet-backed Premium variation, served because the LaunchDarkly context now has `tier: "premium"` and the rule you just added matches it.

The app's code didn't change. The variation you served changed because LaunchDarkly evaluated the targeting rule against the context.

Click **Check** when you're satisfied.
