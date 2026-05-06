---
title: "TDD for content & UI: tests for a static blog"
pubDate: "2026-05-06T17:17:00Z"
description: "Why tests matter even for static content and a practical link-checking setup."
tags: [testing, ci, content]
readingTime: "7 min"
draft: true
slug: "tdd-for-content-ui"
---

Tests aren't just for application logic. For a static blog, regressions come from broken links, missing assets, and layout shifts introduced by CSS changes. Treat content as code: write tests that exercise the things readers rely on and make small changes safe to ship.

What to test

- Link validity (internal and external)
- Frontmatter presence and required fields
- Basic accessibility smoke checks (alt on images, heading order)
- Build output sanity (no orphaned 404 pages, expected routes)
- Visual snapshots for critical UI like the header/nav and article layout

Test tooling and flow

The fastest guardrail is a link checker that runs after your static build. You should also add a frontmatter lint step and a couple of lightweight accessibility checks. Keep tests fast — a slow pipeline discourages iteration.

Example: link checks with linkinator

Install as a dev dependency and run against the published output directory. This catches 404s, malformed URLs, and server errors from external sites:

```bash
npm install --save-dev linkinator
npm run build # produces ./public or ./dist depending on your setup
npx linkinator ./public --concurrency 10 --timeout 5000 --failLevel error
```

This fails CI on link-level errors. To avoid flakiness from transient external failures, consider:

- caching results for external domains
- treating external-only failures as warnings on the first failure and failing only on persistent errors
- maintaining a small allowlist of known flaky domains

Frontmatter linting

Frontmatter fields are contract points between authoring and rendering. A missing or malformed pubDate, for example, can break RSS generation or sorting. A minimal Node script using front-matter will keep you honest:

```js
const glob = require('glob');
const fm = require('front-matter');
const fs = require('fs');

const required = ['title','pubDate','description'];

glob.sync('src/content/posts/**/*.md').forEach(file => {
  const raw = fs.readFileSync(file,'utf8');
  const { attributes } = fm(raw);
  required.forEach(k => { if (!attributes[k]) throw new Error(`${file} missing ${k}`); });
  if (isNaN(Date.parse(attributes.pubDate))) throw new Error(`${file} has invalid pubDate`);
});
```

Accessibility & visual checks

Run a couple of axe-core rules against a headless build snapshot or add `eslint-plugin-jsx-a11y` if your site generates React code. Small automated checks to include:

- images have alt text
- form controls are labelled
- headings increase logically (H1 → H2 → H3)

Add a visual snapshot for the header and article template using a tiny puppeteer script or Playwright. If the header/nav changes unexpectedly in a PR, the snapshot diff is a fast signal.

CI integration suggestions

- Execute linters and frontmatter checks in parallel to keep runtime low.
- Run link checks after build but before publishing artifacts (so failures block merges).
- Keep external checks optional or run them in a separate stage that can be retried without blocking faster unit-style checks.

Handling false positives and flaky external links

- Provide a `--allow` file for known flaky external links and mark them as warnings.
- Offer a quick triage workflow: when a link check fails, open an issue that references the PR and mark it for follow-up.

Why this matters

Content regressions are visible and erode trust quickly. Tests keep the author flow fast — they surface problems before a PR is merged and make small changes low-cost. A lean test suite (link checks + frontmatter + minimal accessibility) catches most content problems and keeps CI green without slowing down contributors.

Actionable checklist for maintainers

- [ ] Add link check step after build
- [ ] Add frontmatter linting step
- [ ] Add a visual snapshot for header and article page
- [ ] Configure external-link policy (fail/warn)

Takeaway

Treat your blog's content pipeline like code: minimal, fast tests surface real problems early and protect the reader experience while preserving a rapid edit → review → merge loop.
