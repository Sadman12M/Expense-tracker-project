const CONFIG = window.APP_CONFIG;

if (!CONFIG) {
  document.body.innerHTML =
    '<div style="padding:40px;font-family:sans-serif;color:#B3261E;">Missing config.js — check that Terraform generated it and it loads before script.js.</div>';
  throw new Error("window.APP_CONFIG is missing");
}

const categoryColors = {
  Food: { bg: "#E3EFEE", fg: "#0E7C7B" },
  Transport: { bg: "#FBEEE4", fg: "#B45309" },
  Rent: { bg: "#EFE7F6", fg: "#6B3FA0" },
  Utilities: { bg: "#E9F0FB", fg: "#2952A3" },
  Other: { bg: "#F0EDE5", fg: "#6B6659" }
};

function login() {
  const url = `${CONFIG.cognitoDomain}/oauth2/authorize?client_id=${CONFIG.clientId}` +
    `&response_type=code&scope=openid+email+profile&redirect_uri=${encodeURIComponent(CONFIG.redirectUri)}`;
  window.location.href = url;
}

function logout() {
  sessionStorage.removeItem("id_token");
  sessionStorage.removeItem("access_token");
  const url = `${CONFIG.cognitoDomain}/logout?client_id=${CONFIG.clientId}` +
    `&logout_uri=${encodeURIComponent(CONFIG.logoutRedirectUri)}`;
  window.location.href = url;
}

async function exchangeCodeForTokens(code) {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: CONFIG.clientId,
    code: code,
    redirect_uri: CONFIG.redirectUri
  });
  const res = await fetch(`${CONFIG.cognitoDomain}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body
  });
  if (!res.ok) throw new Error("Token exchange failed");
  const data = await res.json();
  sessionStorage.setItem("id_token", data.id_token);
  sessionStorage.setItem("access_token", data.access_token);
}

function getIdToken() {
  return sessionStorage.getItem("id_token");
}

function decodeJwt(token) {
  try {
    return JSON.parse(atob(token.split(".")[1]));
  } catch (e) {
    return null;
  }
}

async function apiCall(path, options = {}) {
  const token = getIdToken();
  const res = await fetch(`${CONFIG.apiUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
      ...(options.headers || {})
    }
  });

  if (!res.ok) {
    let message = `API error: ${res.status}`;
    try {
      const errBody = await res.json();
      if (errBody?.error) message = errBody.error;
    } catch (_) {
      // response had no JSON body; keep the generic message
    }
    throw new Error(message);
  }

  return res.json();
}

async function loadExpenses() {
  try {
    const data = await apiCall("/expenses");
    renderExpenses(data.expenses || [], data.monthTotal || 0);
  } catch (e) {
    console.error("Failed to load expenses:", e);
    document.getElementById("expense-list").innerHTML =
      `<div class="empty-state">${escapeHtml(e.message)}</div>`;
  }
}

function renderExpenses(expenses, monthTotal) {
  document.getElementById("stat-total").textContent = `$${parseFloat(monthTotal).toFixed(2)}`;
  document.getElementById("stat-count").textContent = expenses.length;

  const counts = {};
  expenses.forEach(e => { counts[e.category] = (counts[e.category] || 0) + 1; });
  const top = Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0] || "—";
  document.getElementById("stat-top").textContent = top;

  const list = document.getElementById("expense-list");
  if (expenses.length === 0) {
    list.innerHTML = '<div class="empty-state">No expenses yet — add your first one.</div>';
    return;
  }

  list.innerHTML = expenses.map(exp => {
    const colors = categoryColors[exp.category] || categoryColors.Other;
    return `
      <div class="row-grid table-row">
        <div>${formatDate(exp.date)}</div>
        <div><span class="badge" style="background:${colors.bg}; color:${colors.fg};">${escapeHtml(exp.category)}</span></div>
        <div>${escapeHtml(exp.description || "")}</div>
        <div class="amount">$${parseFloat(exp.amount).toFixed(2)}</div>
        <div class="del-btn"><button class="delete-btn" data-id="${escapeHtml(exp.expenseId)}" style="background:none;border:none;cursor:pointer;">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#B3261E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"></path><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"></path></svg>
        </button></div>
      </div>`;
  }).join("");

  list.querySelectorAll(".delete-btn").forEach(btn => {
    btn.addEventListener("click", () => deleteExpense(btn.dataset.id));
  });
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  if (isNaN(d)) return dateStr;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

async function addExpense() {
  const amount = document.getElementById("amount").value;
  const category = document.getElementById("category").value;
  const description = document.getElementById("description").value;
  const date = document.getElementById("date").value;

  if (!amount) { alert("Please enter an amount"); return; }

  try {
    await apiCall("/expenses", {
      method: "POST",
      body: JSON.stringify({ amount: parseFloat(amount), category, description, date })
    });
    document.getElementById("amount").value = "";
    document.getElementById("description").value = "";
    loadExpenses();
  } catch (e) {
    alert("Failed to add expense: " + e.message);
  }
}

async function deleteExpense(id) {
  try {
    await apiCall(`/expenses/${id}`, { method: "DELETE" });
    loadExpenses();
  } catch (e) {
    alert("Failed to delete expense: " + e.message);
  }
}

function showDashboard() {
  document.getElementById("login-screen").style.display = "none";
  document.getElementById("dashboard").style.display = "flex";
  const claims = decodeJwt(getIdToken());
  const username = claims?.["cognito:username"] || claims?.email || "User";
  document.getElementById("username-display").textContent = username;
  document.getElementById("avatar-letter").textContent = username[0].toUpperCase();
  loadExpenses();
}

function showLogin() {
  document.getElementById("login-screen").style.display = "flex";
  document.getElementById("dashboard").style.display = "none";
}

async function init() {
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");

  if (code) {
    try {
      await exchangeCodeForTokens(code);
      window.history.replaceState({}, document.title, window.location.pathname);
      showDashboard();
    } catch (e) {
      console.error(e);
      showLogin();
    }
  } else if (getIdToken()) {
    showDashboard();
  } else {
    showLogin();
  }
}

init();