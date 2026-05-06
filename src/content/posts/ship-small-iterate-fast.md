---
title: "Ship small, iterate fast: tiny redesign, big signal"
pubDate: "2026-05-06T17:17:00Z"
description: "Case study of a focused tiny redesign and the outcomes it unlocked."
tags: [case-study, design, ux]
readingTime: "6 min"
draft: true
slug: "ship-small-iterate-fast"
---

Small changes often produce the clearest signal. This case study walks through a tiny redesign shipped as a single PR: what we changed, why we scoped it that way, and how we measured impact.

Why scope small?

Large redesigns carry coordination overhead, long review cycles, and high risk. By contrast, a focused, well-scoped change is easier to review, faster to iterate on, and simpler to revert if it regresses. For content-driven sites, small visual and navigation improvements can yield measurable engagement gains without a full rewrite.

The problem

Our static site showed three small, high-impact issues:

- Inconsistent vertical rhythm across headings and paragraphs caused uneven reading flow.
- Dark-mode body text used a slightly desaturated blue that read as low contrast in some lighting.
- The blog link was nested inside a secondary menu, reducing discoverability.

The scope

To keep the PR reviewable, we limited changes to three files:

1. root CSS variables (spacing + color tokens)
2. theme CSS for dark mode color tweak
3. header/nav markup to promote the blog link

Implementation details

Spacing and rhythm

We introduced two variables: --sp-base (8px) and --sp-rhythm (calc(var(--sp-base) * 2)). They controlled margins on headings and paragraphs so a single token tweak propagated cleanly:

```css
:root { --sp-base: 8px; --sp-rhythm: calc(var(--sp-base) * 2); }
h1, h2, p { margin-top: var(--sp-rhythm); margin-bottom: var(--sp-rhythm); }
```

Dark-mode contrast

Rather than choose a pure white for body text, we picked #e6eef7 — slightly desaturated — to reduce glare while preserving a contrast ratio > 7:1 for normal text sizes. This small change improved legibility without altering the overall aesthetic.

Navigation

We promoted the blog link to a primary nav slot and added an underline-on-focus rule to improve keyboard discoverability. The markup change was one-line and the focus style was a 2-line CSS addition.

Testing and review

Because the PR touched CSS and nav markup, we ran the static site's smoke tests and the link-checker locally (linkinator) before opening the PR. We added a screenshot snapshot for the header to visually confirm the nav placement across breakpoints. The PR description included the rationale, a before/after screenshot, and a short QA checklist.

Outcomes

- The PR merged in under 24 hours after two quick reviews.
- Initial telemetry (first week) showed an ~18% increase in clicks to /blog and a 7% decrease in bounce on long-form posts.
- No regressions were reported in cross-browser smoke tests.

Lessons learned

- Small scope wins: keep PRs tightly focused and explain the user problem clearly in the description.
- Make tiny visual tokens reusable: spacing and color variables make future small adjustments trivial.
- Measure quickly: even simple telemetry (clicks, bounce, screenshots) helps validate assumptions.

Next steps

- Iterate on rhythm if longer-form posts still feel cramped.
- Continue to centralize tokens (typography, colors) so future tiny PRs stay small.

Takeaway

Ship a single, well-scoped change targeting a clear user problem. Fast iteration uncovers signal early and keeps the codebase healthy.
