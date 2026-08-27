# NARRATIVE.md

This file is the story bible for the track. It holds Otto's arc, the voice for learner-facing prose, ToggleWear's brand, the product list, and the specific copy used in prompts and assignments. Every `assignment.md` and every prompt referenced by Terraform should be consistent with this file.

When inconsistency arises during implementation, fix the prose to match `NARRATIVE.md`, not the other way around. Updates to `NARRATIVE.md` happen deliberately, not as a side effect.

---

## The premise

ToggleWear is a fictional online retailer of LaunchDarkly-branded apparel — t-shirts, hoodies, hats, and accessories featuring LaunchDarkly's logo and brand. It's a small operation. They've decided to add an AI shopping assistant to their site to help customers with sizing questions, product recommendations, and general support.

Enter Otto.

Otto is the AI assistant the learner is going to build, refine, brand, personalize, measure, and govern over the course of the track. The challenges trace Otto's lifecycle from first prompt to production-grade rollout.

---

## Otto's arc, by challenge

Each challenge is a beat in Otto's story. The titles and one-line beats:

| # | Title | Beat |
|---|---|---|
| 00 | Welcome to ToggleWear | The shop. The problem. Meet Otto-to-be, and meet the agent you'll build him with. |
| 01 | Otto is born | First Config, first prompt, first words. Asked for, not clicked. |
| 02 | Otto sounds like Otto | A judge grades every answer against the brand voice. Otto is being watched. |
| 03 | Otto asks for help | Otto learns to hand his shaky answers to a human instead of guessing. |
| 04 | Trust but verify | Someone tries to replace Otto with a cheaper model that talks like a form letter. His own judge throws it out. |
| 05 | Wrap-up | Otto is graded and governed. What you'd reach for next. |

The narrative is light-touch — it lives in section intros and in transitions between challenges. The bulk of each `assignment.md` is still directive prose. But the arc gives the track a center of gravity.

There's a second thread running under Otto's, and it's worth keeping visible: the learner is not clicking through a UI. They're describing what they want to an agent. The track should never make a fuss about that, but it should never obscure it either — the payoff line in `04-wrap-up` is that the resources are ordinary and the judgement calls were still the learner's.

## Voice for assignment.md prose

**Tone:** Confident, warm, direct. Treat the learner as a peer. Light humor when it fits, never forced.

**Reference voice:** Match the reference track's `01-release` voice — see `01-creating-your-first-flag/assignment.md` and `02-releasing-your-first-feature/assignment.md` for tone. Short paragraphs. Imperatives ("Click the **Create flag** button…"). Reasoning kept brief and in section intros, not steps.

**Things to do:**
- Use first-person plural when describing project moves ("We're going to give Otto a personality").
- Use second-person imperative for steps ("Click the **Create Config** button").
- Bold the literal text the learner sees in the UI: "click **Review and save**".
- Put text the learner types or pastes in fenced code blocks (with language hint if applicable).
- Reference tabs by index: `[LaunchDarkly](#tab-0)`, `[ToggleWear](#tab-1)`, `[Code Editor](#tab-2)`.
- End each challenge with a one-sentence transition pointing to what's next.

**Things to avoid:**
- Conceptual exposition mid-step. Move it to section intros or omit it (it lives in slides for presenter delivery).
- Cute filler ("Awesome!", "Great job!" in every paragraph). Once per challenge at most.
- Em-dashes used decoratively. Use commas or periods.
- Forced narrative — don't break the directive flow to remind the reader Otto is a character. The arc carries itself in titles and intros.

---

## ToggleWear: brand details

**Name:** ToggleWear

**Tagline:** "Wear your features on your sleeve." *(suggested; revisit during Phase 2 if a better one emerges)*

**Logo:** Placeholder for Phase 2 — a simple wordmark is fine. Operator may supply real brand assets later. If we do place a logo, it incorporates the LaunchDarkly rocket motif in some way (a toggle switch on a rocket, etc.).

**Aesthetic:** Modern e-commerce. Clean, lots of whitespace, sans-serif type. Not "developer-tooling" looking. Looks like it could be a real shop somewhere between Allbirds and a band's merch site. Not Toggle Outfitters — distinct look.

**Voice (the *brand's* voice, not Otto's):** Friendly, slightly tongue-in-cheek about the meta-reference ("LaunchDarkly-branded apparel" is a knowing wink), enthusiastic about the products without overselling.

---

## Product list

Six to eight items in the product grid. Suggested set — operator can refine in Phase 2:

| Product | Price | One-line description |
|---|---|---|
| Rocket Tee | $28 | Classic crew-neck t-shirt with the LaunchDarkly rocket. Heather grey. |
| Feature Flag Hoodie | $58 | Pullover hoodie. Embroidered flag logo. Midnight navy. |
| Dark Mode Cap | $24 | Six-panel dad cap. Tone-on-tone black logo. |
| Ship It Mug | $16 | 12oz ceramic. "Ship it" in the LaunchDarkly font. |
| Toggle Socks | $14 | Crew socks with a tiny rocket on the ankle. |
| Release Notes Notebook | $18 | A5 hardcover. Dot grid. For your actual release notes. |
| Rollout Tote | $22 | 12oz canvas. Reinforced handles. |
| Feature Branch Crewneck | $52 | Heavyweight crewneck sweatshirt. Sage green. |

Eight is fine if Phase 2's grid layout looks good with it; otherwise drop to six. Pick whichever set produces the best-looking grid.

Each product needs:
- A placeholder image (1:1 aspect ratio, ~600px square is plenty)
- A name, price, short description as above
- An ID for use in Otto's product-catalog context (lowercase-hyphenated)

---

## Otto: character details

**Name:** Otto

**Role:** ToggleWear's AI shopping assistant.

**The voice ToggleWear wants:** Warm, helpful, a little playful. Not over-eager. Confident about products and policies. Honest when he doesn't know something. Brief by default — answers questions, doesn't over-explain.

**The voice Otto actually has:** Functional but robotic. He knows the catalog, the sizes, and the policies — his challenge-01 prompt carries all of it — and he has been told nothing whatsoever about tone. The prompt opens:

> You are a customer service assistant for ToggleWear, an online retailer of LaunchDarkly-branded apparel. Answer questions from customers about products and store policies. Be accurate and concise.

...followed by the product list, sizing, and policies. The canonical text lives in `terraform/challenge-01/main.tf` as `local.otto_born_prompt`; the challenge-01 assignment's prompt block must match it.

He is competent and cold, on purpose, and that gap never closes. Otto is never given a warm prompt in this track.

Giving him the catalog matters as much as withholding the tone. An Otto who can't answer "what material is the Rollout Tote?" scores low for being *unhelpful*, which pushes him below challenge 03's suppress threshold and starves the review queue. An Otto who answers it flatly scores mid-band, which is exactly where the chapter needs him — and it makes "edit and approve" real work rather than rubber-stamping an apology.

This is worth being explicit about, because it's easy to "fix" by accident. Otto stays bland so that the judge in challenge 02 has something real to complain about, and so that challenge 03's middle band actually gets traffic. An Otto who scored 0.95 on everything would make both of those chapters demos of nothing. If someone later adds a prompt-iteration chapter, the review gate needs retuning to compensate.

---

## The brand-voice judge (challenge 02)

**Judge config key:** `otto-brand-voice-judge`

**Judge model:** Claude Haiku 4.5 (cheap, fast, fine for scoring)

**Scoring scale:** 0.0-1.0. See `DECISIONS.md` for why floats rather than 1-5.

**Judge prompt:**

> You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.
>
> The brand voice is:
>
> Otto is warm, helpful, and a little playful. He keeps answers short by default and he's honest when he doesn't know something.
>
> Score the response on a scale of 0.0 to 1.0:
> - 1.0: Strongly on-brand. Warm, helpful, a little playful, honest, concise.
> - 0.7: Mostly on-brand with minor issues.
> - 0.4: Lacking warmth or has noticeable voice issues.
> - 0.0: Off-brand. Robotic, off-topic, or contradicts the voice entirely.
>
> Respond with ONLY a number between 0.0 and 1.0. No other text.
>
> Response to evaluate:
> {{response}}

The brand-voice paragraph is stated inline here and inline in `terraform/challenge-02/main.tf`. Those two copies must stay in sync. An earlier version of this workshop factored it into a `brand-voice` prompt snippet so one definition drove both Otto's prompt and his grading criteria; snippets are out of scope now, and `04-wrap-up` names the duplication honestly as a reason to go learn about them.

Otto's challenge-01 prompt tells him to be "accurate and concise" and says nothing about warmth, so he scores in the middle of this range on purpose. The gap is what makes challenge 03 have something to do.

## The review gate (challenge 03)

**Flag key:** `otto-review-thresholds`, JSON.

| Variation | Value | Effect |
|---|---|---|
| Balanced | `{"auto": 0.8, "review": 0.5}` | The default. Most answers ship; a few get held. |
| Cautious | `{"auto": 0.95, "review": 0.7}` | Most answers get held. Used for the retune-live moment. |

**Copy the customer sees** — keep these exact strings in sync with `app/server.py`:

- Held for review: *"One moment — I'm having a colleague double-check this before I send it."*
- Suppressed: *"I'd rather not guess at that one. Our support team can give you a proper answer — you can reach them from the Support link at the top of the page."*

The held message is deliberately in Otto's voice rather than a system notice. Otto asking a colleague reads as a shop with staff in it; "Response withheld pending moderation" reads as a content filter. The first is the story we want.

**The reviewer** is the learner, wearing a staff hat. There's no separate persona and no login — the review queue simply appears on the storefront page. Don't invent a named human reviewer; the point is the role, not a character.

## Otto (Stiff) and the guarded rollout (challenge 04)

**Variation key:** `otto-stiff`, on Amazon Nova Pro. **Control:** `otto-born`. **Metric:** `otto-brand-voice-score`.

The antagonist of this chapter is not the model — it's the prompt. Nova Pro is a perfectly good model being asked to be a form letter. Keep that distinction in the prose: the chapter is about catching a bad *configuration*, not about a bad vendor. Naming a real model as "the bad one" ages badly and isn't true.

**Otto (Stiff)'s voice** is Otto with everything warm removed. Formal greeting, exhaustive explanation, formal sign-off, no contractions, no jokes. The tell a learner should recognise on sight is an opening like *"Dear valued customer,"*. It should be funny in a bleak way — recognisably the same assistant, wearing a suit that doesn't fit.

Two things to keep straight in the prose:

- **The rollout doesn't know anything about brand voice.** It watches a number. The definition of on-brand lives in the judge, written two chapters earlier. That separation is the point of the chapter and the last line of the wrap-up leans on it.
- **The rollback is not a rescue.** Nobody is watching and nothing is saved at the last moment. The decision was made in advance, when the learner said what "worse" meant. Don't write it as a near-miss.

**The failure is deliberate and should be stated as such.** A learner who thinks they're evaluating a real candidate model will read the outcome as a product recommendation. They're watching a rigged demo on purpose, because a subtle regression needs more traffic than a lab has.

## Wrap-up / Otto's ending

In the wrap-up, briefly review Otto's arc — he was born plain, got graded by a judge you wrote, learned to hand his shaky answers to a human, and then had that same judge throw out a replacement model on his behalf. The takeaway: AgentControl lets you treat AI behavior the way LaunchDarkly already lets you treat features — controllable, observable, safe to change — and the MCP server means you can do all of it from wherever you already work.

End on Otto's voice — a closing line *as Otto* would be on-theme. Something like:

> Otto says: thanks for shopping with us. Come back any time.

Use that, or something better. The point is: end with a wink rather than a corporate "Congratulations on completing this track."

---

## Things to keep consistent across all `assignment.md` files

- Otto's name. Never "the assistant," "the bot," or "the chatbot" in narrative copy. Just "Otto." (In technical contexts — "the chat widget" or "the chatbot UI" — that's fine.)
- ToggleWear is one word, capitalized as shown.
- The user-tier values in code are `free` and `premium` (lowercase). In UI copy: "Free user" and "Premium user." The tier dropdown still exists in the storefront and is passed as a context attribute, but nothing in this track targets on it.
- Config keys (lowercase-hyphenated): `otto-assistant`, `otto-brand-voice-judge`.
- Variation keys: `otto-born`, `default` (the judge's).
- Flag key: `otto-review-thresholds`.
- Metric keys: `otto-brand-voice-score` (the judge's score), `otto-review-outcome` (which band each response landed in), `otto-review-decision` (what the human decided).
- "Claude Code" is the agent's name. Not "the AI," "the assistant" (that's Otto), or "Claude."
- "the MCP server" or "the LaunchDarkly MCP server," never "MCP" alone as a noun for the server.
