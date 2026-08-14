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
