# Feature: Due Diligence Playbook + Task Tracking

**Tier:** Pro
**Target:** v2
**Risk:** medium — risk of drifting into "we're a project management tool now"

## Goal

After a deal moves past LOI, the searcher enters a 60–90 day diligence period. Underight becomes their DD companion: standard phase-based playbook, per-deal task tracking, document checklist, status reporting. The retention feature — the natural bridge from "one-shot analysis" to "weekly active use during the live deal" without committing to the full post-close ownership scorecard.

## Why this matters

The post-LOI period is where searchers are most engaged and where most deals die. Currently they manage this in Notion / spreadsheets / Trello — none of which know anything about the underwriting they already did in Underight. Underight that *carries the underwriting forward into DD* is uniquely positioned. The DD playbook is what turns Underight from a tool the searcher uses for an hour per deal into one they open every weekday for two months.

## Playbook structure

Standard 5-phase template, adapted from search-fund community DD checklists:

1. **Initial DD (week 1–2)** — Confidentiality agreements, data room access, broker rapport, financial schedules requested.
2. **Financial DD (week 3–5)** — QoE / TTM verification, customer concentration deep-dive, working capital validation, expense quality, A/R aging review.
3. **Operational DD (week 4–7)** — Key person risk, employee interviews, systems and tech stack review, vendor/supplier relationships, site visit.
4. **Legal DD (week 6–9)** — Entity structure, contracts review, IP, litigation history, real estate / lease, regulatory compliance.
5. **Closing prep (week 8–12)** — Bank financing finalized, R&W insurance (if applicable), closing checklist, transition plan.

Each phase carries 8–20 default tasks. Industry-specific add-ons layer on top (HVAC adds licensing review; restaurant adds health permits; etc.).

## Per-task fields

- Title, description, status (Not started / In progress / Verified / Blocked / N/A)
- Owner (default: searcher; can assign to broker, accountant, lawyer)
- Due date (auto-calculated from LOI date + phase offset; user overrides)
- Notes
- Linked documents (attached files or links into the data room)
- Blockers / outstanding questions

## Document checklist

Parallel surface: what we need from the seller. Pre-populated by industry. Each item: requested / received / verified status, source link.

## Output / reporting

- **DD dashboard** per deal — phase progress bars, tasks by status, overdue flags.
- **Weekly DD status email** — auto-draft summary for partners/investors. Phase status, key findings, outstanding blockers, next-week focus.
- **DD report** at close — full summary of everything verified, with links to source documents. Lives alongside the underwriting and the lender package as the deal's permanent record.

## UI surface

- New "DD" tab on a saved `.underight` deal (only enabled after marking the deal as "LOI Signed" — explicit state transition).
- Tabbed view: Tasks / Documents / Findings / Reports.
- Visible across the analysis and DD views: deal status badge (Analyzing / LOI Signed / In DD / Closing / Closed / Dead).

## Dependencies

- Saved-deals workflow (v1.5)
- Multi-state deal model (v1.5)
- LLM client for weekly status email drafts (week 2)
- Industry packs (for phase 1/2/3 task customization — v2)

## Risks / traps

- **PM-tool drift.** This must NOT become Asana for SMB diligence. The right scope is "what's specifically valuable because we know the underwriting" — auto-populated task lists from the deal type, broker questions linked back to source PDF, status emails that reference the original verdict. Avoid: priority schemes, custom workflows, Gantt charts, dependency graphs.
- **Notion / Trello competition.** Some users will already have a DD system. Don't fight that. Add value with the things only Underight can do (carry underwriting forward, generate status reports referencing the analysis, link tasks back to PDF citations). Let them export and ignore the tracking part if they want.
- **Closing-tier feature creep.** Real closing-prep tasks (escrow, wire instructions, etc.) touch real money. Be very clear that Underight tracks status; the buyer's attorney is responsible for execution. No money movement, no document execution from inside the app.
- **State transitions can't be reversed.** If a searcher marks a deal "Dead" by accident, recovery should be easy. Soft-delete state, not hard-delete.

## What ships in v1

Nothing functional. v1 ships with the `.underight` document model architected to support a status field, but no DD tab and no playbook. v2 lights it up.
