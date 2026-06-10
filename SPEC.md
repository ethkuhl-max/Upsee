# Underight — v1 spec

**Locked 2026-06-09. Status: scaffolding. Mac-first. Pricing deferred.**

## Wedge

A Mac app that gives SMB buyers a brutally honest second opinion on a deal before they write the LOI. Drag in a CIM, get back a skeptical underwriting with the math the seller didn't do.

Promise in one line: *"The second opinion every SMB buyer wishes they had."*

## The killer flow

1. Drag a CIM PDF onto the dock icon (or a drop zone in the main window).
2. App parses what it can deterministically — asking price, claimed SDE, listed add-backs, industry, geography, basic financials.
3. **Deal Card** appears: structured, inline-editable, side-by-side with the source PDF. User confirms / corrects extraction.
4. Click **Analyze**.
5. Deterministic math runs first (~instant): DSCR scenarios, normalized SDE, multiple sanity, max defensible offer.
6. LLM analysis runs second (~10–20 sec): qualitative add-back review, business model risks, what's missing from the CIM, industry red flags, questions to ask on the broker call.
7. Output: a single scrollable **Analysis Document** with citations back into the source PDF.

## Output structure

One screenshottable document, multi-section:

- **Verdict** — Tailwind-style headline. *"At asking, this is a PASS. DSCR 0.96. To pencil at 1.25, offer ≤ $620K."*
- **The numbers** — extracted terms, normalized SDE with add-back skepticism table, DSCR at three loan scenarios, multiple vs industry median, sensitivity tables.
- **Skeptical review** (LLM) — what the seller is hiding, what's missing from the CIM, business-model concerns, concentration risks.
- **Questions for the broker** (LLM) — concrete numbered list. The section users will screenshot before their call.
- **Citations** — every finding links back to a highlighted region in the source PDF.

## Architecture split — deterministic vs LLM

**Deterministic (Swift, no LLM):**
- SDE normalization with add-back credibility weights (0–1 per add-back)
- DSCR at multiple SBA loan terms (rate + amortization)
- Multiple comparison vs industry median lookup (~30 SIC categories for v1)
- Max offer for target DSCR (solve backwards)
- Sensitivity: revenue −10%/−20%, rate +100bps, etc.

**LLM (Claude Sonnet 4.6 via API):**
- Per-add-back qualitative skepticism
- Missing-information audit
- Business model risk read
- Customer / supplier concentration questions
- Industry-specific red flag check
- Question generation for the broker call

Multiple narrow prompts, structured JSON outputs, one per section. Not one kitchen-sink prompt.

## Tech stack

- SwiftUI multi-platform, **Mac only as v1 build target**, `#if os(macOS)` for Mac-specific affordances
- XcodeGen — vendored `.tooling` binary, same pattern as Tailwind / Driver.Co (no Homebrew)
- PDFKit for parsing + visual citation highlighting
- **Apple Foundation Models (on-device)** as the v1 LLM — `SystemLanguageModel.default` via `LanguageModelSession`. No API key, no network round-trip, no per-deal cost, and *"your deals never leave your Mac"* is the v1 default. Trade-off: on-device ~3B model is meaningfully less sharp on qualitative voice than a frontier remote model. Architecture leaves room to swap in a remote model (Anthropic Sonnet 4.6) as a Pro upgrade later.
- StoreKit 2 (Mac App Store) and direct DMG / Sparkle for direct distribution
- File-based persistence — each deal saved as a `.underight` document (JSON under the hood). No backend, no accounts.

## v1 scope — the cuts

- ❌ Deal library / pipeline view (one deal at a time, save as file)
- ❌ Spreadsheet drag-in (PDF only in v1)
- ❌ Local LLM mode (API only in v1)
- ❌ Export analysis to PDF (in-app document only in v1)
- ❌ Industry deep-dive rules (one general red-flag pass in v1)
- ❌ Pricing logic (deferred — ship the build, decide pricing on contact with users)
- ❌ iOS / iPad build (Mac only in v1)

## v2 carrots (priority order)

1. Local LLM mode ("your deals never leave your Mac" — privacy upgrade)
2. Deal pipeline view (tagged watching / passed / LOI / DD / closed)
3. Spreadsheet + Excel drag-in
4. PDF export of the analysis
5. Industry-specific red-flag packs (HVAC, laundromat, services SMBs)

## Pricing tier structure (deferred prices, structural placeholder)

Three tiers planned. Prices set on contact with users after v1 ships.

- **Free** — Magnet tier. Limited analyses or watermarked output. Includes Source Verification ([features/03](features/03-source-verification.md)) and SBA Eligibility ([features/05](features/05-sba-eligibility.md)) in full — these are conversion features, never gated.
- **Personal** — For individual searchers. Unlimited analyses, Shareable Deal Card export, voice/character output in full, branded voice guide active.
- **Pro** — For professional searchers / search funds / acquisition associates. Adds Lender Package ([features/01](features/01-lender-package.md)), QoE Bundle ([features/02](features/02-qoe-bundle.md)), DD Playbook ([features/04](features/04-dd-playbook.md)), audit trail, multi-financing comparison, sensitivity grid, custom industry overrides.

**v1 surfaces the Pro tier visually** (disabled features with "Pro" badge) even though Pro features ship in v1.5 / v2. This sets the tier hierarchy at launch.

## Backlog

Full feature backlog organized by theme and tier lives in [BACKLOG.md](BACKLOG.md). Per-feature one-pagers under [features/](features/).

## Distribution

- Mac App Store + direct DMG (both)
- Mac App Store: discovery
- Direct DMG: workflow freedom outside the sandbox + the "Show HN" crowd that hates the sandbox

## Launch channels

1. Acquisitions Anonymous (Slack + podcast outreach)
2. Searchfunder forum
3. Show HN — Mac native + AI + niche financial tool resonates here
4. Product Hunt
5. ETA Twitter / X — Codie Sanchez orbit, search-fund Twitter
6. /r/EntrepreneurRideAlong, /r/smallbusiness (secondary)

## Milestones (AI-paired)

- **Week 1** — Scaffold (XcodeGen, multi-platform SwiftUI, main window, drop zone), deterministic deal-math engine + unit tests, PDF text extraction working end-to-end.
- **Week 2** — Deal Card UI with inline edit, extraction wiring, LLM prompt templates per analysis section, output document UI rendering structured analysis.
- **Week 3** — End-to-end happy path: drop PDF → analysis → output document. Polish, error handling, edge cases, source-PDF highlighting on citations.
- **Week 4** — Pricing decision + StoreKit, notarization + signing, DMG packaging, landing page, Show HN draft.
- Ship end of week 4 or early week 5.

## Risks

- **LLM analysis quality.** The product *is* the LLM being convincingly skeptical. Bad prompts = toy. Plan to iterate prompts in week 2 against 5–10 real CIMs (BizBuySell archives, Acquisitions Anonymous show notes are public sources).
- **First Mac app.** Notarization, sandboxing, document-based app architecture — learning curve. SwiftUI multi-platform flattens most of it; budget half a week of slack.
- **"I could do this in Excel."** Answer: the qualitative review and broker-questions sections are what they can't do in Excel. Make those genuinely good.
