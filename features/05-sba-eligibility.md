# Feature: SBA Eligibility Pre-Check

**Tier:** Free
**Target:** v1.5
**Risk:** low — small rule set, high credibility payoff

## Goal

Catch SBA-7(a)-disqualifying issues before the searcher writes an LOI. Run the standard eligibility checks (business type, real estate concentration, foreign ownership, size standards, prior SBA loans), surface a green/yellow/red verdict with specifics, and tell the user what to verify with the broker before going further.

Small surface area, big credibility win. Catches the kind of deal-killers searchers don't learn about until 3 weeks into wasted diligence.

## Why this matters

Not every business qualifies for SBA 7(a) financing. The disqualifying rules are public (SOP 50 10 7) but obscure to new searchers. *Real estate >50% of asset value, foreign ownership thresholds, NAICS-based size standards, prior SBA debt of the seller, business-type exclusions (gambling, religion, agriculture, etc.)* — any of these can kill the deal mid-DD.

A searcher who burns 4 weeks on an ineligible deal will never forget the Underight session that caught it on day one.

## Eligibility rules to check (v1.5 scope)

### Business type
- Excluded industries per SBA SOP 50 10 7: gambling, religion-affiliated, multi-level marketing, lending, life insurance, speculative real estate, pyramid sales, illegal activity.
- LLM-augmented: read the CIM business description, classify against excluded categories.

### Real estate concentration
- If >50% of asset value is real estate, deal must be SBA 504 (not 7(a)) or the real estate is purchased separately.
- Requires asset breakdown from CIM or financials.

### Foreign ownership / citizenship
- >49% non-US ownership disqualifies SBA 7(a).
- Buyer must be a US citizen or lawful permanent resident.
- This is a buyer-side flag — surfaced as a question, not a deal-killer.

### Size standards (NAICS-based)
- Per-NAICS revenue or employee thresholds. Most SMBs are under, but verify.
- Requires industry classification + revenue figure.

### Prior SBA loans
- If the seller has an outstanding SBA loan on the business, it must be paid off at closing. Affects sources & uses.
- Surfaced as a question to ask the broker.

### Equity injection
- SBA typically requires 10% equity injection from the buyer. Can be cash + seller note on standby (with restrictions on seller note terms).
- Surfaced as a planning flag, not a check.

### Personal eligibility (buyer-side flags)
- Prior bankruptcy, criminal history, prior SBA default — all may disqualify the buyer.
- Surfaced as a buyer self-check, not auto-evaluated.

## Output

A new section in `AnalysisDocumentView`:

- **Verdict:** Green ("Eligible based on what we see") / Yellow ("Likely eligible — verify these items") / Red ("Eligibility issue likely — see below")
- **Per-rule findings:** PASS / NEEDS VERIFICATION / FAIL with specifics.
- **Buyer-side checklist:** items the searcher needs to self-verify (citizenship, prior SBA, personal history).
- **Questions for the broker:** specific items to confirm (entity structure, foreign ownership, prior SBA debt, asset composition).

## Implementation approach

- **Rules engine** in Swift. Each rule = struct with check function returning `EligibilityFinding`.
- **Inputs:** Deal model + CIM-extracted business description + buyer profile (collected once, stored in app preferences).
- **LLM-augmented** only for industry/business-type classification (the "is this business an excluded industry" call).
- **Output:** structured findings, rendered as a section in the analysis document.

## UI surface

- "SBA Eligibility" section in `AnalysisDocumentView`, near the verdict.
- One-time buyer profile collection on app first-run (citizenship status, prior SBA, etc.) — stored locally, never sent to the LLM, never logged.
- "Why?" tooltip on every finding linking to the SBA SOP reference.

## Dependencies

- `AnthropicClient` (week 2) — for business-type classification only.
- Buyer profile model (new, v1.5) — small, local-only.
- No new infrastructure beyond the rules engine.

## Risks / traps

- **Stale rules.** SBA SOP updates periodically. Hard-code the rules as of SOP 50 10 7 (2026) and version them. Show "rules current as of YYYY-MM-DD" in the eligibility section. Update annually.
- **Liability creep.** This is not legal or financial advice. Voice and copy must consistently frame findings as "verify with your lender" or "ask the broker." Never "you cannot get SBA financing for this deal" — *"this deal likely faces SBA eligibility friction; verify with your lender."*
- **Buyer-side complexity.** Buyer eligibility (personal history, citizenship) is sensitive. Don't gate the analysis behind a long onboarding form. Collect minimally, defer optional items until they're relevant.

## Why Free tier

- Catches deal-killers — a feature that's invisible until the moment it saves a searcher 4 weeks of wasted DD.
- Builds trust early; sells the Pro tier on the back of "Underight already caught the SBA issue, of course I'll pay for the lender package."

## What ships in v1

Nothing functional. v1.5 ships SBA Eligibility as a core feature.
