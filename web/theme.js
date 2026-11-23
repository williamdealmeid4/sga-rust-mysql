"use strict";
// Controle de tema claro e escuro com preferência salva no navegador.
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
      button.querySelector('path').setAttribute('d', theme === 'dark' ? 'M20 15.5A8.5 8.5 0 0 1 8.5 4 8.5 8.5 0 1 0 20 15.5Z' : 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8 M12 2v2 M12 20v2 M2 12h2 M20 12h2 M4.93 4.93l1.42 1.42 M17.65 17.65l1.42 1.42 M4.93 19.07l1.42-1.42 M17.65 6.35l1.42-1.42');
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
