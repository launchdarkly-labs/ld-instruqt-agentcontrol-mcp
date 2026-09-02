---
slug: quiz-configs-and-snippets
id: 6cjs0ylcroj6
type: quiz
title: Quiz — AgentControl Configs and Snippets
teaser: A quick check on what you just built.
notes:
- type: text
  contents: Pause for a moment and consolidate. The next question is about AgentControl
    Configs, Snippets, and what changes when you edit a prompt in the AgentControl
    UI.
answers:
- The Python `launchdarkly-server-sdk-ai` package auto-reloads the server when a prompt
  changes.
- LaunchDarkly AgentControl evaluates at runtime, so prompt edits in the UI are picked
  up on the next chat — no redeploy required.
- The systemd service watches for prompt file changes on disk and restarts the app.
- The ToggleWear chat widget caches the prompt in `localStorage` and refreshes hourly.
solution:
- 1
difficulty: ""
timelimit: 600
enhanced_loading: null
---
Otto's system prompt changed twice in the last three challenges — first when you gave him a personality, then when you factored brand voice and safety rules into snippets. Each time, the change took effect without restarting or redeploying the ToggleWear app.

What made that possible?
