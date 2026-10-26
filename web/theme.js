"use strict";
// Only a validated appearance preference is stored; no credentials or student data.
(() => {
  const preference = window.matchMedia('(prefers-color-scheme: dark)');
  let saved;
  try { saved = localStorage.getItem('sga-theme'); } catch {}
  let explicit = saved === 'dark' || saved === 'light';
  function apply(theme) {
    document.documentElement.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]').content = theme === 'dark' ? '#101e29' : '#112b3c';
    document.querySelectorAll('[data-action="toggle-theme"]').forEach(button => {
      button.setAttribute('aria-pressed', String(theme === 'dark'));
      button.setAttribute('aria-label', theme === 'dark' ? 'Ativar modo claro' : 'Ativar modo escuro');
      button.title = button.getAttribute('aria-label');
      button.querySelector('span').textContent = theme === 'dark' ? 'Modo claro' : 'Modo escuro';
    });
  }
  apply(explicit ? saved : preference.matches ? 'dark' : 'light');
  document.addEventListener('click', event => {
    if (!event.target.closest('[data-action="toggle-theme"]')) return;
    const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    explicit = true;
    apply(theme);
    try { localStorage.setItem('sga-theme', theme); } catch {}
  });
  preference.addEventListener('change', event => { if (!explicit) apply(event.matches ? 'dark' : 'light'); });
})();
