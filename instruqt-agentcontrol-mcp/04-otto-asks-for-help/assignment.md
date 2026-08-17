---
slug: otto-asks-for-help
id: oyl7cnyoc4uq
type: challenge
title: Otto Asks for Help
teaser: Ship Otto's confident answers, hold his borderline ones for a human, and suppress
  the bad ones — with the thresholds living in LaunchDarkly.
notes:
- type: text
  contents: 'A judge score is only worth what you do with it. In this challenge you''ll
    put Otto''s answers through a three-way gate: high scores go straight to the customer,
    middling scores get held for a human to approve or fix, and low scores never leave
    the building. The thresholds live in a LaunchDarkly flag, so you can retune how
    cautious Otto is without redeploying anything.'
tabs:
- id: zzlbjqrmwmlk
  title: LaunchDarkly
  type: browser
  hostname: launchdarkly
- id: xpusl1cvwlro
  title: ToggleWear
  type: service
  hostname: workstation
  port: 3000
- id: bswkkmilyxrs
  title: Code Editor
  type: service
  hostname: workstation
  port: 8080
- id: pbriyqddh9ml
  title: Staff Review
  type: service
  hostname: workstation
  path: /review
  port: 3000
difficulty: intermediate
timelimit: 1500
enhanced_loading: null
---

# A score nobody acts on

Otto is being graded on every answer, and so far the grade changes nothing. A 0.2 reaches the customer exactly as fast as a 0.95.

The obvious fix — block everything below some number — throws away most of the value. Plenty of Otto's borderline answers are fine and just need a light edit. Those are worth a human's thirty seconds; they're not worth losing.

So: three bands.

| Score | What happens |
|---|---|
| at or above `auto` | Ships straight to the customer. |
| between `review` and `auto` | Held. The customer gets a "checking this" note; a human approves, edits, or rejects. |
| below `review` | Suppressed. The customer gets a safe fallback pointing at support. |

The interesting design question is where those two numbers live. In code, changing them is a deploy. In LaunchDarkly, changing them is a click — which matters, because you will not guess them right the first time.

# Ask for the thresholds flag

A JSON flag holds both numbers as one value, so a threshold change is one atomic edit rather than two flags that can disagree.

| Thing | Value |
|---|---|
| Flag key | `otto-review-thresholds` |
| Type | JSON |
| Variation 1 | `Balanced` — `{"auto": 0.8, "review": 0.5}` |
| Variation 2 | `Cautious` — `{"auto": 0.95, "review": 0.7}` |
| Serving | `Balanced`, on, in Test |

In your `claude` session:

```
In my LaunchDarkly project, create a JSON feature flag with key otto-review-thresholds named "Otto Review Thresholds".

Give it two variations:
- named "Balanced", value {"auto": 0.8, "review": 0.5}
- named "Cautious", value {"auto": 0.95, "review": 0.7}

Turn the flag on in the Test environment and serve the Balanced variation by default.
```

Check its work before you rely on it:

```
Show me the otto-review-thresholds flag: its type, both variation values, whether it's on in Test, and which variation Test serves by default.
```

Two things to confirm, both of which fail quietly. The variation values have to be real JSON objects with `auto` and `review` as numbers — a JSON flag holding the *string* `"{\"auto\": 0.8}"` looks fine in the UI and parses to nothing useful. And the flag has to be **on**: an off flag serves its off-variation, which here is also Balanced, so the gate appears to work while ignoring your targeting entirely.

# Wire the gate

Open `app/server.py` in the [Code Editor](#tab-2) and find this function:

```python
def gate_response(
    req: "ChatRequest",
    assistant_text: str,
    score: Optional[float],
    model_id: str,
) -> tuple[str, str]:
    """Decide what the customer sees. Returns (text_to_send, decision).

    `decision` is one of "ship", "hold", or "suppress".
    The review-gate chapter replaces this body.
    """
    # ─── Challenge 03 review gate: replace this body ─────────────────────────
    return assistant_text, "ship"
```

`/chat` calls it with the score from the judge you wired last challenge, and sends whatever text it returns. Replace the two lines of its body with:

```python
    # ─── Challenge 03: human-in-the-loop review gate ─────────────────────────
    # Otto has an answer and the judge has a score. Decide who gets to see it.
    #
    # The thresholds are NOT in this code — they come from the
    # otto-review-thresholds flag, so the band can be retuned in LaunchDarkly
    # while the app keeps running.
    review_ctx = Context.builder(req.session_id).set("tier", req.user_tier).build()
    thresholds = ld_client.variation(REVIEW_FLAG_KEY, review_ctx, REVIEW_DEFAULTS)
    try:
        auto_at = float(thresholds["auto"])
        review_at = float(thresholds["review"])
    except (KeyError, TypeError, ValueError):
        log.warning("Malformed %s variation: %r — using defaults", REVIEW_FLAG_KEY, thresholds)
        auto_at = REVIEW_DEFAULTS["auto"]
        review_at = REVIEW_DEFAULTS["review"]

    if score is None:
        # The judge didn't produce a score. Fail open: a customer waiting on a
        # human because our judge timed out is a worse outcome than an ungraded
        # answer, and a hold nobody is staffed to clear is just a dropped reply.
        decision = "ship"
    elif score >= auto_at:
        decision = "ship"
    elif score >= review_at:
        decision = "hold"
    else:
        decision = "suppress"

    if decision == "hold":
        _enqueue_review(req.session_id, req.message, assistant_text, score, model_id)
        assistant_text = HOLD_PLACEHOLDER
    elif decision == "suppress":
        assistant_text = SUPPRESS_FALLBACK

    ld_client.track(
        "otto-review-outcome",
        review_ctx,
        {"decision": decision, "score": score},
        1,
    )
    log.info(
        "review-gate session=%s score=%s auto=%.2f review=%.2f decision=%s",
        req.session_id, score, auto_at, review_at, decision,
    )
    return assistant_text, decision
```

Save the file. The service auto-reloads.

The queue, the `/review` endpoints, and the Staff Review page are already built — `_enqueue_review`, `HOLD_PLACEHOLDER`, `SUPPRESS_FALLBACK`, and `REVIEW_FLAG_KEY` all come from the top of `server.py`. What you just wrote is the only part that's a judgement call.

Read the `score is None` branch again before you move on. That's the failure mode nobody plans for: the judge is a second model call inside the customer's request, and when it fails you have to choose between shipping ungraded text and making a customer wait on a human who may not be there. This code ships. That's defensible, not obviously correct, and it's the kind of thing worth deciding on purpose rather than discovering in an incident.

# Watch it work

Open the [ToggleWear](#tab-1) tab and talk to Otto until you land in the middle band. Ask him something he'll answer stiffly and briefly:

```text
What is your return policy?
```

Otto knows the policy but states it flatly, which is exactly what lands in the middle band. A few tries should get you a hold. When one does:

1. The chat shows *"One moment — I'm having a colleague double-check this before I send it."*
2. Switch to the [Staff Review](#tab-3) tab. Otto's proposed answer is waiting there with its score and the customer's question.
3. Warm it up — edit the text — then click **Approve**. Switch back to [ToggleWear](#tab-1) and within a few seconds your edit appears in the customer's chat.
4. Get another hold and click **Reject** instead. The customer gets the support fallback pointing at the team.

Notice what the two tabs are doing. Same browser, same person, but a shopper and a support agent are different roles with different authority, and the response crosses between them before it reaches anyone. That crossing is the whole chapter.

If nothing gets held, your scores are all landing above `0.8`. Rather than fighting it, retune the band — which is the next step anyway.

# Retune without redeploying

Ask for a wider review band:

```
Switch the otto-review-thresholds flag in Test to serve the Cautious variation.
```

Now `auto` is `0.95` and `review` is `0.7`, so far more of Otto's answers route through a human. Send a few more messages and watch the queue fill.

No deploy. No restart. The app didn't change; the policy did. That's the same move you'd make with any LaunchDarkly flag, applied to a governance decision rather than a feature.

Change it back to **Balanced** when you've seen enough.

Click **Check** when the flag exists and the gate is wired.

<!-- VERIFY: confirm an Instruqt service tab accepts a `path:` key to open /review directly. If it doesn't, the learner has to navigate from the storefront's Staff Review link instead, and this tab plus the #tab-3 references need rewording. -->
