# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Mentoria is a full-stack mentorship marketplace platform (mentor/mentee matching, booking, payments, real-time messaging). It is a **pnpm monorepo** with two packages: `server` (Express + MSSQL) and `client` (React + Vite), orchestrated via Turborepo.

## Commands

### Root (run from repo root)
```bash
pnpm dev          # Run client + server concurrently in dev mode
pnpm build        # Build both packages
pnpm lint         # Lint all packages via Turbo
pnpm lint:fix     # Auto-fix lint errors
pnpm format       # Check formatting
pnpm format:fix   # Auto-format code
pnpm clean        # Remove build artifacts
```

### Server (`packages/server` or prefix with `--filter server`)
```bash
pnpm --filter server dev         # nodemon with TypeScript (auto-reload)
pnpm --filter server build       # tsc + copy assets + tsc-alias path resolution
pnpm --filter server seed        # Seed database (tsx src/scripts/seed.ts)
pnpm --filter server seed:slot   # Generate mentor availability slots
pnpm --filter server bundle:swagger  # Bundle OpenAPI YAML specs
pnpm --filter server debug       # nodemon with --inspect on port 9229
```

### Client (`packages/client` or prefix with `--filter client`)
```bash
pnpm --filter client dev         # Vite dev server (port 5173)
pnpm --filter client build       # TypeScript check + Vite build
pnpm --filter client start       # Preview production build
pnpm --filter client sitemap     # Generate sitemap
```

### Commit conventions
Commits are enforced via `commitlint` with Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `chore`, etc.). The pre-commit hook runs lint-staged.

## Architecture

### Monorepo structure
```
mentoria-dbms/
├── server/          # Express.js + TypeScript backend
├── client/          # React 19 + Vite frontend
├── turbo.json       # Turborepo task graph
├── pnpm-workspace.yaml
└── docker-compose.yml
```

### Server: Layered architecture
```
Routes → Controllers → Services → Database (raw SQL via mssql driver)
```
- **`src/routes/`** — 17 feature modules mounted in `index.ts`
- **`src/controllers/`** — Thin request handlers; delegate all logic to services
- **`src/services/`** — Business logic with direct SQL queries; use `sql.ConnectionPool`
- **`src/database/`** — Raw SQL files: `SQL.sql` (26-table schema), `trigger.sql`, `procedure.sql`, `function.sql`, `INSERT_DATA.sql` (seed data)
- **`src/validation/`** — Zod schemas for request input validation
- **`src/socket/`** — Socket.IO real-time messaging and notifications
- **`src/middlewares/`** — JWT auth, Multer file upload, Prometheus metrics, IP whitelist
- **`src/mailtrap/`** — Nodemailer email templates
- **`src/openapi/`** — Swagger/OpenAPI YAML docs served at `/api-docs`

There is **no ORM** — all database access is raw SQL. Path alias `@/` maps to `src/`.

### Client: React SPA
- **`src/pages/`** — Role-based views organized under `admin/`, `mentee/`, `mentor/`, `public/`
- **`src/store/`** — Zustand stores: `useAuthStore`, `useBookingStore`, `useMeetingStore`, `useSearchStore`, `useSlotStore`
- **`src/apis/`** — Axios wrappers for each backend resource (interceptors handle token refresh)
- **`src/components/`** — Shared UI components
- Routing via React Router v7; styling via Tailwind CSS v4 + Framer Motion

## Database Setup

Database: **Microsoft SQL Server 2022** (no migration tool — manual SQL execution).

**First-time setup:**
1. Set `DB_INIT=true` in `server/.env` — the server will auto-execute the SQL files on startup
2. Or manually run `server/src/database/SQL.sql` → `trigger.sql` → `procedure.sql` → `function.sql` in SSMS
3. Seed data: run `INSERT_DATA.sql` manually or `pnpm --filter server seed`
4. Generate slots: `pnpm --filter server seed:slot`

**Schema changes** require manual SQL updates to the relevant files in `src/database/`.

## Environment Variables

Copy and fill in both env files before running:
```bash
cp server/.env.example server/.env
cp client/.env.example client/.env
```

Key server variables: `DB_USER`, `DB_PASS`, `DB_SERVER`, `DB_NAME`, `DB_INIT`, `JWT_SECRET` (min 32 chars), `CLIENT_URL`, `GOOGLE_CLIENT_ID/SECRET`, `CLOUDINARY_*`, `STRIPE_SECRET_KEY/PUBLIC_KEY/WEBHOOK_SECRET`, `GEMINI_API_KEY`, `MAIL_USER/PASS/SEND`.

Client: `VITE_API_ENDPOINT=http://localhost:3000`

## Key Integrations

| Integration | Purpose |
|---|---|
| Google OAuth (Passport.js) | Social login |
| Stripe | Subscription plans, checkout, webhooks |
| Cloudinary | Profile images, CV uploads (via Multer) |
| Socket.IO | Real-time messaging & notifications |
| node-cron | Hourly meeting reminder jobs |
| Google Generative AI (Gemini) | AI chatbot |
| Prometheus | Metrics middleware + exporters |
| Swagger/OpenAPI | API docs at `/api-docs` |

## Docker

```bash
# Requires root .env with DB_USER, DB_PASS, DB_NAME, DOCKERHUB_USERNAME
docker-compose up
```
Services: client (4003), server (4002), mssql, adminer (8083), nginx-exporter (9114), mssql-exporter (4004).

## Testing

No automated test suite. Use the Postman collection in `/postman/` for API testing.
