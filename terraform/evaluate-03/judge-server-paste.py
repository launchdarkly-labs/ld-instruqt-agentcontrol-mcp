    # ─── Evaluate 03: brand-voice judge ─────────────────────────────────────
    # Score Otto's response 0.0-1.0 with the otto-brand-voice-judge Config,
    # then emit the score as an otto-brand-voice-score metric event. Errors
    # are swallowed — a judge failure should not poison a user's chat.
    try:
        bv_ctx = Context.builder(req.session_id).set("tier", req.user_tier).build()
        bv_cfg = ai_client.judge_config(
            "otto-brand-voice-judge",
            bv_ctx,
            variables={"response": assistant_text},
        )
        if bv_cfg.enabled and bv_cfg.model is not None:
            bv_system: list[dict] = []
            bv_messages: list[dict] = []
            for m in (bv_cfg.messages or []):
                if m.role == "system":
                    bv_system.append({"text": m.content})
                else:
                    bv_messages.append(
                        {"role": m.role, "content": [{"text": m.content}]}
                    )
            bv_kwargs = {
                "modelId": resolve_bedrock_model(bv_cfg.model.name),
                "messages": bv_messages,
                "inferenceConfig": {"maxTokens": 8, "temperature": 0.0},
            }
            if bv_system:
                bv_kwargs["system"] = bv_system
            bv_resp = bedrock.converse(**bv_kwargs)
            bv_text = _extract_text(bv_resp).strip()
            try:
                score = float(bv_text.split()[0])
            except (ValueError, IndexError):
                score = None
            if score is not None and 0.0 <= score <= 1.0:
                ld_client.track("otto-brand-voice-score", bv_ctx, None, score)
                log.info(
                    "brand-voice-judge session=%s otto_model=%s score=%.2f",
                    req.session_id, model_id, score,
                )
    except Exception:  # noqa: BLE001
        log.exception("Brand-voice judge eval failed (non-fatal)")
