---
slug: otto-on-brand
id: 3yduvofx3oy4
type: challenge
title: Otto On-Brand at Scale
teaser: Otto's prompt is getting long. Factor reusable brand voice and safety rules
  into snippets you can share across configs.
notes:
- type: text
  contents: As Otto's prompt grows, you'll want to pull common pieces — brand voice,
    safety rules — out into reusable snippets. Snippets let you change those rules
    in one place and have every AgentControl Config that references them pick up the
    change.
tabs:
- id: q5vx16ad04kj
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: cjpk73n3ezym
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: i0h6i1da7k54
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Otto's prompt is getting long

Otto's prompt now describes his voice *and* what he sells *and* what he won't do. As we add variations for different audiences, all of those pieces will need to repeat. That's a maintenance trap — change the brand voice and you'd update it in every variation.

**Snippets** let you pull repeated chunks out and reference them from anywhere. Update a snippet once, and every variation that references it picks up the change.

We're going to extract two snippets:
- **brand-voice** — Otto's tone and personality.
- **safety-rules** — what Otto must not do.

Then we'll refactor Otto's prompt to use them.

# Create the `brand-voice` snippet

Open the [LaunchDarkly](#tab-0) tab.

1. From the left-hand navigation, go to **Library**, then click **Snippets** from the upper menu.
2. Click **Create snippet**.
3. For **Name**, enter:
```text
Brand voice
```
4. For **Key**, confirm or set:
```text
brand-voice
```
5. For **Text**, enter:
```text
You are Otto. You're warm, helpful, and a little playful. You keep answers short by default and you're honest when you don't know something.
```
6. Click **Save**.

# Create the `safety-rules` snippet

Repeat for the second snippet:

1. Back on **Snippets**, click **Create snippet**.
2. **Name**:
```text
Safety rules
```
3. **Key**:
```text
safety-rules
```
4. **Text**:
```text
Don't make up prices, sizes, or policies. If you don't know, say so and suggest the customer check the product page or contact support. Don't discuss topics outside of ToggleWear and the products we sell.
```
5. Click **Save**.

# Refactor Otto's prompt

1. Navigate back to **Configs** → **Otto Assistant** → **Otto (Born)**.
2. In the **System** prompt text area, clear out the existing text.
3. Click **Load snippet**, and select **Brand voice**.
4. Below the `{{snippet.brand-voice#1}}` markup that the editor inserts, enter the following:
```text
You work at ToggleWear, an online shop for LaunchDarkly-branded apparel. Help customers find products, answer questions about sizing and care, and guide them when they're not sure what they want.
```
5. With the cursor positioned in the next line, click **Load snippet** and select **Safety rules**.
6. Click **Review and Save**, then **Save changes**.

# Try it

Open the [ToggleWear](#tab-1) tab and chat with Otto. He should sound exactly the same as he did at the end of Challenge 02 — same voice, same guardrails — because the snippets contain the same content. The win is structural, not behavioral: now if marketing changes the brand voice, you change it in one place.

```text
What's the difference between the Rocket Tee and the Feature Branch Crewneck?
```

Click **Check** when you're satisfied.
