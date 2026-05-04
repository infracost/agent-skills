# Infracost AI — Landing Page

Static landing page for the Infracost AI Claude Code skill. Built with Astro, deployed to GitHub Pages.

## Local Development

```bash
# Install dependencies
npm ci

# Start dev server (hot reload)
npm run dev

# Build for production
npm run build

# Preview production build locally
npm run preview
```

## Testing

```bash
# Run E2E tests (requires production build)
npm run build && npm run test:e2e

# Run with headed browser
npm run test:e2e:headed

# Type check
npm run astro:check
```

## Project Structure

```
/
├── public/
│   ├── fonts/          # Self-hosted font files (Inter + JetBrains Mono)
│   ├── images/         # Static images (og-image.png, logos, etc.)
│   └── CNAME.example   # Copy to CNAME when custom domain is ready
├── src/
│   ├── components/     # Reusable Astro components
│   ├── layouts/        # Page layout templates (BaseLayout.astro)
│   ├── pages/
│   │   └── index.astro # Main landing page
│   └── styles/
│       └── global.css  # Design tokens + global resets
├── tests/e2e/          # Playwright E2E test specs
├── scripts/            # Dev utility scripts
├── specs/              # Feature specifications
├── docs/               # Architecture notes and planning docs
├── .github/workflows/  # CI and deploy pipelines
├── astro.config.mjs
├── playwright.config.ts
└── package.json
```

## Deployment

**Automatic:** Merging to `site` triggers the GitHub Actions deploy workflow, which builds and deploys to GitHub Pages.

**GitHub Pages setup (one-time):**

1. In repo Settings → Pages, set source to "GitHub Actions"
2. Ensure Actions have Pages write permission

**Custom domain:**
The custom domain is configured via `public/CNAME`. `astro.config.mjs` defaults to `https://cost.dev` with `/` as the base path.

## Icon Strategy

Icons use inline SVG paths sourced from [Heroicons](https://heroicons.com) (MIT license). No icon package is required — SVG paths are copied directly into components. The four launch icons are: tag, lightning bolt, currency dollar, and shield check.

## Environment Variables

| Variable     | Default                       | Description                                                    |
| ------------ | ----------------------------- | -------------------------------------------------------------- |
| `ASTRO_SITE` | `https://cost.dev` | Full URL of deployed site                                      |
| `ASTRO_BASE` | `/`                | Base path (set to `/agent-skills` for GitHub project Pages)    |
