/**
 * Pet Soul · 魔搭 BFF 客户端（Token 只在 Studio 服务端）
 */
window.PetSoulMS = (function () {
  const TIMEOUT_MS = 9000;

  function baseUrl() {
    const fromWin = typeof window.PETSOUL_BFF_URL === 'string' ? window.PETSOUL_BFF_URL.trim() : '';
    if (fromWin) return fromWin.replace(/\/$/, '');
    try {
      const stored = localStorage.getItem('petsoul_bff_url');
      if (stored && stored.trim()) return stored.trim().replace(/\/$/, '');
    } catch (_) { /* sessionStorage-only env */ }
    return '';
  }

  function enabled() {
    return !!baseUrl();
  }

  async function post(path, body, fallback) {
    const base = baseUrl();
    const safeFallback = fallback || '';
    if (!base) return { text: safeFallback, ai: false };

    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
    try {
      const res = await fetch(`${base}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: ctrl.signal,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return { text: (data.text || safeFallback).trim(), ai: !!data.ai };
    } catch (_) {
      return { text: safeFallback, ai: false };
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    enabled,
    baseUrl,
    soulResult(payload, fallback) {
      return post('/api/soul-result', payload, fallback);
    },
    matchBlurb(payload, fallback) {
      return post('/api/match-blurb', payload, fallback);
    },
    icebreaker(payload, fallback) {
      return post('/api/icebreaker', payload, fallback);
    },
  };
})();
