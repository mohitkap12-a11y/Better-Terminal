#!/usr/bin/env node
// Builds the documentation site: docs/site-src/*.md  ->  site/docs/*.html (committed, no build step in CI).
// Usage: node scripts/build-docs.js
// Markdown subset: front matter (title, group, order), # headings (with {#id}), paragraphs, - and 1. lists,
// | tables |, ``` code ```, > quotes, **bold**, *italic*, `code`, [links](url).
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, '..', 'docs', 'site-src');
const OUT = path.join(__dirname, '..', 'site', 'docs');
const GROUPS = ['Start', 'Organise', 'Find', 'Look', 'Under the hood', 'Reference'];

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const slug = s => s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^a-z0-9\s-]/g, '').trim().replace(/\s+/g, '-');

function inline(t) {
  const codes = [];
  t = t.replace(/`([^`]+)`/g, (_, c) => { codes.push(c); return `\u0000${codes.length - 1}\u0000`; });
  t = esc(t);
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, text, url) => {
    const ext = /^https?:/.test(url);
    return `<a href="${url}"${ext ? ' rel="noopener"' : ''}>${text}</a>`;
  });
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/(^|[^*])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>');
  return t.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${esc(codes[+i])}</code>`);
}

function render(md) {
  const lines = md.split('\n'), out = [], toc = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (/^```/.test(line)) {
      const buf = []; i++;
      while (i < lines.length && !/^```/.test(lines[i])) buf.push(lines[i++]);
      i++; out.push(`<pre><code>${esc(buf.join('\n'))}</code></pre>`); continue;
    }
    const h = line.match(/^(#{1,3}) (.*?)(?:\s*\{#([\w-]+)\})?$/);
    if (h) {
      const level = h[1].length, text = h[2], id = h[3] || slug(text);
      if (level === 2) toc.push({ id, text: text.replace(/`/g, '') });
      out.push(level === 1 ? `<h1>${inline(text)}</h1>` : `<h${level} id="${id}">${inline(text)}<a class="anchor" href="#${id}" aria-label="Link to this section">#</a></h${level}>`);
      i++; continue;
    }
    if (/^\|/.test(line)) {
      const rows = [];
      while (i < lines.length && /^\|/.test(lines[i])) rows.push(lines[i++]);
      const cells = r => r.replace(/^\||\|$/g, '').split('|').map(c => c.trim());
      const head = cells(rows[0]), body = rows.slice(2).map(cells);
      out.push('<div class="tbl"><table><thead><tr>' + head.map(c => `<th>${inline(c)}</th>`).join('') + '</tr></thead><tbody>' +
        body.map(r => '<tr>' + r.map(c => `<td>${inline(c)}</td>`).join('') + '</tr>').join('') + '</tbody></table></div>');
      continue;
    }
    if (/^(- |\d+\. )/.test(line)) {
      const ordered = /^\d+\. /.test(line), items = [];
      while (i < lines.length && /^(- |\d+\. )/.test(lines[i])) items.push(lines[i++].replace(/^(- |\d+\. )/, ''));
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>${items.map(x => `<li>${inline(x)}</li>`).join('')}</${tag}>`); continue;
    }
    if (/^> /.test(line)) {
      const buf = [];
      while (i < lines.length && /^> /.test(lines[i])) buf.push(lines[i++].slice(2));
      out.push(`<blockquote>${inline(buf.join(' '))}</blockquote>`); continue;
    }
    if (!line.trim()) { i++; continue; }
    const buf = [];
    while (i < lines.length && lines[i].trim() && !/^(```|#{1,3} |\||- |\d+\. |> )/.test(lines[i])) buf.push(lines[i++]);
    out.push(`<p>${inline(buf.join(' '))}</p>`);
  }
  return { html: out.join('\n'), toc };
}

function load(file) {
  const raw = fs.readFileSync(path.join(SRC, file), 'utf8');
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  const meta = {}; m[1].split('\n').forEach(l => { const [k, ...v] = l.split(':'); meta[k.trim()] = v.join(':').trim(); });
  return { file, slug: file.replace(/\.md$/, ''), meta, body: m[2] };
}

const pages = fs.readdirSync(SRC).filter(f => f.endsWith('.md')).map(load);
pages.sort((a, b) => GROUPS.indexOf(a.meta.group) - GROUPS.indexOf(b.meta.group) || (+a.meta.order) - (+b.meta.order));

const ICON = `<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>`;
const MENU = `<svg class="ico-open" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg><svg class="ico-close" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>`;
const GH = 'https://github.com/mohitkap12-a11y/Better-Terminal';

function nav(current) {
  return GROUPS.map(g => {
    const items = pages.filter(p => p.meta.group === g);
    if (!items.length) return '';
    return `<div class="dg"><div class="dt">${g}</div>${items.map(p =>
      `<a href="${p.slug === 'index' ? './' : p.slug + '.html'}"${p.slug === current ? ' aria-current="page"' : ''}>${p.meta.title}</a>`).join('')}</div>`;
  }).join('');
}

function page(p, idx) {
  const { html, toc } = render(p.body);
  const prev = pages[idx - 1], next = pages[idx + 1];
  const link = q => (q.slug === 'index' ? './' : q.slug + '.html');
  const pn = (prev || next) ? `<nav class="pn">${prev ? `<a class="prev" href="${link(prev)}"><small>Previous</small>${prev.meta.title}</a>` : '<span></span>'}${next ? `<a class="next" href="${link(next)}"><small>Next</small>${next.meta.title}</a>` : '<span></span>'}</nav>` : '';
  const desc = (p.body.split('\n').find(l => l.trim() && !l.startsWith('#')) || '').replace(/[`*\[\]]/g, '').slice(0, 160);
  return `<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${p.meta.title} | Better Terminal docs</title>
<meta name="description" content="${esc(desc)}">
<meta property="og:title" content="${p.meta.title} | Better Terminal docs"><meta property="og:type" content="website">
<meta property="og:image" content="https://mohitkap12-a11y.github.io/Better-Terminal/assets/og.png">
<link rel="icon" href="../assets/favicon.png"><link rel="apple-touch-icon" href="../assets/apple-touch-icon.png">
<link rel="stylesheet" href="../styles.css">
<script>try{var t=localStorage.getItem('bt-theme');if(t)document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site"><div class="wrap"><div class="bar">
  <a class="brand" href="../index.html"><img src="../assets/icon-512.png" alt="">Better Terminal</a>
  <nav class="links">
    <a class="hide-sm" href="../index.html#features">Features</a><a class="hide-sm" href="./">Docs</a><a class="hide-sm" href="../support.html">Support</a><a class="hide-sm" href="${GH}">GitHub</a>
    <button class="icon-btn" id="theme-toggle" aria-label="Switch light and dark theme">${ICON}</button>
    <button class="icon-btn menu-btn" id="menu-toggle" aria-label="Open menu" aria-expanded="false" aria-controls="mobile-menu">${MENU}</button>
  </nav>
  <div class="mobile-menu" id="mobile-menu" hidden><a href="../index.html#features">Features</a><a href="./">Docs</a><a href="../support.html">Support</a><a href="${GH}">GitHub</a><a class="btn primary" href="${GH}/releases/latest/download/BetterTerminal.dmg">Download for macOS</a></div>
</div></div></header>

<main id="main"><div class="wrap docs">
  <aside class="dnav" aria-label="Documentation"><details class="dmob"><summary>Documentation menu</summary>${nav(p.slug)}</details><div class="dside">${nav(p.slug)}</div></aside>
  <article class="dbody">
    <p class="crumbs"><a href="../index.html">Home</a> › <a href="./">Docs</a>${p.slug === 'index' ? '' : ' › ' + p.meta.title}</p>
${html}
${pn}
    <p class="edit"><a href="${GH}/edit/main/docs/site-src/${p.file}">Edit this page on GitHub</a></p>
  </article>
  ${toc.length > 2 ? `<aside class="dtoc" aria-label="On this page"><div class="dt">On this page</div>${toc.map(t => `<a href="#${t.id}">${esc(t.text)}</a>`).join('')}</aside>` : ''}
</div></main>
<footer><div class="wrap"><span>© Better Terminal · open source</span><span class="flinks"><a href="${GH}">GitHub</a><a href="${GH}/releases">Releases</a><a href="${GH}/issues">Issues</a><a href="./">Docs</a><a href="../support.html">Support</a></span></div></footer>
<script src="../script.js"></script>
</body></html>
`;
}

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
pages.forEach((p, i) => fs.writeFileSync(path.join(OUT, p.slug === 'index' ? 'index.html' : p.slug + '.html'), page(p, i)));
console.log(`built ${pages.length} pages into site/docs`);
