'use strict';

// Staff review queue. Loaded by /review, and shares the session id with the
// storefront through localStorage so a reviewer sees the shopper's held
// responses from the same browser.
//
// Kept separate from app.js: this page has no product grid and no chat widget,
// and the storefront has no review UI.

const REVIEW_POLL_MS = 3000;
const SESSION_KEY = 'togglewear.sessionId';

function getSessionId() {
  return localStorage.getItem(SESSION_KEY) || '';
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

function render(pending, otherSessions) {
  const list = document.getElementById('review-list');
  const empty = document.getElementById('review-empty');
  const others = document.getElementById('review-others');

  others.textContent = otherSessions
    ? `${otherSessions} more held from other sessions (background traffic).`
    : '';

  empty.hidden = pending.length > 0;
  list.hidden = pending.length === 0;

  // Don't clobber a half-typed edit.
  if (document.activeElement && document.activeElement.closest?.('.review-item')) return;

  list.innerHTML = pending.map((item) => `
    <article class="review-item" data-review-id="${escapeHtml(item.id)}">
      <div class="review-meta">
        <span class="review-score">score ${item.score === null ? 'n/a' : Number(item.score).toFixed(2)}</span>
        <span class="review-model">${escapeHtml(item.model)}</span>
      </div>
      <p class="review-question"><strong>Customer asked:</strong> ${escapeHtml(item.question)}</p>
      <label class="review-label" for="answer-${escapeHtml(item.id)}">Otto's proposed answer — edit before approving if you like</label>
      <textarea id="answer-${escapeHtml(item.id)}" class="review-answer">${escapeHtml(item.answer)}</textarea>
      <div class="review-actions">
        <button class="review-approve" data-action="approve">Approve</button>
        <button class="review-reject" data-action="reject">Reject</button>
      </div>
    </article>
  `).join('');
}

async function resolve(reviewId, action, answer) {
  try {
    const res = await fetch('/review/resolve', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: reviewId, action, answer }),
    });
    if (!res.ok) console.warn('review resolve failed', res.status);
  } catch (err) {
    console.warn('review resolve error', err);
  }
  poll();
}

async function poll() {
  const sid = getSessionId();
  if (!sid) {
    document.getElementById('review-empty').textContent =
      'Open the ToggleWear storefront tab first, so this page knows which shopper session to review.';
    return;
  }
  try {
    const res = await fetch(`/review/queue?session_id=${encodeURIComponent(sid)}`);
    if (!res.ok) return;
    const { pending, other_sessions: otherSessions } = await res.json();
    render(pending || [], otherSessions || 0);
  } catch (err) {
    console.warn('review poll error', err);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('review-list').addEventListener('click', (ev) => {
    const btn = ev.target.closest('button[data-action]');
    if (!btn) return;
    const item = btn.closest('.review-item');
    btn.disabled = true;
    resolve(item.dataset.reviewId, btn.dataset.action, item.querySelector('.review-answer').value);
  });

  poll();
  setInterval(poll, REVIEW_POLL_MS);
});
