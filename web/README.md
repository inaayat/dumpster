# Dumpster Web

The Dumpster macOS + iOS apps rebuilt as a web app: a Next.js PWA that lives
behind the same user accounts as [inaayat.xyz](https://inaayat.xyz) (Neon
Auth) and stores everything in the same Neon Postgres database. Works great
on desktop and installs to the home screen on mobile.

## What's in v1

- **Daily Dump** — auto-bulleted editor, inline-colored `#tags`, tag
  autocomplete (Tab accepts), magic tags processed on Enter:
  `#action` `#prio` `#backlog` `#brainstorm` `#resource` `#win` `#save`
  `#delete`, plus auto-resource for bare URLs. Attention bar shows
  high-priority + overdue items. Past days expandable below.
- **Items** — All/Actions/Brainstorms/Resources tabs, high-prio and
  completed toggles, group-by-tag with collapse, "New" section for items
  created in the last 24h, quick add, full edit sheet (tags via `#` in the
  title, due date, notes, URL).
- **Tags** — hierarchy (sub-tags), rename (rename onto an existing tag
  merges, updating hashtags inside dumps/docs too), merge, delete; tag
  detail shows linked items + dump bullets + its Master Doc.
- **Master Docs** — the iOS multi-tag model: a doc owns several tags, all
  tagged items and dump bullets flow into its **Inbox**, and you add each
  entry under a chosen `##` heading (or the end). Markdown editor with
  preview, section chips, add-section.
- **Wins** — chronological brag doc (macOS feature), fed by `#win` or
  logged directly, with optional artifact URLs.
- **Backup** — export/import in the exact iOS `AppBackup` JSON shape, so an
  iOS export restores here (legacy RTF doc content converts on import) and
  a web export restores on iOS.
- **PWA** — manifest + service worker (app shell cached, data always live,
  offline fallback page).

Deliberately not in v1 (the API is shaped so these can be added):
AI dump analysis / doc placement / synthesis (add an `ANTHROPIC_API_KEY`
route later — magic tags cover manual flow), voice capture, widgets.

## Architecture

```
web/
├── public/                    # manifest, service worker, icons
└── src/
    ├── lib/
    │   ├── types.ts           # domain types (mirror the Swift models)
    │   ├── magic.ts           # bullet parsing + magic-tag rules (isomorphic)
    │   ├── markdown.ts        # doc headings, insert-under-heading, RTF import
    │   ├── client/
    │   │   ├── auth.tsx       # Neon Auth provider (browser)
    │   │   └── api.ts         # typed fetch + SWR hooks + mutations
    │   └── server/
    │       ├── db.ts          # Neon client + self-provisioning schema
    │       ├── auth.ts        # JWT verify (jose/JWKS) + withAuth wrapper
    │       ├── store.ts       # all queries (the web Queries.swift)
    │       ├── processor.ts   # magic-tag processing (ported from Swift)
    │       └── backup.ts      # iOS-compatible export/import
    ├── app/
    │   ├── api/               # route handlers (thin; call into lib/server)
    │   └── …                  # pages: / items tags docs wins settings
    └── components/            # AppShell, dump editor, cards, modals, ui kit
```

- **Auth**: the browser signs in against the hosted Neon Auth service
  (`/api/auth-config` hands out the URL at runtime) and sends a Bearer JWT
  with every API call; the server verifies it statelessly against the
  service's JWKS — the same pattern as inaayat.xyz's `lib/neon-auth.js`.
- **Data**: all tables are `dumpster_*`, keyed by `user_id`, in the shared
  Neon database; the schema provisions itself on first request (same
  philosophy as the site's `lib/db.js`). `/api/me` upserts into the shared
  `users` table so rows join back to a known account.
- **Magic tags** run server-side (one `POST /api/dumps/:date/process` per
  completed line) so the rules live in exactly one place.

## Deploy (Vercel)

This folder sits alongside the native macOS app (repo root); Vercel only
cares about `web/` and skips builds for commits that don't touch it
(`ignoreCommand` in `vercel.json`).

1. **New Vercel project** → import `inaayat/dumpster`, set
   **Root Directory** to `web/`. Framework auto-detects as Next.js. Every
   push to the production branch then auto-deploys; other branches get
   preview URLs.
2. **Environment variables** (same values as the inaayat.xyz project):
   - `DATABASE_URL` — the Neon Postgres connection string
   - `NEON_AUTH_BASE_URL` — the Neon Auth service URL
3. **Domain**: add `dumpster.inaayat.xyz` to the project (Vercel gives you
   the CNAME; add it wherever inaayat.xyz's DNS lives).
4. Push to `main` → deploys. No migrations to run — tables create
   themselves on first authenticated request.

## Local development

```bash
cd web
npm install
DATABASE_URL=... NEON_AUTH_BASE_URL=... npm run dev
```

Without the env vars the app boots into a "not configured" screen and every
API route returns 503 with a clear message.

## Importing your iOS data

iPhone: Dumpster iOS → Backup & Restore → Export → share the JSON to
yourself. Web: Settings → Import JSON. The import **replaces** all web data
(same semantics as the iOS restore).
