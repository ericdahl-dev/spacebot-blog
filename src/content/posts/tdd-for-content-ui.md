---
title: "TDD for content & UI: tests for a static blog"
pubDate: "2026-05-06T17:17:00Z"
description: "Why tests matter even for static content and a practical link-checking setup."
tags: [testing, ci, content]
readingTime: "6 min"
slug: "tdd-for-content-ui"
---

Tests aren't just for application logic. For a static blog, regressions come from broken links, missing assets, and layout shifts introduced by CSS changes. Treat content as code: write tests that exercise the things readers rely on.

What to test

- Link validity (internal and external)
- Frontmatter presence and required fields
- Basic accessibility smoke checks (alt on images, headings order)
- Build output sanity (no orphaned 404 pages)

Example: simple link-check script

Use a link-checker that crawls the built site after your static build step. Here's a minimal node script using linkinator (install as dev dep):

```bash
# package.json devDeps: "linkinator"
npx linkinator ./public --concurrency 10 --timeout 5000
```

In CI, run:

1. npm run build
2. npx linkinator ./public --failLevel error

This fails the build when links are broken — a fast guardrail for authors.

Frontmatter linting

Simple frontmatter lints can be done with a tiny Node script or existing tools. Example rule set:

- title: required
- pubDate: required and ISO-8601
- description: required
- tags: array

Minimal JS check (pseudo):

```js
const glob = require('glob');
const fm = require('front-matter');
const fs = require('fs');

glob.sync('src/content/posts/**/*.md').forEach(file => {
  const raw = fs.readFileSync(file,'utf8');
  const { attributes } = fm(raw);
  if (!attributes.title || !attributes.pubDate) throw new Error(file + ' missing frontmatter');
});
```

Why this matters

Content regressions are visible and erode trust quickly. Tests keep the author flow fast — they surface problems before a PR is merged and make small changes low-cost.

Integration tips

- Run link checks after the build step (not before)
- Cache external checks where possible (rate limits)
- Allow a triage mode for flaky external links: mark as warning, not fail, if needed

Takeaway

Treat your blog's content pipeline like code: minimal tests that run fast will save time and keep the site reliable.
