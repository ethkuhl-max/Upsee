# Feature: Source Document Verification

**Tier:** Free (intentional magnet)
**Target:** v1
**Risk:** low — small implementation, high credibility payoff

## Goal

Cross-check the seller's CIM claims against the financial schedules attached or embedded in the CIM. When numbers don't reconcile, flag them. *If the CIM body says SDE = $400K but the P&L on page 23 implies $320K, surface the discrepancy.*

The trust feature. Also the viral feature — screenshots of "Underight caught the broker's CIM lying about SDE" sell themselves to ETA Twitter.

## Why this matters

Sellers and brokers routinely round, fudge, or selectively report numbers in CIM narratives that don't tie to the underlying financials. Most buyers don't catch it because they read the CIM body and skim the financials. Underight that systematically reconciles is doing work no human reliably does, and the value lands the first time it finds a real discrepancy.

This is the feature that takes Underight from "another LLM wrapper" to "this thing caught something I would have missed."

## Discrepancy types to detect

1. **Reported SDE vs SDE derived from P&L** — claim doesn't match the math.
2. **Revenue claim vs P&L revenue** — narrative says $2.1M, P&L sums to $1.94M.
3. **Add-back amounts vs documented amounts** — claimed $40K in "owner perks" but the line items only total $28K.
4. **Year claimed vs year shown** — "trailing twelve months" but financials are calendar year 2024.
5. **Missing categories** — narrative cites "recurring service revenue" but no breakdown in financials supports the split.
6. **Math errors in the CIM itself** — gross margin doesn't equal revenue minus COGS as stated.

## Implementation approach

- **Phase 1: deterministic extraction.** PDFKit text extraction → regex / heuristic pass to pull out claimed key numbers (asking price, SDE, revenue, EBITDA, individual add-backs) from CIM body.
- **Phase 2: financial table extraction.** Parse tabular data in the CIM's P&L pages. PDFKit gets us text; tabular structure recovery is harder — start with positional heuristics, fall back to LLM-assisted parsing for ambiguous layouts.
- **Phase 3: reconciliation pass.** Pure Swift. Compare claimed vs extracted, tolerance bands per category (round numbers in narrative are normal; >2% deviation is suspicious; >5% is a discrepancy worth flagging).
- **Phase 4: LLM commentary.** For each flagged discrepancy, LLM produces a one-line explanation of what doesn't tie and what to ask the broker.

## Output

- New "Source Verification" section in `AnalysisDocumentView`.
- Badge count on the verdict header ("3 discrepancies").
- Each discrepancy: claim, source location (page, line), reconciled value, LLM commentary, suggested broker question.
- "All ties" green-check banner when nothing material is flagged — also useful (signals a clean CIM).

## UI surface

- Always shown in `AnalysisDocumentView`, prominent placement near the verdict.
- Click a discrepancy → highlights the relevant region in the source PDF viewer panel.

## Dependencies

- PDFKit extraction layer (week 2 work, this leverages it)
- LLM client (week 2 work, this leverages it)
- No new infrastructure — this feature is mostly *new prompts and reconciliation logic on existing primitives*.

## Risks / traps

- **False positives.** Round numbers and approximations in narrative are normal; flagging "$2M vs $1.97M" makes the feature feel pedantic. Tolerance bands must be calibrated against real CIMs in week 2 prompt-iteration sessions.
- **Tabular extraction is hard.** PDF tables vary wildly in formatting. v1 handles common cases (clear column layouts, standard P&L structure); ambiguous layouts gracefully degrade to "couldn't parse the financials section — verification limited."
- **Don't accuse the seller of fraud.** Language matters. *"This figure doesn't reconcile to the P&L"* is right. *"The seller is misrepresenting SDE"* is wrong. Voice guide enforces.

## Why Free tier

- This is the **magnet feature**. The free analysis surfaces a real discrepancy → user says "holy shit" → user upgrades for QoE Bundle or unlimited analyses. Don't gate the thing that creates the conversion event.
- Also: it's the screenshottable moment. Every screenshot is free marketing. Don't friction that.

## What ships in v1

Source Verification ships in v1 as a core feature alongside the standard analysis. It's part of the launch story, not a fast-follow.
