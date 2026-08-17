---
slug: otto-sounds-like-otto
id: giadwdq0s1yv
type: challenge
title: Otto Sounds Like Otto
teaser: Ask for a custom judge that grades every one of Otto's answers against ToggleWear's
  brand voice.
notes:
- type: text
  contents: Otto works, but nobody is checking whether he's any good. In this challenge
    you'll ask Claude Code for a custom judge — a Config in judge mode that scores
    each of Otto's answers from 0.0 to 1.0 on whether he sounds like ToggleWear wants
    him to sound. Then you'll paste a small block into the server so every response
    gets graded, and watch the scores arrive.
tabs:
- id: 4lxawjevq4ic
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: nbxdoutcwgb6
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: pijfxbdyrfxt
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
difficulty: basic
timelimit: 1200
enhanced_loading: null
---

# Grading Otto

Otto answers questions now. Whether he answers them *well* is currently a matter of opinion, and opinions don't scale — nobody is going to read every conversation.

LaunchDarkly ships built-in judges for accuracy, relevance, and toxicity. Useful, but generic: they have no idea what ToggleWear wants Otto to sound like. So we'll write our own.

A judge is just another AgentControl Config, in **judge mode**. Its prompt takes the response being evaluated as a `{{response}}` template variable, grades it, and returns a number. You attach it to the variation you want graded and give it a sampling rate — every graded response costs a second model call, so in production you'd sample down. This lab uses 100%, because the next challenge needs a score on every answer.

# Ask for the judge

Here's the spec:

| Thing | Value |
|---|---|
| Judge config key | `otto-brand-voice-judge` |
| Mode | Judge |
| Evaluation metric | `$ld:ai:judge:otto-brand-voice-score` |
| Variation key | `default` |
| Model | `anthropic.claude-haiku-4-5-20251001-v1:0` on Bedrock |
| Attached to | `otto-assistant` / `otto-born`, sampling 100% |
| Metric | `otto-brand-voice-score`, numeric, averaged, higher is better |

Back in your `claude` session in the [Code Editor](#tab-2) tab:

```
In my LaunchDarkly project, create an AgentControl config named "Otto Brand Voice Judge" with key otto-brand-voice-judge in judge mode, with evaluation metric key $ld:ai:judge:otto-brand-voice-score.

Give it one variation named "Default" with key default, using the Bedrock model anthropic.claude-haiku-4-5-20251001-v1:0, and this system message:

You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.

The brand voice is:

Otto is warm, helpful, and a little playful. He keeps answers short by default and he's honest when he doesn't know something.

Score the response on a scale of 0.0 to 1.0:
- 1.0: Strongly on-brand. Warm and a little playful, and it actually helps.
- 0.7: Mostly on-brand with minor issues.
- 0.4: Correct but cold. Accurate and useful, no warmth or personality.
- 0.2: Declines to help, or is warm but unhelpful.
- 0.0: Off-brand. Rude, off-topic, or contradicts the voice entirely.

Judge tone, not correctness — assume the facts are right. Saying "I don't know" honestly is fine but is not on its own a high score; a good response still helps the customer get somewhere.

Respond with ONLY a number between 0.0 and 1.0. No other text.

Response to evaluate:
{{response}}

Then set the default rule in the Test environment to serve that variation, and attach this judge to the otto-born variation of the otto-assistant config with a sampling rate of 100%.

Finally, create a custom numeric metric with key and event key otto-brand-voice-score, named "Otto Brand Voice Score", unit "score", averaged per user, where a higher value is better.
```

Two details in there that are easy to lose:

- **`{{response}}` is load-bearing.** It's the slot Otto's actual answer gets substituted into. Without it the judge grades an empty string. Check that it survived into the saved prompt.
- **The judge needs its own default rule**, same as Otto did. A judge whose targeting still points at the disabled variation returns nothing, silently.

Note that the brand voice is written out in full inside the judge's prompt. That's a duplicate of what Otto's own prompt implies, and duplication like that drifts. Keeping one definition in one place is what prompt snippets are for — worth knowing about, out of scope here.

Then check its work, same as last time:

```
Show me the otto-brand-voice-judge config: its mode, its evaluation metric key, its variation's full prompt, and what Test is serving. Also show me which judges are attached to otto-assistant's otto-born variation and at what sampling rate.
```

Read the prompt it reads back to you and confirm `{{response}}` is still the last thing in it. That's the one failure that looks like success: a judge missing its template variable still returns confident-looking numbers, for an empty string.

# Wire the app to invoke the judge

Attaching the judge declared your intent. It doesn't make the judge run.

Here's why: the `ldai` SDK can invoke attached judges automatically, but only through a provider plugin, and there's no Bedrock provider today. So the app fetches the judge's Config and calls Bedrock itself. Same judge, same prompt, same score — the call just originates in our code instead of the SDK's.

Open the [Code Editor](#tab-2) tab and open `app/server.py`. Find this function:

```python
def score_response(
    req: "ChatRequest",
    assistant_text: str,
    model_id: str,
) -> Optional[float]:
    """Grade Otto's answer. Returns a score in 0.0-1.0, or None if not graded.

    The judge chapter replaces this body.
    """
    # ─── Challenge 02 judge: replace this body ───────────────────────────────
    return None
```

`/chat` already calls it on every request and hands the result to the review gate you'll write next challenge. Replace the two lines of its body — the marker comment and `return None` — with:

```python
    # ─── Challenge 02: brand-voice judge ─────────────────────────────────────
    # Score Otto's answer 0.0-1.0 with the otto-brand-voice-judge Config, emit
    # it as an otto-brand-voice-score metric event, and return it.
    #
    # Errors are swallowed and return None — a judge failure should not poison a
    # customer's chat. The next challenge decides what None means.
    try:
        bv_ctx = Context.builder(req.session_id).set("tier", req.user_tier).build()
        bv_cfg = ai_client.judge_config(
            "otto-brand-voice-judge",
            bv_ctx,
            variables={"response": assistant_text},
        )
        if not (bv_cfg.enabled and bv_cfg.model is not None):
            return None

        bv_system: list[dict] = []
        bv_messages: list[dict] = []
        for m in (bv_cfg.messages or []):
            if m.role == "system":
                bv_system.append({"text": m.content})
            else:
                bv_messages.append({"role": m.role, "content": [{"text": m.content}]})

        # Bedrock's Converse API requires the conversation to start with a user
        # turn. A LaunchDarkly judge variation normally carries only a system
        # message — the answer being judged is interpolated into it as
        # {{response}} — so bv_messages is empty here and the call would fail with
        # ValidationException: "A conversation must start with a user message."
        if not bv_messages:
            bv_messages = [
                {"role": "user", "content": [{"text": "Score the response. Reply with only the number."}]}
            ]

        bv_kwargs = {
            "modelId": resolve_bedrock_model(bv_cfg.model.name),
            "messages": bv_messages,
            "inferenceConfig": {"maxTokens": 8, "temperature": 0.0},
        }
        if bv_system:
            bv_kwargs["system"] = bv_system

        bv_text = _extract_text(bedrock.converse(**bv_kwargs)).strip()
        score = float(bv_text.split()[0])
        if not 0.0 <= score <= 1.0:
            return None

        ld_client.track("otto-brand-voice-score", bv_ctx, None, score)
        log.info(
            "brand-voice-judge session=%s otto_model=%s score=%.2f",
            req.session_id, model_id, score,
        )
        return score
    except Exception:  # noqa: BLE001
        log.exception("Brand-voice judge eval failed (non-fatal)")
        return None
```

Save the file. The ToggleWear service auto-reloads.

Note the bare `except` returning `None`. A judge is a second model call in the middle of a user's request, and it can fail for reasons that have nothing to do with the customer asking about socks. When it fails the customer still gets their answer and we lose a score. That tradeoff is deliberate, and `None` becomes a real decision in the next challenge.

# Watch the scores

A traffic generator is running against Otto in the background, so scores start landing within a minute or so.

Ask the agent for them:

```
Which metric events has my LaunchDarkly project received recently? I'm looking for otto-brand-voice-score.
```

Once `otto-brand-voice-score` shows up with a recent timestamp, the loop is closed: Otto answered, the judge graded him, and the score reached LaunchDarkly.

Then ask for the substance rather than just the existence:

```
Summarise the recent otto-brand-voice-score values for my project. What's the rough average, and what's the spread?
```

You should see scores clustered in the middle of the range rather than near 1.0. Otto's prompt tells him to be "accurate and concise" and says nothing about warmth, so he's being graded against a standard nobody asked him to meet. He knows the catalog, he just recites it. That gap is the whole reason the next challenge exists.

<!-- VERIFY: confirm the agent can summarise metric values, not just list event keys. If the MCP surface only exposes event keys and last-seen timestamps, cut the second prompt and keep the first. -->

You can also see this in the LaunchDarkly UI under **Agents → Configs → Otto Assistant → Monitoring**, selecting **otto-brand-voice-score** from the metric dropdown. Treat that as optional: the [LaunchDarkly](#tab-0) tab depends on a sandbox sign-in service that isn't always available, and nothing in this track requires it.

Click **Check** when the judge is live and `server.py` invokes it.
