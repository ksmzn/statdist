"use strict";

// statdist 静的版のメインロジック。
// データは data/meta.json と data/<dist>.json（事前計算済み）を読み込むだけで、
// 統計計算は行わない（離散分布のCDFの累積和だけは表示側で求める）。

const state = {
  lang: "ja",
  view: "dist", // 'dist' | 'about'
  distId: "norm",
  paramIdx: [],
  mode: "pdf", // 'pdf'（離散では PMF）| 'cdf'
  range: [0, 0],
};

let META = null;
const distCache = new Map();

const $ = (id) => document.getElementById(id);

function t(en) {
  if (state.lang === "ja" && META && META.i18n[en]) return META.i18n[en];
  return en;
}

function distMeta(id) {
  return META.distributions.find((d) => d.id === id);
}

function fmt(v) {
  if (v === null || v === undefined) return "-";
  const r = Math.round(v * 1000) / 1000;
  return String(Object.is(r, -0) ? 0 : r);
}

function fmtStat(v) {
  if (v === null || v === undefined) return t("Undefined");
  if (v !== 0 && (Math.abs(v) >= 1e7 || Math.abs(v) < 1e-4)) {
    return v.toExponential(3);
  }
  return fmt(v);
}

function tex(el, str) {
  if (!el) return;
  if (str === null || str === undefined || str === "") {
    el.textContent = "";
    return;
  }
  try {
    katex.render(str, el, { throwOnError: false });
  } catch (e) {
    el.textContent = str;
  }
}

async function loadDist(id) {
  if (distCache.has(id)) return distCache.get(id);
  const meta = distMeta(id);
  $("chart-loading").hidden = false;
  try {
    const parts = await Promise.all(
      meta.files.map((f) => fetch("data/" + f).then((r) => r.json()))
    );
    const merged = {
      dist: id,
      type: parts[0].type,
      x: parts[0].x || null,
      params: parts[0].params,
      values: parts[0].values,
      combos: {},
    };
    for (const p of parts) Object.assign(merged.combos, p.combos);
    distCache.set(id, merged);
    return merged;
  } finally {
    $("chart-loading").hidden = true;
  }
}

function nearestIdx(values, target) {
  let best = 0, bestDist = Infinity;
  values.forEach((v, i) => {
    const d = Math.abs(v - target);
    if (d < bestDist) { bestDist = d; best = i; }
  });
  return best;
}

// 無効な組み合わせ（連続一様で min >= max など、生成時に除外されたもの）に
// なっていたら、最も近い有効な組み合わせに寄せる
function resolveValidIdx(id, idx) {
  const meta = distMeta(id);
  const data = distCache.get(id);
  if (data.combos[idx.join(",")]) return idx;
  const lens = meta.params.map((p) => data.values[p.name].length);
  const n = idx.length;
  for (let dist = 1; dist <= 3; dist++) {
    const candidates = [];
    const gen = (pos, rem, cur) => {
      if (pos === n) { if (rem === 0) candidates.push([...cur]); return; }
      for (let d = -rem; d <= rem; d++) {
        cur[pos] = idx[pos] + d;
        gen(pos + 1, rem - Math.abs(d), cur);
      }
    };
    gen(0, dist, new Array(n));
    for (const c of candidates) {
      if (c.every((v, i) => v >= 0 && v < lens[i]) && data.combos[c.join(",")]) {
        return c;
      }
    }
  }
  return idx;
}

function applyDefaults(id) {
  const meta = distMeta(id);
  const data = distCache.get(id);
  const idx = meta.params.map((p) =>
    nearestIdx(data.values[p.name], p.default));
  state.paramIdx = resolveValidIdx(id, idx);
  state.range = [meta.range.default[0], meta.range.default[1]];
  state.mode = "pdf";
}

function syncURL() {
  if (state.view !== "dist") return;
  const q = new URLSearchParams();
  q.set("d", state.distId);
  q.set("p", state.paramIdx.join(","));
  q.set("m", state.mode);
  q.set("r", state.range.join(","));
  q.set("lang", state.lang);
  history.replaceState(null, "", "?" + q.toString());
}

function parseURL() {
  const q = new URLSearchParams(location.search);
  if (q.get("lang") === "en" || q.get("lang") === "ja") state.lang = q.get("lang");
  const d = q.get("d");
  if (d && META.distributions.some((x) => x.id === d)) state.distId = d;
  return q;
}

function applyURLParams(q) {
  const meta = distMeta(state.distId);
  const data = distCache.get(state.distId);
  const p = q.get("p");
  if (p) {
    const idx = p.split(",").map((s) => parseInt(s, 10));
    if (idx.length === meta.params.length &&
        idx.every((v, i) => Number.isInteger(v) && v >= 0 && v < data.values[meta.params[i].name].length)) {
      state.paramIdx = resolveValidIdx(state.distId, idx);
    }
  }
  if (q.get("m") === "cdf" || q.get("m") === "pdf") state.mode = q.get("m");
  const r = q.get("r");
  if (r) {
    const vals = r.split(",").map(Number);
    if (vals.length === 2 && vals.every((v) => Number.isFinite(v)) &&
        vals[0] >= meta.range.min && vals[1] <= meta.range.max && vals[0] < vals[1]) {
      state.range = vals;
    }
  }
}

// ---------- 描画 ----------

function renderNav() {
  const nav = $("sidebar");
  nav.innerHTML = "";
  const groups = [
    ["Continuous distributions", META.distributions.filter((d) => d.type === "continuous")],
    ["Discrete distributions", META.distributions.filter((d) => d.type === "discrete")],
  ];
  for (const [title, dists] of groups) {
    const h = document.createElement("div");
    h.className = "nav-group-title";
    h.textContent = t(title);
    nav.appendChild(h);
    for (const d of dists) {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "nav-item" + (d.id === state.distId && state.view === "dist" ? " active" : "");
      b.textContent = d.name[state.lang];
      b.addEventListener("click", () => selectDist(d.id));
      nav.appendChild(b);
    }
  }
}

function renderHeader() {
  $("site-title").textContent = t("Probability Distributions Viewer");
  $("lang-ja").classList.toggle("active", state.lang === "ja");
  $("lang-en").classList.toggle("active", state.lang === "en");
  document.documentElement.lang = state.lang;
}

function renderControls() {
  const meta = distMeta(state.distId);
  const data = distCache.get(state.distId);

  $("legend-params").textContent = t("Parameters");
  $("legend-range").textContent = t("Range");
  $("legend-mode").textContent = t("Plot");
  $("mean-label").textContent = t("Mean");
  $("var-label").textContent = t("Variance");

  // PDF/PMF と CDF の切替
  const modeWrap = $("mode-radios");
  modeWrap.innerHTML = "";
  const densLabel = meta.type === "continuous"
    ? t("Probability density function (PDF)")
    : t("Probability mass function (PMF)");
  const cdfLabel = t("Cumulative distribution function (CDF)");
  for (const [value, label] of [["pdf", densLabel], ["cdf", cdfLabel]]) {
    const lab = document.createElement("label");
    const input = document.createElement("input");
    input.type = "radio";
    input.name = "mode";
    input.value = value;
    input.checked = state.mode === value;
    input.addEventListener("change", () => {
      state.mode = value;
      renderChartAndStats();
      syncURL();
    });
    lab.appendChild(input);
    lab.appendChild(document.createTextNode(" " + label));
    modeWrap.appendChild(lab);
  }

  // パラメータのスライダー（値のグリッド上のインデックスで操作する）
  const wrap = $("param-controls");
  wrap.innerHTML = "";
  meta.params.forEach((p, i) => {
    const values = data.values[p.name];
    const row = document.createElement("div");
    row.className = "slider-row";
    const head = document.createElement("div");
    head.className = "slider-head";
    const nameSpan = document.createElement("span");
    const labelText = p.label[state.lang] || "";
    nameSpan.textContent = labelText;
    const sym = document.createElement("span");
    sym.className = "param-symbol";
    tex(sym, p.symbol);
    nameSpan.appendChild(sym);
    const val = document.createElement("span");
    val.className = "slider-value";
    val.textContent = fmt(values[state.paramIdx[i]]);
    head.appendChild(nameSpan);
    head.appendChild(val);
    const input = document.createElement("input");
    input.type = "range";
    input.min = "0";
    input.max = String(values.length - 1);
    input.step = "1";
    input.value = String(state.paramIdx[i]);
    input.addEventListener("input", () => {
      const prev = state.paramIdx[i];
      state.paramIdx[i] = parseInt(input.value, 10);
      // 無効な組み合わせになる場合はそのスライダーを元に戻す
      if (!data.combos[state.paramIdx.join(",")]) {
        state.paramIdx[i] = prev;
        input.value = String(prev);
        return;
      }
      val.textContent = fmt(values[state.paramIdx[i]]);
      renderChartAndStats();
      syncURL();
    });
    row.appendChild(head);
    row.appendChild(input);
    wrap.appendChild(row);
  });

  // 表示範囲のスライダー
  const rwrap = $("range-controls");
  rwrap.innerHTML = "";
  const names = state.lang === "ja" ? ["最小値", "最大値"] : ["Min", "Max"];
  [0, 1].forEach((k) => {
    const row = document.createElement("div");
    row.className = "slider-row";
    const head = document.createElement("div");
    head.className = "slider-head";
    const nameSpan = document.createElement("span");
    nameSpan.textContent = names[k];
    const val = document.createElement("span");
    val.className = "slider-value";
    val.textContent = fmt(state.range[k]);
    head.appendChild(nameSpan);
    head.appendChild(val);
    const input = document.createElement("input");
    input.type = "range";
    input.min = String(meta.range.min);
    input.max = String(meta.range.max);
    input.step = String(meta.range.step);
    input.value = String(state.range[k]);
    input.addEventListener("input", () => {
      let v = parseFloat(input.value);
      if (k === 0) v = Math.min(v, state.range[1] - meta.range.step);
      else v = Math.max(v, state.range[0] + meta.range.step);
      state.range[k] = Math.round(v * 1e10) / 1e10;
      input.value = String(state.range[k]);
      val.textContent = fmt(state.range[k]);
      renderChartAndStats();
      syncURL();
    });
    row.appendChild(head);
    row.appendChild(input);
    rwrap.appendChild(row);
  });
}

function currentCombo() {
  const data = distCache.get(state.distId);
  return data.combos[state.paramIdx.join(",")] || null;
}

function currentPoints() {
  const meta = distMeta(state.distId);
  const data = distCache.get(state.distId);
  const combo = currentCombo();
  if (!combo) return [];
  const [lo, hi] = state.range;
  if (meta.type === "continuous") {
    const arr = state.mode === "pdf" ? combo.pdf : combo.cdf;
    const pts = [];
    for (let i = 0; i < data.x.length; i++) {
      const x = data.x[i];
      if (x < lo || x > hi) continue;
      pts.push({ x, y: arr[i] });
    }
    return pts;
  }
  // 離散: PMF はそのまま、CDF は台の先頭からの累積和
  const pts = [];
  let cum = 0;
  for (let i = 0; i < combo.pmf.length; i++) {
    const x = combo.x0 + i;
    cum += combo.pmf[i];
    const y = state.mode === "pdf" ? combo.pmf[i] : Math.min(cum, 1);
    if (x < lo || x > hi) continue;
    pts.push({ x, y });
  }
  return pts;
}

function renderChartAndStats() {
  const meta = distMeta(state.distId);
  const combo = currentCombo();
  const pts = currentPoints();

  let yMax = 1;
  if (state.mode === "pdf") {
    let m = 0;
    for (const p of pts) if (p.y !== null && p.y !== undefined && p.y > m) m = p.y;
    yMax = niceCeil(m);
  }
  const shortLabel = state.mode === "cdf" ? "CDF"
    : meta.type === "continuous" ? "PDF" : "PMF";
  drawChart($("chart"), {
    points: pts,
    kind: meta.type === "continuous" ? "line" : "points",
    xDomain: state.range,
    yDomain: [0, yMax],
    onHover: (point, px, py) => {
      const tip = $("tooltip");
      if (!point) { tip.hidden = true; return; }
      tip.hidden = false;
      tip.textContent = `x = ${fmt(point.x)}, ${shortLabel} = ${fmt(point.y)}`;
      const wrap = $("chart-wrap");
      tip.style.left = (px + 8) + "px";
      tip.style.top = (py + 8) + "px";
      tip.style.maxWidth = wrap.clientWidth + "px";
    },
  });

  if (combo) {
    $("mean-value").textContent = fmtStat(combo.mean);
    $("var-value").textContent = fmtStat(combo.var);
  }
}

function renderDist() {
  const meta = distMeta(state.distId);
  $("dist-name").textContent = meta.name[state.lang];
  const wiki = meta.wiki[state.lang] || meta.wiki.en;
  const wikiEl = $("dist-wiki");
  if (wiki) { wikiEl.href = wiki; wikiEl.hidden = false; }
  else wikiEl.hidden = true;
  tex($("formula-box"), meta.formula);
  tex($("mean-formula"), meta.mean_str);
  tex($("var-formula"), meta.variance_str);
  renderControls();
  renderChartAndStats();
}

function renderView() {
  $("view-dist").hidden = state.view !== "dist";
  $("view-about").hidden = state.view !== "about";
  if (state.view === "about") {
    $("about-ja").hidden = state.lang !== "ja";
    $("about-en").hidden = state.lang !== "en";
  }
  renderNav();
}

async function selectDist(id) {
  state.view = "dist";
  if (id !== state.distId || !distCache.has(id)) {
    state.distId = id;
    await loadDist(id);
    applyDefaults(id);
  }
  renderView();
  renderDist();
  syncURL();
}

async function init() {
  META = await fetch("data/meta.json").then((r) => r.json());
  const q = parseURL();
  renderHeader();
  await loadDist(state.distId);
  applyDefaults(state.distId);
  applyURLParams(q);
  renderView();
  renderDist();
  syncURL();

  $("lang-ja").addEventListener("click", () => setLang("ja"));
  $("lang-en").addEventListener("click", () => setLang("en"));
  $("btn-about").addEventListener("click", () => {
    state.view = state.view === "about" ? "dist" : "about";
    renderView();
    if (state.view === "dist") { renderDist(); syncURL(); }
  });

  let resizeTimer = null;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      if (state.view === "dist") renderChartAndStats();
    }, 150);
  });
}

function setLang(lang) {
  if (state.lang === lang) return;
  state.lang = lang;
  renderHeader();
  renderView();
  if (state.view === "dist") renderDist();
  syncURL();
}

document.addEventListener("DOMContentLoaded", init);
