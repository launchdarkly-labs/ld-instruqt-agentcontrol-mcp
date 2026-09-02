'use strict';

const PRODUCTS = [
  { id: 'togglebot-tee', name: 'ToggleBot Tee', price: 28,
    desc: 'Crew-neck tee with the ToggleBot mascot. Charcoal grey.',
    img: '/static/images/togglebot-tee.png' },
  { id: 'feature-flag-hoodie', name: 'Feature Flag Hoodie', price: 58,
    desc: 'Pullover hoodie with flag management diagram. Midnight navy.',
    img: '/static/images/feature-flag-hoodie.png' },
  { id: 'dark-mode-cap', name: 'Dark Mode Cap', price: 24,
    desc: 'Six-panel dad cap. Feature Flag System embroidery. Charcoal.',
    img: '/static/images/dark-mode-cap.png' },
  { id: 'ship-it-mug', name: 'Ship It Mug', price: 16,
    desc: '12oz ceramic with "Ship it" and the ToggleWear rocket.',
    img: '/static/images/ship-it-mug.png' },
  { id: 'toggle-socks', name: 'Toggle Socks', price: 14,
    desc: 'Crew socks with embroidered rocket logo. Charcoal.',
    img: '/static/images/toggle-socks.png' },
  { id: 'release-notes-notebook', name: 'Release Notes Notebook', price: 18,
    desc: 'A5 hardcover. Dot grid. Version, date, and key features cover.',
    img: '/static/images/release-notes-notebook.png' },
  { id: 'rollout-tote', name: 'Rollout Tote', price: 22,
    desc: 'Canvas tote with rollout phase diagram. Reinforced handles.',
    img: '/static/images/rollout-tote.png' },
  { id: 'deployment-crewneck', name: 'Deployment Crewneck', price: 52,
    desc: 'Heavyweight crewneck with deployment workflow. Sage green.',
    img: '/static/images/deployment-crewneck.png' },
  { id: 'deployment-hoodie', name: 'Deployment Hoodie', price: 62,
    desc: 'Pullover hoodie with deployment workflow diagram. Navy.',
    img: '/static/images/deployment-hoodie.png' },
  { id: 'neon-flag-hoodie', name: 'Neon Flag Hoodie', price: 64,
    desc: 'Charcoal hoodie with neon feature flag system graphic.',
    img: '/static/images/neon-flag-hoodie.png' },
];

// ---------- Product grid ----------

function renderProducts() {
  const grid = document.getElementById('shop');
  grid.innerHTML = PRODUCTS.map((p) => `
    <article class="product" data-product-id="${p.id}">
      <img class="product-image" src="${p.img}" alt="${p.name}" loading="lazy">
      <div class="product-body">
        <h2 class="product-name">${p.name}</h2>
        <p class="product-price">$${p.price}</p>
        <p class="product-desc">${p.desc}</p>
      </div>
    </article>
  `).join('');
}

// ---------- Session state ----------

const SESSION_KEY = 'togglewear.sessionId';

function getSessionId() {
  let id = localStorage.getItem(SESSION_KEY);
  if (!id) {
    id = (crypto?.randomUUID?.() ?? `s-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`);
    localStorage.setItem(SESSION_KEY, id);
  }
  return id;
}

let userTier = 'free';

function initTierSwitch() {
  const sel = document.getElementById('user-tier');
  userTier = sel.value;
  sel.addEventListener('change', () => {
    userTier = sel.value;
    appendBubble('system', `Switched to ${userTier === 'premium' ? 'Premium' : 'Free'} user.`);
    fetchFeatures();
  });
}

// ---------- Feature flags ----------

async function fetchFeatures() {
  try {
    const res = await fetch(
      `/api/features?session_id=${encodeURIComponent(getSessionId())}&user_tier=${encodeURIComponent(userTier)}`
    );
    if (!res.ok) return;
    const flags = await res.json();
    document.getElementById('new-arrivals').hidden = !flags.new_arrivals_enabled;
    document.getElementById('premium-banner').hidden = !flags.premium_banner_enabled;
    const sortBar = document.getElementById('sort-bar');
    sortBar.hidden = !flags.new_layout_enabled;
    if (flags.new_layout_enabled) {
      document.getElementById('product-count').textContent = `${PRODUCTS.length} items`;
    }
    if (flags.hero_headline) {
      document.getElementById('hero-headline').textContent = flags.hero_headline;
    }
  } catch (_) {
    // non-fatal — storefront still works without flag data
  }
}

// ---------- Event tracking ----------

function trackClick(eventKey) {
  fetch(`/api/track?session_id=${encodeURIComponent(getSessionId())}&event_key=${encodeURIComponent(eventKey)}`, {
    method: 'POST'
  }).catch(() => {});
}

// ---------- Otto widget ----------

const transcript = () => document.getElementById('otto-transcript');
const meta = () => document.getElementById('otto-meta');

function appendBubble(kind, text) {
  const div = document.createElement('div');
  div.className = `bubble ${kind}`;
  div.textContent = text;
  const t = transcript();
  t.appendChild(div);
  t.scrollTop = t.scrollHeight;
}

function setMeta(text) {
  meta().textContent = text;
}

function initOttoPanel() {
  const toggle = document.getElementById('otto-toggle');
  const panel = document.getElementById('otto-panel');
  const close = document.getElementById('otto-close');
  const reset = document.getElementById('otto-reset');
  const input = document.getElementById('otto-input');

  const open = () => {
    panel.hidden = false;
    toggle.setAttribute('aria-expanded', 'true');
    toggle.style.display = 'none';
    setTimeout(() => input.focus(), 30);
  };
  const shut = () => {
    panel.hidden = true;
    toggle.setAttribute('aria-expanded', 'false');
    toggle.style.display = '';
  };

  toggle.addEventListener('click', open);
  close.addEventListener('click', shut);
  reset.addEventListener('click', resetChat);
}

async function resetChat() {
  const reset = document.getElementById('otto-reset');
  reset.disabled = true;
  try {
    const res = await fetch('/chat/reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: getSessionId() }),
    });
    if (!res.ok) {
      appendBubble('system', `Reset failed (${res.status}).`);
      return;
    }
    transcript().innerHTML = '';
    setMeta('');
    appendBubble('system', "Chat reset. Ask me anything about ToggleWear.");
    document.getElementById('otto-input').focus();
  } catch (err) {
    appendBubble('system', `Reset error: ${err.message}`);
  } finally {
    reset.disabled = false;
  }
}

async function sendMessage(message) {
  const sendBtn = document.querySelector('.otto-send');
  const input = document.getElementById('otto-input');
  input.disabled = true;
  sendBtn.disabled = true;

  try {
    const res = await fetch('/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message,
        user_tier: userTier,
        session_id: getSessionId(),
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      // Turn cap (429) returns a friendly response we still want to show.
      if (res.status === 429 && data?.response) {
        appendBubble('system', data.response);
      } else {
        appendBubble('system', `Error ${res.status}: ${data?.detail || 'request failed'}`);
      }
      return;
    }

    appendBubble('otto', data.response);
    setMeta(`turn ${data.turn} / ${data.turn_limit} · tier: ${userTier}`);
  } catch (err) {
    appendBubble('system', `Network error: ${err.message}`);
  } finally {
    input.disabled = false;
    sendBtn.disabled = false;
    input.focus();
  }
}

function initChatForm() {
  const form = document.getElementById('otto-form');
  const input = document.getElementById('otto-input');

  form.addEventListener('submit', (ev) => {
    ev.preventDefault();
    const msg = input.value.trim();
    if (!msg) return;
    appendBubble('user', msg);
    input.value = '';
    sendMessage(msg);
  });
}

// ---------- Boot ----------

document.addEventListener('DOMContentLoaded', () => {
  renderProducts();
  initTierSwitch();
  initOttoPanel();
  initChatForm();
  fetchFeatures();
  appendBubble('system', "Hi — I'm Otto. Ask me anything about ToggleWear.");
  document.getElementById('shop').addEventListener('click', (e) => {
    if (e.target.closest('.product')) trackClick('product-click');
  });
});
