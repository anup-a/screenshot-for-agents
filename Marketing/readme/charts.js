// Classic script (file:// blocks modules). Tiny SVG helpers for the README charts (charts-*.html). Snip is the accent; everything else is neutral context.
(() => {
const NS = 'http://www.w3.org/2000/svg';
const C = {
  accent: '#4c84ff',
  accentText: '#8fb4ff',
  other: '#5d6378',
  ink: 'rgba(255,255,255,.94)',
  ink2: 'rgba(232,236,255,.66)',
  ink3: 'rgba(232,236,255,.42)',
  grid: 'rgba(255,255,255,.08)',
  danger: '#ff7a6b',
};

function el(parent, name, attrs = {}, text) {
  const node = document.createElementNS(NS, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  if (text !== undefined) node.textContent = text;
  parent.appendChild(node);
  return node;
}

function svg(host, w, h) {
  return el(host, 'svg', { width: w, height: h, viewBox: `0 0 ${w} ${h}` });
}

/** Horizontal bar with a 4px rounded data end, square at the baseline. */
function hbar(g, x, y, w, h, fill) {
  const r = Math.min(4, w / 2, h / 2);
  el(g, 'path', {
    d: `M${x},${y} H${x + w - r} Q${x + w},${y} ${x + w},${y + r} V${y + h - r} Q${x + w},${y + h} ${x + w - r},${y + h} H${x} Z`,
    fill,
  });
}

/** Vertical bar, rounded at the top. */
function vbar(g, x, y, w, h, fill) {
  const r = Math.min(4, w / 2, h / 2);
  el(g, 'path', {
    d: `M${x},${y + h} V${y + r} Q${x},${y} ${x + r},${y} H${x + w - r} Q${x + w},${y} ${x + w},${y + r} V${y + h} Z`,
    fill,
  });
}

const fmt = (n) => n.toLocaleString('en-US');

window.Charts = { C, el, svg, hbar, vbar, fmt };
})();
