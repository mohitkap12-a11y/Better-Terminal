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
