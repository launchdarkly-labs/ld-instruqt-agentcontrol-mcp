---
slug: welcome
id: rxbf8wb2433t
type: challenge
title: Welcome to ToggleWear
teaser: Meet ToggleWear, meet Otto-to-be, and get oriented before you start building.
notes:
- type: text
  contents: ToggleWear sells LaunchDarkly-branded apparel. They want an AI shopping
    assistant on the site. Over the next seven challenges you'll build, refine, brand,
    personalize, and measure that assistant. His name is going to be Otto.
tabs:
- id: 8m4k7gecmyvy
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: y4ou0tpu0gxc
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: 5l1knztanlcz
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 300
enhanced_loading: null
---

# Welcome

Over the next ~2 hours, you're going to build an AI shopping assistant for **ToggleWear**, a fictional online retailer of LaunchDarkly-branded apparel. The assistant's name is **Otto**. Right now Otto doesn't exist — by the end of this track, he'll be live in the [ToggleWear](#tab-1) storefront, targeted by user tier, and monitored in production.

You're going to do this using **LaunchDarkly AgentControl**: prompts, models, and rollout strategy as runtime configuration instead of hardcoded values.

# What you'll do

| # | Beat |
|---|---|
| 01 | Create Otto's first Config and wire him into the app. |
| 02 | Change Otto's personality without redeploying. |
| 03 | Factor reusable brand voice into snippets. |
| 04 | Quick quiz to consolidate. |
| 05 | Add a premium-tier Otto, target it by user attribute. |
| 06 | Look at Otto's production data in the monitoring view. |
| 07 | Put a risky model behind a judge and watch it get rolled back. |
| 08 | Wrap up. |

Most of it you'll do in the LaunchDarkly UI. Three things you'll ask a coding agent for instead — the Config, the variations, and the judge — because creating a resource is exactly the kind of thing you shouldn't have to click through.

# Assumptions

This track assumes you already know the LaunchDarkly basics — flags, contexts, environments, targeting rules. If you don't, the [LaunchDarkly Basics](https://launchdarkly.com) track is a better starting point.

The tabs on the right will all be useful: [LaunchDarkly](#tab-0) for the LD UI, [ToggleWear](#tab-1) for the live storefront, [Code Editor](#tab-2) for `server.py` and other repo files.

# Connect your coding agent

The workstation has **Claude Code** installed and already connected to LaunchDarkly's **MCP server**. You'll use it three times — once per resource you create — so it's worth proving the connection now rather than discovering it's broken mid-challenge.

Open the [Code Editor](#tab-2) tab, open a terminal with **Terminal → New Terminal**, and start it:

```sh
claude
```

Confirm it sees the server:

```
/mcp
```

**LaunchDarkly** should be listed as connected. Now prove the connection actually works, which is a different thing:

```
List my LaunchDarkly projects.
```

You should get back exactly one project. That's your sandbox, and your credentials reach nothing else — which is why every prompt in this track says "my project" and never names a project key.

If it reports an invalid access token, tell your instructor. The lab's credentials didn't land, and nothing that depends on the agent will work.

<!-- VERIFY: confirm the code-server terminal path (Terminal > New Terminal) and that `claude` starts with no onboarding, trust, or MCP-approval prompts on a freshly baked image. -->

Click **Check** below when you're ready to start.
