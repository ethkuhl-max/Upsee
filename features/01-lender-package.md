# Feature: Lender Package generation

**Tier:** Pro
**Target:** v1.5
**Risk:** medium (templating drift, multi-format support temptation)

## Goal

After an analysis completes, the user clicks "Generate Lender Package" and Underight produces a real SBA lender-ready document the searcher can attach to a lender outreach email. This is the single highest-value Pro feature. Searchers currently pay consultants $3–15K for this exact deliverable.

## Why this matters

The lender package is the deliverable that wins SBA approval. A searcher shops it to 3–5 SBA lenders to get terms. If Underight produces a credible package, the app moves from "calculator" to "the tool I use to actually close deals." That alone justifies a $99+/mo Pro tier.

## Output sections

1. **Cover sheet** — Borrower (buyer LLC), target business, requested loan amount, deal date.
2. **Executive summary** — 1 page. Business overview, why this deal makes sense, buyer credentials, financing structure. LLM-generated narrative on top of deterministic deal data.
3. **Sources & uses** — Table. Where the money comes from (SBA loan, seller note, buyer equity), where it goes (purchase price, working capital, closing costs, reserves).
4. **Debt service schedule** — Monthly amortization for the SBA loan + any seller note. Auto-generated from `LoanEngine`.
5. **5-year projection** — Base case revenue and SDE projection. Conservative growth assumption (default 2%/year for SDE; user can override). DSCR by year.
6. **Risk factors** — LLM-generated. The standard SBA risk-factor categories (customer concentration, key person, market, regulatory, etc.) tailored to this specific deal.
7. **Mitigants** — LLM-generated. What the buyer has done or plans to do to address each risk.
8. **Appendix** — Deal math worked, source CIM page references, assumption log.

## Implementation approach

- **Format:** Markdown source → PDF rendering via `WebKit` (HTML/CSS intermediate) or native PDFKit composition. **Not Word, not DOCX, not Pages.** Lean into Markdown's constraints — the templating burden grows non-linearly with format support.
- **Deterministic templating** for sources & uses, debt service schedule, projections, appendix.
- **LLM-narrative** for executive summary, risk factors, mitigants. Three distinct prompts, each with its own structured output schema.
- **Branded styling** — clean serif body, monospace numbers, simple Underight wordmark. No clip art, no "designed in Canva" energy. Lenders trust documents that look like documents.

## UI surface

- "Generate Lender Package" button in `AnalysisDocumentView` (disabled in free tier with Pro badge).
- Click → progress sheet → preview window → save to disk or open in Preview.app.
- Optional: save the generated package alongside the `.underight` deal file as `[business-name]-lender-package.pdf`.

## Dependencies

- `AnthropicClient` (week 2)
- Output document rendering pipeline (week 2)
- Markdown → PDF infrastructure (new, v1.5 work)
- Pro tier gating mechanism (new, v1.5 work)

## Risks / traps

- **Format creep.** The first request from a power user will be "can it export to Word so I can edit?" — say no. The package is a deliverable, not a draft. If they want to edit, they generate again with adjusted inputs.
- **Templating brittleness.** Don't build a configurable template system. One template, opinionated, branded. v2 can add "second template variant" if needed.
- **LLM hallucinating risk factors.** Constrain the LLM with a fixed list of standard SBA risk categories; LLM only fills in deal-specific instances within each category. Don't let it invent new risk categories.
- **Lender variance.** Different SBA lenders prefer different package formats. v1.5 ships one Underight-opinionated format. Lender-specific variants are v3 territory (lives with the Lender Directory feature).

## What ships in v1

Nothing functional — but the **UI surface ships** (disabled button + Pro badge) to signal the Pro tier exists from launch.
