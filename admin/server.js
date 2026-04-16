const path = require("path");
const express = require("express");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
const port = Number(process.env.PORT || 3001);
const adminToken = process.env.ADMIN_TOKEN || "";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is required");
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

app.use(express.json());

function requireAdmin(req, res, next) {
  if (!adminToken) {
    return next();
  }

  const bearer = req.headers.authorization || "";
  const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";

  if (token !== adminToken) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  next();
}

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get("/api/overview", requireAdmin, async (_req, res) => {
  try {
    const [statsResult, recentUsersResult, recentTransactionsResult] = await Promise.all([
      pool.query(`
        SELECT
          (SELECT COUNT(*)::int FROM users) AS users_count,
          (SELECT COUNT(*)::int FROM transactions) AS transactions_count,
          COALESCE((SELECT SUM(amount_cents)::bigint FROM transactions WHERE status = 'completed'), 0) AS completed_volume_cents,
          (SELECT COUNT(*)::int FROM transactions WHERE status = 'completed') AS completed_count,
          (SELECT COUNT(*)::int FROM transactions WHERE status = 'pending') AS pending_count,
          (SELECT COUNT(*)::int FROM transactions WHERE status = 'failed') AS failed_count
      `),
      pool.query(`
        SELECT id, phone, stripe_customer, balance_cents, created_at
        FROM users
        ORDER BY created_at DESC
        LIMIT 5
      `),
      pool.query(`
        SELECT
          t.id,
          t.amount_cents,
          t.status,
          t.created_at,
          fu.phone AS from_phone,
          tu.phone AS to_phone
        FROM transactions t
        LEFT JOIN users fu ON fu.id = t.from_user
        LEFT JOIN users tu ON tu.id = t.to_user
        ORDER BY t.created_at DESC
        LIMIT 10
      `),
    ]);

    res.json({
      stats: statsResult.rows[0],
      recentUsers: recentUsersResult.rows,
      recentTransactions: recentTransactionsResult.rows,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/users", requireAdmin, async (req, res) => {
  try {
    const search = (req.query.search || "").toString().trim();
    const limit = Math.min(Number(req.query.limit || 50), 200);
    const hasSearch = search.length > 0;

    const result = await pool.query(
      `
        SELECT
          u.id,
          u.phone,
          u.stripe_customer,
          u.balance_cents,
          u.created_at,
          COALESCE(SUM(CASE WHEN t.status = 'completed' THEN t.amount_cents ELSE 0 END), 0)::bigint AS completed_received_cents,
          COUNT(t.id)::int AS transaction_count
        FROM users u
        LEFT JOIN transactions t ON t.to_user = u.id
        WHERE ($1 = '' OR u.phone ILIKE '%' || $1 || '%')
        GROUP BY u.id
        ORDER BY u.created_at DESC
        LIMIT $2
      `,
      [hasSearch ? search : "", limit]
    );

    res.json({ users: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/transactions", requireAdmin, async (req, res) => {
  try {
    const status = (req.query.status || "").toString().trim();
    const limit = Math.min(Number(req.query.limit || 100), 300);

    const result = await pool.query(
      `
        SELECT
          t.id,
          t.amount_cents,
          t.status,
          t.created_at,
          t.from_user,
          t.to_user,
          fu.phone AS from_phone,
          tu.phone AS to_phone
        FROM transactions t
        LEFT JOIN users fu ON fu.id = t.from_user
        LEFT JOIN users tu ON tu.id = t.to_user
        WHERE ($1 = '' OR t.status = $1)
        ORDER BY t.created_at DESC
        LIMIT $2
      `,
      [status, limit]
    );

    res.json({ transactions: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.use("/", express.static(path.join(__dirname, "public")));

app.listen(port, () => {
  console.log(`Bleep Pay admin listening on http://localhost:${port}`);
});
