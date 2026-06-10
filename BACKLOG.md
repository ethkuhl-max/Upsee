# Underight Backlog

Captured 2026-06-09. Organized by theme and priority tier. Detailed specs for the headline professional features live under `features/`.

## Tier definitions

- **v1** — required for first release (see `SPEC.md`)
- **v1.5** — fast-follow within ~30 days of launch
- **v2** — second major version
- **v3+** — long-term / network-effect plays
- **Pro** — paid Pro-tier feature (pricing deferred; structural placeholder)
- **Free** — magnet feature for the free / introductory tier

---

## Headline professional features (Pro tier candidates)

| # | Feature | Tier | Pricing | Spec |
|---|---------|------|---------|------|
| 1 | Lender Package generation | v1.5 | Pro | [features/01-lender-package.md](features/01-lender-package.md) |
| 2 | QoE Bundle (TTM + seasonality + working capital + customer concentration) | v2 | Pro | [features/02-qoe-bundle.md](features/02-qoe-bundle.md) |
| 3 | Source document verification (CIM ↔ P&L cross-check) | v1 | Free | [features/03-source-verification.md](features/03-source-verification.md) |
| 4 | Due Diligence Playbook + task tracking | v2 | Pro | [features/04-dd-playbook.md](features/04-dd-playbook.md) |
| 5 | SBA eligibility pre-check | v1.5 | Free | [features/05-sba-eligibility.md](features/05-sba-eligibility.md) |

---

## Diligence-grade features

- **TTM analysis** — Trailing twelve months SDE/revenue vs reported annual. Catches deteriorating businesses sellers list at peak. *(v2, Pro — part of QoE Bundle)*
- **Seasonality detection** — Month-over-month revenue pattern. Flags Q4-concentrated businesses where buyer Q1 cash needs are dramatically understated. *(v2, Pro)*
- **Working capital + cash conversion analysis** — DSO + DIO − DPO. Models the closing working capital peg. *(v2, Pro)*
- **Customer concentration (Pareto)** — Top-10% / top-20% revenue concentration from financials. Flag if top customer >25%. *(v2, Pro)*
- **Source document verification** — CIM ↔ P&L reconciliation. *(v1, Free — magnet feature)*
- **Add-back interrogation** — Per-add-back skeptical commentary with credibility weights. *(v1, included in SPEC)*

## Deliverables (Pro tier candidates)

- **Lender package** — SBA-ready Markdown→PDF: cover, exec summary, sources & uses, debt service, projections, risk factors, mitigants. *(v1.5, Pro)*
- **LOI generation** — Draft letter of intent with negotiation margin notes (where to give vs hold). *(v2, Pro)*
- **Annotated CIM export** — Source PDF re-exported with Underight margin notes and highlights. *(v1.5, all tiers)*
- **Audit trail / assumption log** — Every assumption, override, and AI-generated finding logged per deal. Critical for board/partner/lender defense. *(v2, Pro)*
- **Shareable Deal Card** — Polished verdict + key findings image sized for Twitter/X. The viral loop. *(v1, all tiers)*

## Structuring intelligence

- **SBA eligibility pre-check** — Business type, real estate concentration, foreign ownership, size standards, prior SBA loans. *(v1.5, Free)*
- **Multi-loan financing scenarios** — SBA + seller note + equity stacks. *(v1, in current spec via FinancingScenario model)*
- **Stock vs asset purchase modeling** — Tax implications for buyer (depreciation) and seller (capital gains). Win-win basis allocation. *(v2, Pro)*
- **Earn-out optimization** — Trigger metrics, caps, guarantee structures. *(v2, Pro)*
- **Synergy / improvement scenarios** — Model gross margin improvements, consolidations, etc. alongside base case. *(v2, Pro)*

## Voice / character / output quality

- **Branded skeptical voice guide** — System prompt + tone bible for the LLM. The voice IS the moat. *(v1, must-have before LLM client)*
- **"What would change my mind" section** — Per-verdict, what evidence would flip the call. Intellectual honesty as a feature. *(v1, prompt-level addition)*
- **Confidence levels per finding** — HIGH / MEDIUM / LOW tagging on every claim. *(v1, prompt-level addition)*
- **"This saved you $X" framing** — Output reminds user of value delivered (e.g., "Underight reduced your effective SDE by $48K → $144K change in defensible offer at 3x"). *(v1, output template)*

## Network-effect features (long game)

- **Private comparable transactions database** — Opt-in anonymized deal contributions build a real SMB comp set. The moat. Privacy positioning matches Tmpo's. *(v3, Pro — needs user volume first)*
- **Lender directory + matching** — Public + crowdsourced lender preferences. Match each deal to best 2–3 lenders. *(v2, Pro)*
- **Industry-specific deep packs** — HVAC, SaaS, restaurant, manufacturing, etc. Per-pack tech retention, NRR, lease analysis, customer concentration thresholds. *(v2, paid add-ons)*

## Post-LOI / DD companion

- **DD playbook with task tracking** — Standard 60–90 day phase template, per-deal task status, document checklist. The retention bridge feature. *(v2, Pro)*
- **R&W insurance modeling** (>$5M deals) — Cost, coverage, exclusions. *(v3, Pro)*
- **Closing checklist generator** — Bank accounts, employee notifications, vendor reassignments, lease assumptions, insurance binders. *(v2, Pro)*
- **CapEx requirement modeling** — Industry-specific implicit CapEx (HVAC trucks every 7 years, etc.) eating into SDE. *(v2, Pro)*

## Team / search-fund workspace

- **Multi-user with role-based access** — Searcher + investors. *(v2, Team tier ~$399/mo)*
- **Investor view-only mode** — Analyses visible without editing. *(v2, Team tier)*
- **Threaded comments per finding** — Discussion on specific concerns. *(v2, Team tier)*
- **Shared deal pipeline** — Team-wide active deal list. *(v2, Team tier)*

## Distribution / growth features

- **Shareable Deal Card export** — See "Deliverables" above. *(v1)*
- **Annotated CIM PDF export** — See "Deliverables" above. *(v1.5)*
- **Personal calibration over time** — App learns your taste in add-back skepticism, pre-applies your priors. Retention play. *(v2)*
- **Saved deals + revisit workflow** — `.underight` doc reopened weeks later, re-run with new numbers, compare to prior analysis. *(v1.5)*
- **Public "Deal of the Week"** — Anonymized real deal posted weekly with Underight analysis. Free marketing surface. *(post-v1, owner workflow)*
- **Referral mechanism** — Searcher refers another searcher, both get a free analysis. *(v1.5)*

## Power-user / advanced features

- **"Ask Underight" follow-up chat** — Post-analysis natural-language follow-up that re-runs the math. *(v1.5)*
- **Multi-financing comparison side-by-side** — SBA-only vs SBA+seller-note vs SBA+earnout. *(v1.5)*
- **Full 2D sensitivity grid** — Beyond the 4-row strip; revenue × rate. *(v1.5)*
- **Custom add-back categories with custom weights** — User-defined credibility for unusual categories. *(v2)*
- **Custom industry multiple overrides** — User tells the app HVAC in their market is 3.5x median, not 2.8x. *(v2)*
- **API / CLI for bulk analysis** — Power-user batch mode. *(v3)*
- **Voice input** — Talk through a deal, app captures and analyzes. *(v3)*
- **Per-deal "redact" mode** — Strip identifying info before LLM call (paranoid privacy mode). *(v2, Pro)*
- **BYO API key** — User supplies their own Anthropic key, no cost pass-through. *(v2)*

## Privacy

- **Local LLM mode** — mlx-swift / on-device model. "Your deals never leave your Mac." Tmpo-parallel privacy positioning. *(v2, Pro upgrade)*
- **Per-deal redact mode** — See above. *(v2, Pro)*
- **No-storage mode** — Explicit guarantee that no deal data is logged on Anthropic's side beyond prompt processing. *(v1, default behavior)*

---

## Cross-cutting decisions deferred

- **Pricing** — Pro tier exists structurally; concrete prices set on contact with users after v1 ships.
- **Tier surface in v1 UI** — v1 should *signal that Pro exists* (e.g., disabled "Generate Lender Package" button with "Pro" badge) even though Pro features ship in v1.5 / v2.
- **Comp database opt-in flow** — Architect data model to support opt-in contribution from day one even though comp surfacing is v3.
- **Multi-user data model** — Architect for it now (deal ownership, sharing) even though Team tier ships v2.
