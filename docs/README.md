# BP Mobile Documentation

SvelteKit documentation site for ESP32 connection guides and WebSocket protocol reference.

## Development

```bash
npm install
npm run dev
```

## Building for Production

```bash
npm run build
npm run preview
```

## Deployment

This site is automatically deployed to GitHub Pages via GitHub Actions when changes are pushed to the `main` branch.

### Manual Deployment

If you need to deploy manually:

1. Build the site:
   ```bash
   npm run build
   ```

2. The built files will be in `docs/build/`

3. Push to the `gh-pages` branch (if using that method) or let GitHub Actions handle it

## Documentation Pages

- `/docs/getting-started` - Quick start guide
- `/docs/connection` - Detailed connection instructions
- `/docs/protocol` - WebSocket protocol reference
- `/docs/examples` - Code examples and Arduino sketches

All documentation is written in Markdown and rendered using mdsvex.

## Configuration

- **Base Path**: `/BP_mobile` (configured for GitHub Pages)
- **Adapter**: `@sveltejs/adapter-static` (static site generation)
- **Styling**: Tailwind CSS with custom colors matching Flutter app
- **Fonts**: Bricolage Grotesque Variable (sans-serif), Maple Mono (monospace)
