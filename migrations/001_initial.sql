CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    stripe_customer TEXT,              -- Stripe customer ID
    balance_cents   BIGINT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE transactions (
    id            UUID PRIMARY KEY,
    from_user     UUID REFERENCES users(id),
    to_user       UUID REFERENCES users(id),
    amount_cents  BIGINT NOT NULL,
    status        TEXT NOT NULL,       -- pending | completed | failed
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_from ON transactions(from_user);
CREATE INDEX idx_transactions_to   ON transactions(to_user);
