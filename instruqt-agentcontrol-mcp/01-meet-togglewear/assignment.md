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
timelimit: 600
enhanced_loading: null
---

# Welcome

You're going to build an AI shopping assistant for **ToggleWear**, a fictional online retailer of LaunchDarkly-branded apparel. The assistant's name is **Otto**. Right now Otto doesn't exist. By the end of this track he'll be live in the [ToggleWear](#tab-1) storefront, graded on every answer by a judge you wrote, and wired to a review gate that holds his borderline answers for a human.

You're going to do this using **LaunchDarkly AgentControl**: prompts, models, and quality gates as runtime configuration instead of hardcoded values.

And you're going to do almost all of it without clicking through the LaunchDarkly UI. The workstation has **Claude Code** installed, already connected to LaunchDarkly's **MCP server**. You'll describe what you want in plain language and let it create the resources.

# What you'll do

| # | Beat |
|---|---|
| 01 | Ask for Otto's first Config, then wire him into the app. |
| 02 | Ask for a custom judge that scores whether Otto sounds on-brand. |
| 03 | Hold Otto's borderline answers for a human before they reach a customer. |
| 04 | Wrap up. |

# Connect to LaunchDarkly

Open the [Code Editor](#tab-2) tab. Open a terminal in it — **Terminal → New Terminal** — and start the agent:

```sh
claude
```

Confirm it can see the LaunchDarkly MCP server:

```
/mcp
```

You should see **LaunchDarkly** listed as connected. Now prove the connection actually works, which is a different thing. Ask:

```
List my LaunchDarkly projects.
```

You should get back exactly one project.

That one project is your sandbox for this track, and your credentials reach nothing else. That's why every prompt in this track can say "my project" and the agent will resolve it — you never need to type a project key.

<!-- VERIFY: confirm the code-server terminal path (Terminal > New Terminal) and that `claude` launches with no onboarding, trust, or MCP-approval prompts on a freshly baked image. -->

If the agent reports an invalid access token, tell the operator — the lab's credentials didn't land, and nothing downstream will work.

# Assumptions

This track assumes you already know the LaunchDarkly basics: flags, contexts, environments, targeting rules. If you don't, the [LaunchDarkly Basics](https://launchdarkly.com) track is a better starting point.

[Code Editor](#tab-2) is where you'll spend most of your time, both for Claude Code and for editing `server.py`. [ToggleWear](#tab-1) is the live storefront.

The [LaunchDarkly](#tab-0) tab is optional. It signs you into a sandbox LaunchDarkly account so you can look at what you've built, but that sign-in service isn't always available, and nothing in this track needs it — everything you create, you can also read back by asking the agent.

# When the agent gets it wrong

It will, sometimes. Come back to this section when it does — every chapter's **Check** tells you what's missing, and these are the fixes.

**It used a different key.** The most common one, and the one that breaks the most downstream. This track depends on the exact keys `otto-assistant`, `otto-born`, `otto-brand-voice-judge`, and `otto-review-thresholds`. Tell it plainly: *"You created it with key X. Delete that and recreate it with key `otto-assistant` exactly."*

**It created the Config but nothing is being served.** A new Config serves a built-in "disabled" variation until a targeting rule points somewhere else. Ask: *"Set the default rule in the Test environment to serve the otto-born variation."*

**It says it's done and the Check still fails.** Ask it to show you the resource rather than describe it — *"Show me the otto-assistant config's variations and what Test is serving"* — and compare against the spec table in the chapter. Agents report success from their own intent, not from a re-read.

**It picked the wrong mode.** A Config's mode is fixed when it's created. Judge-mode and completion-mode Configs can't be converted, so this one needs a delete and recreate.

**It can't reach LaunchDarkly at all**, or reports an invalid token. That's a lab problem, not yours. Tell your instructor.

The general move: be specific about which thing is wrong, and ask it to fix that one thing. It has the same tools it used to build the resource, so it can correct its own work — but only if you tell it what's actually wrong rather than "that didn't work."

Click **Check** below when the agent has listed your project.
