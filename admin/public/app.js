const state = {
  token: "",
};

function authHeaders() {
  return state.token ? { Authorization: `Bearer ${state.token}` } : {};
}

function money(cents) {
  const amount = Number(cents || 0) / 100;
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
  }).format(amount);
}

function dateTime(value) {
  if (!value) return "-";
  const date = new Date(value);
  return new Intl.DateTimeFormat("en-ZA", {
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function fetchJson(url) {
  const res = await fetch(url, { headers: authHeaders() });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || `Request failed: ${res.status}`);
  }
  return res.json();
}

function renderTransactions(rows) {
  const target = document.getElementById("transactionsTable");
  if (!rows.length) {
    target.innerHTML = `<tr><td colspan="5" class="empty">No transactions found.</td></tr>`;
    return;
  }

  target.innerHTML = rows.map((row) => `
    <tr>
      <td><span class="status ${escapeHtml(row.status)}">${escapeHtml(row.status)}</span></td>
      <td class="phone">${escapeHtml(row.from_phone || row.from_user || "-")}</td>
      <td class="phone">${escapeHtml(row.to_phone || row.to_user || "-")}</td>
      <td class="money">${money(row.amount_cents)}</td>
      <td>${dateTime(row.created_at)}</td>
    </tr>
  `).join("");
}

function renderRecentUsers(rows) {
  const target = document.getElementById("recentUsersTable");
  if (!rows.length) {
    target.innerHTML = `<tr><td colspan="3" class="empty">No users found.</td></tr>`;
    return;
  }

  target.innerHTML = rows.map((row) => `
    <tr>
      <td class="phone">${escapeHtml(row.phone)}</td>
      <td class="money">${money(row.balance_cents)}</td>
      <td>${dateTime(row.created_at)}</td>
    </tr>
  `).join("");
}

function renderUsers(rows) {
  const target = document.getElementById("usersTable");
  if (!rows.length) {
    target.innerHTML = `<tr><td colspan="6" class="empty">No matching users found.</td></tr>`;
    return;
  }

  target.innerHTML = rows.map((row) => `
    <tr>
      <td class="phone">${escapeHtml(row.phone)}</td>
      <td class="money">${money(row.balance_cents)}</td>
      <td class="money">${money(row.completed_received_cents)}</td>
      <td>${escapeHtml(row.transaction_count)}</td>
      <td>${escapeHtml(row.stripe_customer || "-")}</td>
      <td>${dateTime(row.created_at)}</td>
    </tr>
  `).join("");
}

async function loadOverview() {
  const data = await fetchJson("/api/overview");
  const stats = data.stats || {};

  document.getElementById("usersCount").textContent = stats.users_count ?? "-";
  document.getElementById("transactionsCount").textContent = stats.transactions_count ?? "-";
  document.getElementById("volumeTotal").textContent = money(stats.completed_volume_cents);
  document.getElementById("queueHealth").textContent = `${stats.pending_count ?? 0} pending / ${stats.failed_count ?? 0} failed`;

  renderRecentUsers(data.recentUsers || []);
  renderTransactions(data.recentTransactions || []);
}

async function loadTransactions() {
  const status = document.getElementById("statusFilter").value;
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  const data = await fetchJson(`/api/transactions?${params.toString()}`);
  renderTransactions(data.transactions || []);
}

async function loadUsers() {
  const search = document.getElementById("userSearch").value.trim();
  const params = new URLSearchParams();
  if (search) params.set("search", search);
  const data = await fetchJson(`/api/users?${params.toString()}`);
  renderUsers(data.users || []);
}

async function refreshAll() {
  state.token = document.getElementById("tokenInput").value.trim();
  try {
    await Promise.all([loadOverview(), loadUsers()]);
  } catch (error) {
    alert(error.message);
  }
}

document.getElementById("refreshButton").addEventListener("click", refreshAll);
document.getElementById("searchButton").addEventListener("click", loadUsers);
document.getElementById("statusFilter").addEventListener("change", loadTransactions);
document.getElementById("userSearch").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    loadUsers();
  }
});

refreshAll();
