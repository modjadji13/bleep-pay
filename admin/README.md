# Bleep Pay Admin

Node-based admin dashboard for the Bleep Pay backend.

## What it does

- Connects directly to the Bleep Pay Postgres database
- Exposes lightweight admin endpoints for overview, users, and transactions
- Serves a browser dashboard for operations visibility

## Environment

Copy `.env.example` to `.env` and set:

- `DATABASE_URL`
- `PORT`
- `ADMIN_TOKEN` (optional but recommended)

## Run

```bash
npm install
npm start
```

Open `http://localhost:3001`.
