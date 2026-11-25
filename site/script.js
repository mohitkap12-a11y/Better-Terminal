// Theme switch (remembers the choice; defaults to dark)
(function () {
  var root = document.documentElement;
  var saved = null; try { saved = localStorage.getItem('bt-theme'); } catch (e) {}
  if (saved) root.setAttribute('data-theme', saved);
  document.getElementById('theme-toggle').addEventListener('click', function () {
    var next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem('bt-theme', next); } catch (e) {}
  });
})();

// Header turns into a glass pill once scrolled
(function () {
  var h = document.querySelector('header.site');
  function on() { h.classList.toggle('scrolled', window.scrollY > 12); }
  on(); window.addEventListener('scroll', on, { passive: true });
})();

// Real screenshots replace the illustration automatically: add assets/screenshots/app-dark.png (and app-light.png)
(function () {
  var shot = document.querySelector('.shot');
  var img = shot && shot.querySelector('img.real');
  if (!img) return;
  function pick() {
    var light = document.documentElement.getAttribute('data-theme') === 'light';
    var probe = new Image();
    probe.onload = function () { img.src = probe.src; shot.classList.add('has-real'); };
    probe.onerror = function () { shot.classList.remove('has-real'); };
    probe.src = 'assets/screenshots/app-' + (light ? 'light' : 'dark') + '.png';
  }
  pick();
  new MutationObserver(pick).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
})();

// Show the newest release number
(function () {
  var el = document.getElementById('version');
  if (!el) return;
  fetch('https://api.github.com/repos/mohitkap12-a11y/Better-Terminal/releases/latest')
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (j) { if (j && j.tag_name) el.textContent = j.tag_name.replace(/^v/, ''); })
    .catch(function () {});
})();

// Hamburger menu on small screens
(function () {
  var btn = document.getElementById('menu-toggle');
  var menu = document.getElementById('mobile-menu');
  if (!btn || !menu) return;
  function set(open) {
    menu.hidden = !open;
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    btn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  }
  btn.addEventListener('click', function () { set(menu.hidden); });
  menu.addEventListener('click', function (e) { if (e.target.closest('a')) set(false); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') set(false); });
  document.addEventListener('click', function (e) { if (!menu.hidden && !e.target.closest('header.site')) set(false); });
  window.matchMedia('(min-width: 761px)').addEventListener('change', function (e) { if (e.matches) set(false); });
})();

// Copy button for the Homebrew command
(function () {
  document.querySelectorAll('.brew .copy').forEach(function (b) {
    b.addEventListener('click', function () {
      var text = b.getAttribute('data-copy');
      function done() { b.textContent = 'copied'; b.classList.add('done'); setTimeout(function () { b.textContent = 'copy'; b.classList.remove('done'); }, 1800); }
      if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
      function fallback() {
        var t = document.createElement('textarea'); t.value = text; t.style.position = 'fixed'; t.style.opacity = '0';
        document.body.appendChild(t); t.select(); try { document.execCommand('copy'); done(); } catch (e) {} document.body.removeChild(t);
      }
    });
  });
})();
