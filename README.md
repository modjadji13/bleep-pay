# Bleep Pay

Bleep Pay is organized as a single repository with three parts:

- `./` - Rust backend (Axum + Postgres)
- `./mobile` - Flutter mobile client scaffold
- `./admin` - Node/Express admin dashboard

## Architecture

- Flutter app handles auth, BLE proximity flow, and real-time payment UX
- Rust backend handles auth, payment requests, accept/decline, and WebSocket events
- Postgres stores users and transactions
- Node admin dashboard reads the same database for operations visibility

## Flow

1. User A opens the app and advertises a session token.
2. User B detects User A and sends a payment request.
3. Backend creates a pending payment and pushes a WebSocket event.
4. User A accepts or declines the request.
5. Backend records the result and notifies both parties.

## Repository layout

- `src/` and `migrations/` are the Rust backend
- `mobile/lib/` contains the Flutter client code
- `admin/` contains the admin dashboard server and static frontend
