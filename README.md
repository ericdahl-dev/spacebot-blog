# Spacebot Blog (Astro)

## Setup

```bash
npm install
npm run dev
```

## Build for GitHub Pages

```bash
npm run build
```

Output is in `dist/` and configured for `/spacebot-blog` base path.

## Deploy

Uses GitHub Actions to deploy automatically.

## Structure

- `src/content/blog` - markdown posts
- `src/pages` - routes
- `src/layouts` - layouts
- `public` - static assets

## Notes

- `/projects` directory should remain untouched
- Base path is `/spacebot-blog`
