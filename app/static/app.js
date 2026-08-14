'use strict';

const PRODUCTS = [
  { id: 'rocket-tee', name: 'Rocket Tee', price: 28,
    desc: 'Classic crew-neck t-shirt with the LaunchDarkly rocket. Heather grey.',
    img: '/static/images/rocket-tee.svg' },
  { id: 'feature-flag-hoodie', name: 'Feature Flag Hoodie', price: 58,
    desc: 'Pullover hoodie. Embroidered flag logo. Midnight navy.',
    img: '/static/images/feature-flag-hoodie.svg' },
  { id: 'dark-mode-cap', name: 'Dark Mode Cap', price: 24,
    desc: 'Six-panel dad cap. Tone-on-tone black logo.',
    img: '/static/images/dark-mode-cap.svg' },
  { id: 'ship-it-mug', name: 'Ship It Mug', price: 16,
    desc: '12oz ceramic. "Ship it" in the LaunchDarkly font.',
    img: '/static/images/ship-it-mug.svg' },
  { id: 'toggle-socks', name: 'Toggle Socks', price: 14,
    desc: 'Crew socks with a tiny rocket on the ankle.',
    img: '/static/images/toggle-socks.svg' },
  { id: 'release-notes-notebook', name: 'Release Notes Notebook', price: 18,
    desc: 'A5 hardcover. Dot grid. For your actual release notes.',
    img: '/static/images/release-notes-notebook.svg' },
  { id: 'rollout-tote', name: 'Rollout Tote', price: 22,
    desc: '12oz canvas. Reinforced handles.',
    img: '/static/images/rollout-tote.svg' },
  { id: 'feature-branch-crewneck', name: 'Feature Branch Crewneck', price: 52,
    desc: 'Heavyweight crewneck sweatshirt. Sage green.',
    img: '/static/images/feature-branch-crewneck.svg' },
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
  });
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

// ---------- Reviewer decisions coming back (Challenge 03) ----------
//
// When the gate holds a response, the customer sees a placeholder and a human
// decides in the Staff Review tab. This drains whatever they decided and drops
// it into the transcript, so an approval appears without a page refresh.
// A no-op until Challenge 03's gate starts holding anything.

const UPDATES_POLL_MS = 3000;

async function pollUpdates() {
  try {
    const res = await fetch(`/review/updates?session_id=${encodeURIComponent(getSessionId())}`);
    if (!res.ok) return;
    const { messages } = await res.json();
    (messages || []).forEach((text) => appendBubble('otto', text));
  } catch (err) {
    // The endpoint exists from the start, so a failure here is a real error
    // rather than a not-yet-built challenge. Log and keep polling.
    console.warn('updates poll error', err);
  }
}

// ---------- Boot ----------

document.addEventListener('DOMContentLoaded', () => {
  renderProducts();
  initTierSwitch();
  initOttoPanel();
  initChatForm();
  appendBubble('system', "Hi — I'm Otto. Ask me anything about ToggleWear.");
  pollUpdates();
  setInterval(pollUpdates, UPDATES_POLL_MS);
});
