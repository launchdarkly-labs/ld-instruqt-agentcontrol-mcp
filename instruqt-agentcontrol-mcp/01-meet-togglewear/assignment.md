---
slug: meet-togglewear
id: sueugtnwvj4d
type: challenge
title: Welcome to ToggleWear
teaser: Meet ToggleWear, meet Otto-to-be, and connect your coding agent to LaunchDarkly.
notes:
- type: text
  contents: ToggleWear sells LaunchDarkly-branded apparel. They want an AI shopping
    assistant on the site. Over the next four challenges you'll build that assistant,
    grade him, and decide what happens when the grade comes back shaky. His name is
    going to be Otto. You'll build him by asking, not by clicking.
tabs:
- id: gha3tbtluxzo
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: yxorswxxav8c
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: z5wqwbtxssee
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 240
enhanced_loading: null
---
# Welcome

You're going to build **Otto**, an AI shopping assistant for **ToggleWear**, a fictional retailer of LaunchDarkly-branded apparel. By the end he'll be live in the [ToggleWear](#tab-1) storefront, routing premium shoppers to a stronger model, graded on every answer by a judge you wrote — and that judge will have thrown out a replacement model on his behalf, automatically.

You'll do it with **LaunchDarkly AgentControl**: prompts, models, and quality gates as runtime configuration instead of hardcoded values. And you'll do nearly all of it without touching the LaunchDarkly UI. The workstation has **Claude Code** installed and already connected to LaunchDarkly's **MCP server** — you describe what you want, it creates the resources.

The ToggleWear app is already built and already knows how to talk to AgentControl. You won't be writing application code.

| # | Beat |
|---|---|
| 02 | Ask for Otto's Config, then change his prompt with no deploy. |
| 03 | Route premium shoppers to a stronger model. |
| 04 | Ask for a judge that scores whether he sounds on-brand. |
| 05 | Put a risky model behind that judge and watch it get rolled back. |

# Connect to LaunchDarkly

Open the [Code Editor](#tab-2) tab, open a terminal — **Terminal → New Terminal** — and start the agent:

```sh
claude
```

Confirm it sees the MCP server:

```
/mcp
```

**LaunchDarkly** should be listed as connected. Now prove the connection works, which is a different thing:

```
List my LaunchDarkly projects.
```

You should get back exactly one project. That's your sandbox, and your credentials reach nothing else — which is why every prompt in this track says "my project" and never a project key.

If the agent reports an invalid access token, tell the operator. The lab's credentials didn't land and nothing downstream will work.

<!-- VERIFY: confirm the code-server terminal path (Terminal > New Terminal) and that `claude` launches with no onboarding, trust, or MCP-approval prompts on a freshly baked image. -->

This track assumes you know LaunchDarkly basics — flags, contexts, environments, targeting. The [LaunchDarkly](#tab-0) tab is optional throughout: it signs you into a sandbox account to look at what you've built, but that sign-in isn't always available and nothing here needs it.

# When the agent gets it wrong

It will, sometimes. Come back here when a **Check** fails.

**It used a different key.** The most common failure, and the one that breaks the most downstream. This track depends on the exact keys `otto-assistant`, `otto-born`, `otto-premium`, `otto-brand-voice-judge`, and `otto-stiff`. Say plainly: *"You created it with key X. Delete that and recreate it with key `otto-assistant` exactly."*

**It says it's done and the Check still fails.** Ask it to show you the resource rather than describe it, and compare against the chapter's spec table. Agents report success from their own intent, not from a re-read.

**Nothing is being served.** A new Config serves a built-in "disabled" variation until a targeting rule points elsewhere.

**It picked the wrong mode.** A Config's mode is fixed at creation — judge and completion can't be converted, so that one needs a delete and recreate.

The general move: name the specific thing that's wrong and ask it to fix that one thing. It has the same tools it used to build the resource.

Click **Check** when the agent has listed your project.
