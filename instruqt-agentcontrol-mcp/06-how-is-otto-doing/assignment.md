---
slug: how-is-otto-doing
id: ksocxxxmrger
type: challenge
title: How is Otto Doing?
teaser: Otto is live. Time to look at the data. Tokens, latency, and learner feedback,
  all in one view.
notes:
- type: text
  contents: A few days of pretend-traffic have rolled through, and ToggleWear shoppers
    have been chatting with Otto and rating his answers. In this challenge you'll
    explore the AgentControl monitoring view and see how Otto's variations stack up.
tabs:
- id: gbus2qcml5o4
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: y6748tjpjqro
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: n0hotutp5yxc
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 900
enhanced_loading: null
---

# Otto is in production

Otto has been live for a couple of pretend-days. ToggleWear shoppers have been chatting with him and giving him thumbs-up and thumbs-down ratings. (Behind the scenes, setup ran a traffic generator that fed Otto ~120 fake sessions while you were starting this lab.)

The point of this challenge is to *look*. You're not going to change anything. You're going to use the AgentControl monitoring view the same way you'd use it the morning after a real launch — to answer the question, "Is Otto working?"

# Open the monitoring view

Open the [LaunchDarkly](#tab-0) tab.

1. Go to **Configs** → **Otto Assistant**.
2. Click the **Monitoring** tab.
3. Set the environment filter to **Test**.

You should see a populated dashboard. Take a minute to look at it before reading further.

# Things to look for

The monitoring view shows your AgentControl's performance broken down by variation. Compare **Otto (Born)** to **Otto (Premium)**:

- **Generations**: how many times each variation was served. Born will be busier because most simulated shoppers were free-tier.
- **Input / output tokens**: tokens by variation. Premium (Sonnet) writes longer answers, so output tokens are higher.
- **Latency**: Sonnet is slower than Haiku. The premium variation should show a higher median latency.
- **Positive vs. negative feedback**: both variations score well, but Premium scores noticeably better. That's not magic — it's the model. The traffic generator weighted positive feedback higher for Sonnet because, in practice, you'd expect a more capable model to produce more on-brand answers.

# Questions to ask yourself

- If you had to pick **one** variation based on this data, which would you pick?
- The Premium variation costs more per call (bigger model, more output tokens). Is the positive-feedback delta worth the cost difference? Where would you look to find the cost data?
- What would you change about the data collection? (Are thumbs-up / thumbs-down enough? Would you also want a numeric quality score? Latency thresholds?)

# What happens next

Otto is healthy in `Test`. The next challenge is the scary one: a new model variation is going live, and we want AgentControl to *automatically pull the plug* if quality drops. Click **Check** when you're satisfied with what you see here.
