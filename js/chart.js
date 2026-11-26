"use strict";

// SVGチャート描画（依存ライブラリなし）。
// 連続分布は折れ線、離散分布は点で描く。ホバーで最寄りの点を通知する。

function niceStep(rawStep) {
  const mag = Math.pow(10, Math.floor(Math.log10(rawStep)));
  const norm = rawStep / mag;
  if (norm <= 1) return mag;
  if (norm <= 2) return 2 * mag;
  if (norm <= 2.5) return 2.5 * mag;
  if (norm <= 5) return 5 * mag;
  return 10 * mag;
}

function niceTicks(min, max, target) {
  if (!(max > min)) return [min];
  const step = niceStep((max - min) / target);
  const ticks = [];
  const start = Math.ceil(min / step) * step;
  for (let v = start; v <= max + step * 1e-9; v += step) {
    ticks.push(Math.abs(v) < step * 1e-9 ? 0 : v);
  }
  return ticks;
}

function niceCeil(v) {
  if (!(v > 0)) return 1;
  const step = niceStep(v / 5);
  return Math.ceil(v / step) * step;
}

function fmtTick(v) {
  const r = Math.round(v * 1000) / 1000;
  return String(Object.is(r, -0) ? 0 : r);
}

const CHART_MARGIN = { left: 58, right: 14, top: 12, bottom: 34 };

// svg: SVG要素, opts: {points:[{x,y}], kind:'line'|'points',
//   xDomain:[a,b], yDomain:[0,ymax], onHover:function(point, px, py)}
function drawChart(svg, opts) {
  const width = svg.clientWidth || 600;
  const height = svg.clientHeight || 420;
  const m = CHART_MARGIN;
  const iw = Math.max(10, width - m.left - m.right);
  const ih = Math.max(10, height - m.top - m.bottom);
  const [x0, x1] = opts.xDomain;
  const [y0, y1] = opts.yDomain;
  const sx = (x) => m.left + ((x - x0) / (x1 - x0)) * iw;
  const sy = (y) => m.top + ih - ((y - y0) / (y1 - y0)) * ih;

  const parts = [];
  parts.push(`<rect x="0" y="0" width="${width}" height="${height}" fill="transparent"/>`);

  // グリッドと軸ラベル
  for (const t of niceTicks(y0, y1, 5)) {
    const py = sy(t);
    parts.push(`<line x1="${m.left}" y1="${py}" x2="${width - m.right}" y2="${py}" stroke="#e3e9ee" stroke-width="1"/>`);
    parts.push(`<text x="${m.left - 8}" y="${py + 4}" text-anchor="end" font-size="11" fill="#6b7a86">${fmtTick(t)}</text>`);
  }
  for (const t of niceTicks(x0, x1, 8)) {
    const px = sx(t);
    parts.push(`<line x1="${px}" y1="${m.top}" x2="${px}" y2="${m.top + ih}" stroke="#f0f3f6" stroke-width="1"/>`);
    parts.push(`<text x="${px}" y="${m.top + ih + 18}" text-anchor="middle" font-size="11" fill="#6b7a86">${fmtTick(t)}</text>`);
  }
  parts.push(`<line x1="${m.left}" y1="${m.top + ih}" x2="${width - m.right}" y2="${m.top + ih}" stroke="#b9c5ce" stroke-width="1"/>`);
  parts.push(`<line x1="${m.left}" y1="${m.top}" x2="${m.left}" y2="${m.top + ih}" stroke="#b9c5ce" stroke-width="1"/>`);

  const pts = opts.points;
  if (opts.kind === "line") {
    let d = "";
    let pen = false;
    for (const p of pts) {
      if (p.y === null || p.y === undefined || !isFinite(p.y)) { pen = false; continue; }
      const px = sx(p.x), py = sy(Math.min(Math.max(p.y, y0), y1));
      d += pen ? `L${px.toFixed(1)},${py.toFixed(1)}` : `M${px.toFixed(1)},${py.toFixed(1)}`;
      pen = true;
    }
    if (d) parts.push(`<path d="${d}" fill="none" stroke="#3c8dbc" stroke-width="2"/>`);
  } else {
    const circles = [];
    for (const p of pts) {
      if (p.y === null || p.y === undefined || !isFinite(p.y)) continue;
      circles.push(`<circle cx="${sx(p.x).toFixed(1)}" cy="${sy(p.y).toFixed(1)}" r="3.2" fill="#3c8dbc"/>`);
    }
    parts.push(circles.join(""));
  }

  // ホバー位置のマーカー（app.js から制御）
  parts.push(`<circle id="hover-dot" r="4.5" fill="#e67e22" stroke="#fff" stroke-width="1.5" style="display:none"/>`);
  parts.push(`<rect id="hover-overlay" x="${m.left}" y="${m.top}" width="${iw}" height="${ih}" fill="transparent"/>`);
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  svg.innerHTML = parts.join("");

  const overlay = svg.querySelector("#hover-overlay");
  const dot = svg.querySelector("#hover-dot");
  if (overlay && opts.onHover) {
    overlay.addEventListener("mousemove", (ev) => {
      const rect = svg.getBoundingClientRect();
      const px = (ev.clientX - rect.left) * (width / rect.width);
      const dataX = x0 + ((px - m.left) / iw) * (x1 - x0);
      let best = null, bestDist = Infinity;
      for (const p of pts) {
        if (p.y === null || p.y === undefined || !isFinite(p.y)) continue;
        const dist = Math.abs(p.x - dataX);
        if (dist < bestDist) { bestDist = dist; best = p; }
      }
      if (best) {
        dot.setAttribute("cx", sx(best.x));
        dot.setAttribute("cy", sy(Math.min(Math.max(best.y, y0), y1)));
        dot.style.display = "";
        opts.onHover(best, sx(best.x) * (rect.width / width), sy(Math.min(Math.max(best.y, y0), y1)) * (rect.height / height));
      }
    });
    overlay.addEventListener("mouseleave", () => {
      dot.style.display = "none";
      opts.onHover(null);
    });
  }
}
