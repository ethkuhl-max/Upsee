# Feature: QoE Bundle

**Tier:** Pro
**Target:** v2
**Risk:** high — requires richer financial data input than v1's CIM-only flow

## Goal

Underight performs the 80/20 of a Quality of Earnings engagement: TTM analysis, seasonality detection, working capital cycle, customer concentration. Together these turn Underight from "calculator" into a tool that does real diligence work. The features that most distinguish a professional underwriter from an amateur.

A full QoE costs $15–30K and takes 4–6 weeks. The QoE Bundle is what a searcher uses to decide *whether to even commission a full QoE*. It's the pre-screen.

## Four sub-features

### TTM analysis

- Trailing twelve months SDE/revenue vs the reported annual.
- Catches deteriorating businesses sellers list at peak performance year.
- Output: TTM vs LTM (last calendar year) comparison, trend direction, % deviation flag.
- Requires: monthly P&L for at least 24 months (so we can compute both periods).

### Seasonality detection

- Month-over-month revenue pattern with normalized index (100 = average).
- Flag businesses with high seasonality (>30% deviation from average in peak month).
- *Buyer Q1 cash needs are dramatically understated if 70% of revenue lands Q4.*
- Output: 12-month seasonal index chart + commentary on cash flow implications.

### Working capital cycle

- DSO (days sales outstanding) + DIO (days inventory outstanding) − DPO (days payable outstanding).
- Models the closing working capital peg — the hidden killer of SMB deals.
- Output: cash conversion cycle in days, implied working capital requirement, comparison to "normalized" working capital per industry.
- Requires: balance sheet for current period.

### Customer concentration (Pareto)

- Pull top-10% / top-20% customer revenue concentration.
- Flag if top customer >25% of revenue or top-3 >50%.
- Generate specific broker questions: *"What's the contractual term and renewal status on top customer X?"*
- Output: concentration chart + risk-flagged commentary.
- Requires: customer revenue table (often available as a CIM appendix or requested from broker).

## Implementation approach

- **New input surface:** "Add Detailed Financials" step in the deal flow. Supports CSV upload, paste from spreadsheet, or Excel/Numbers drag-in.
- **Schema:** monthly P&L + balance sheet + customer revenue table as structured `FinancialPack` model.
- **Deterministic math** in Swift for TTM/seasonality/cash conversion/concentration calcs.
- **LLM commentary** layer on top, narrowly scoped per sub-feature.
- **Output:** each sub-feature renders as its own section in the analysis document; collectively they form the "QoE Pre-Screen" section.

## UI surface

- New input step: "Have detailed financials? Add them for QoE-grade analysis (Pro)" — surfaces above the standard CIM-only analysis path.
- Pro badge visible in free tier; click → upgrade flow.
- QoE section appears in `AnalysisDocumentView` when the data is present.

## Dependencies

- `AnthropicClient` (week 2)
- Spreadsheet/CSV parsing infrastructure (new, v1.5+)
- `FinancialPack` schema + storage (new, v2)
- Pro tier gating

## Risks / traps

- **Data quality.** Garbage in = garbage out. If the user uploads a bad spreadsheet, the QoE output is worthless. Validation: explicit column matching UI, required-field flags, "we couldn't parse this — what is this column?" interactive cleanup.
- **Industry variance.** "Normalized" working capital varies hugely by industry. v2 launches with general benchmarks; v2.5 adds industry-specific norms.
- **Scope creep into full QoE.** This is the 80/20. Don't try to be the 100/0 replacement for a real QoE — Underight's value is in catching what would kill the deal, not in being the official document a buyer hands to a lender.
- **CIM-only flow regression.** Most users will not have the financial pack. v1 CIM-only flow must remain fully functional and not regress when QoE is added.

## What ships in v1

Nothing functional. v1 launches CIM-only. QoE Bundle is the v2 headline upgrade.
