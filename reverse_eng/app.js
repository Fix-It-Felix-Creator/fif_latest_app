// Viewer shell.
//
//   LEFT  — the details list: every documented item of the application,
//           grouped, filterable.
//   RIGHT — the page view of the selected item: prose blocks, tables and
//           Mermaid pipelines rendered inline. Any diagram opens in a
//           full-screen inspector with zoom + pan.
//
// All content lives in data/*.js — this file only draws it.
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';

mermaid.initialize({
  startOnLoad: false,
  theme: 'neutral',
  themeVariables: { fontFamily: 'Manrope, sans-serif', fontSize: '14px' },
  flowchart: { curve: 'linear', htmlLabels: true, nodeSpacing: 45, rankSpacing: 55 },
  sequence: { useMaxWidth: false },
  er: { useMaxWidth: false },
});

const items = window.DOCS.sections;
const $ = (id) => document.getElementById(id);

const listEl = $('list');
const filterEl = $('filter');
const kickerEl = $('page-kicker');
const titleEl = $('page-title');
const summaryEl = $('page-summary');
const bodyEl = $('page-body');
const footEl = $('page-foot');

let counter = 0;
let current = 0;

/* ------------------------------------------------------------ the list */

function drawList(query = '') {
  const q = query.trim().toLowerCase();
  listEl.innerHTML = '';
  let group = null;

  items.forEach((item, i) => {
    const haystack = `${item.nav} ${item.title} ${item.summary ?? ''} ${item.group}`.toLowerCase();
    if (q && !haystack.includes(q)) return;

    if (item.group !== group) {
      group = item.group;
      const g = document.createElement('div');
      g.className = 'group';
      g.textContent = group;
      listEl.appendChild(g);
    }

    const b = document.createElement('button');
    b.className = 'item' + (i === current ? ' active' : '');
    b.innerHTML =
      `<span class="num">${String(i + 1).padStart(2, '0')}</span>${item.nav}` +
      (item.kicker ? `<span class="sub">${item.kicker}</span>` : '');
    b.onclick = () => show(i);
    listEl.appendChild(b);
  });

  if (!listEl.children.length) {
    const empty = document.createElement('div');
    empty.className = 'group';
    empty.textContent = 'NO MATCH';
    listEl.appendChild(empty);
  }
}

/* ------------------------------------------------------------ the page */

async function show(index) {
  current = index;
  const item = items[index];

  kickerEl.textContent = item.group;
  titleEl.textContent = `${String(index + 1).padStart(2, '0')}. ${item.title}`;
  summaryEl.innerHTML = item.summary ?? '';

  bodyEl.innerHTML = '';
  footEl.innerHTML = '';

  for (const block of item.blocks) {
    const wrap = document.createElement('section');
    wrap.className = 'block';

    if (block.title) {
      const h = document.createElement('h2');
      h.textContent = block.title;
      wrap.appendChild(h);
    }
    if (block.html) {
      const d = document.createElement('div');
      d.innerHTML = block.html;
      wrap.appendChild(d);
    }
    if (block.mermaid) {
      wrap.appendChild(await figure(block.caption ?? block.title ?? 'Diagram', block.mermaid));
    }
    bodyEl.appendChild(wrap);
  }

  drawList(filterEl.value);
  $('page').scrollTop = 0;
}

async function figure(caption, code) {
  const fig = document.createElement('figure');
  fig.className = 'diagram';

  const cap = document.createElement('figcaption');
  cap.className = 'caption';
  cap.innerHTML = `<span class="grow">${caption}</span>`;

  const zoom = document.createElement('button');
  zoom.className = 'plain';
  zoom.textContent = 'Zoom';
  cap.appendChild(zoom);

  const canvas = document.createElement('div');
  canvas.className = 'canvas';

  fig.appendChild(cap);
  fig.appendChild(canvas);

  try {
    const { svg } = await mermaid.render(`d${counter++}`, code);
    canvas.innerHTML = svg;
    zoom.onclick = () => openLightbox(caption, svg);
  } catch (err) {
    canvas.textContent = `Diagram failed to render: ${err.message ?? err}`;
    zoom.disabled = true;
  }
  return fig;
}

/* -------------------------------------------------------- the inspector */

const box = $('lightbox');
const boxViewport = $('lightbox-viewport');
const boxStage = $('lightbox-stage');
const view = { scale: 1, x: 0, y: 0 };

function apply() {
  boxStage.style.transform =
    `translate(${view.x}px, ${view.y}px) scale(${view.scale})`;
}

function size() {
  const svg = boxStage.querySelector('svg');
  if (!svg) return null;
  const vb = svg.viewBox.baseVal;
  return { w: vb.width || svg.clientWidth, h: vb.height || svg.clientHeight };
}

function fit() {
  const s = size();
  if (!s) return;
  const b = boxViewport.getBoundingClientRect();
  view.scale = Math.min((b.width - 60) / s.w, (b.height - 60) / s.h, 2.5);
  view.x = (b.width - s.w * view.scale) / 2;
  view.y = (b.height - s.h * view.scale) / 2;
  apply();
}

function actual() {
  const s = size();
  if (!s) return;
  const b = boxViewport.getBoundingClientRect();
  view.scale = 1;
  view.x = Math.max((b.width - s.w) / 2, 24);
  view.y = 24;
  apply();
}

function zoomAt(cx, cy, factor) {
  const b = boxViewport.getBoundingClientRect();
  const px = cx - b.left;
  const py = cy - b.top;
  const next = Math.min(Math.max(view.scale * factor, 0.05), 12);
  const ratio = next / view.scale;
  view.x = px - (px - view.x) * ratio;
  view.y = py - (py - view.y) * ratio;
  view.scale = next;
  apply();
}

function zoomCenter(factor) {
  const b = boxViewport.getBoundingClientRect();
  zoomAt(b.left + b.width / 2, b.top + b.height / 2, factor);
}

function openLightbox(title, svg) {
  $('lightbox-title').textContent = title;
  boxStage.innerHTML = svg;
  const el = boxStage.querySelector('svg');
  if (el) {
    // Mermaid emits a max-width style and often no intrinsic size; inside an
    // absolutely positioned stage that collapses to nothing. Pin the SVG to
    // its viewBox dimensions so the transform has something to scale.
    const vb = el.viewBox.baseVal;
    el.style.maxWidth = 'none';
    if (vb && vb.width && vb.height) {
      el.setAttribute('width', vb.width);
      el.setAttribute('height', vb.height);
      el.style.width = `${vb.width}px`;
      el.style.height = `${vb.height}px`;
    }
  }
  box.hidden = false;
  requestAnimationFrame(fit);
}

function closeLightbox() {
  box.hidden = true;
  boxStage.innerHTML = '';
}

$('lightbox-tools').addEventListener('click', (e) => {
  const act = e.target.dataset.act;
  if (act === 'in') zoomCenter(1.25);
  else if (act === 'out') zoomCenter(1 / 1.25);
  else if (act === 'reset') actual();
  else if (act === 'fit') fit();
  else if (act === 'close') closeLightbox();
});

boxViewport.addEventListener('wheel', (e) => {
  e.preventDefault();
  zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.15 : 1 / 1.15);
}, { passive: false });

let pan = null;
boxViewport.addEventListener('pointerdown', (e) => {
  pan = { x: e.clientX - view.x, y: e.clientY - view.y };
  boxViewport.classList.add('panning');
  boxViewport.setPointerCapture(e.pointerId);
});
boxViewport.addEventListener('pointermove', (e) => {
  if (!pan) return;
  view.x = e.clientX - pan.x;
  view.y = e.clientY - pan.y;
  apply();
});
boxViewport.addEventListener('pointerup', () => {
  pan = null;
  boxViewport.classList.remove('panning');
});
boxViewport.addEventListener('dblclick', (e) => zoomAt(e.clientX, e.clientY, 1.5));

/* ----------------------------------------------------------- keyboard */

document.addEventListener('keydown', (e) => {
  if (!box.hidden) {
    if (e.key === 'Escape') closeLightbox();
    return;
  }
  if (document.activeElement === filterEl) return;
  if (e.key === 'j' || e.key === 'ArrowDown') show(Math.min(current + 1, items.length - 1));
  if (e.key === 'k' || e.key === 'ArrowUp') show(Math.max(current - 1, 0));
  if (e.key === '/') { e.preventDefault(); filterEl.focus(); }
});

filterEl.addEventListener('input', () => drawList(filterEl.value));

drawList();
show(0);
