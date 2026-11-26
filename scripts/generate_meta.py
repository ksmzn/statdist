#!/usr/bin/env python3
"""statdist の meta.json を生成する。

入力:
  - specs.json（フェーズ0でRソースから抽出した仕様。数式・ラベル・初期値・表示範囲）
  - data/<dist>.json（generate_data.R の出力。パラメータの値グリッドの正本）
  - 旧リポジトリの i18n/translation_ja.csv（日本語名・ラベル・Wikipedia URL）

出力: data/meta.json
  分布の表示に必要な情報（名前、数式、パラメータ仕様、表示範囲）と、
  UI文字列の日英辞書をまとめたもの。

現行アプリからの修正（SPEC.md 追補を参照）:
  - 数式中の \\mbox は KaTeX 未対応のため \\text に置換（アーラン、二項）
  - 非心カイ二乗の数式末尾に残っていた余分な改行（バックスラッシュ）を除去
  - t分布の平均の数式文字列が対数正規のものになっていたため "0" に修正
"""
import csv
import io
import json
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "data")
SPECS = os.path.join(BASE, "specs.json")
CSV_PATH = os.path.join(BASE, "source", "i18n_translation_ja.csv")

ORDER = ["norm", "erlang", "f", "ncf", "chisq", "ncChisq", "gamma", "cauchy",
         "exp_dist", "lnormal", "t_dist", "nct", "beta", "ncbeta", "unif",
         "logis", "weibull", "geom", "hyper", "binom", "nbinom", "pois", "dunif"]


def load_translations():
    rows = list(csv.reader(io.StringIO(open(CSV_PATH).read())))
    pairs = {r[0].strip(): r[1].strip() for r in rows[1:] if len(r) >= 2}
    # 分布名の直後の行がその分布の Wikipedia URL ペアになっている
    wiki = {}
    for i, r in enumerate(rows):
        if len(r) >= 2 and r[1].strip().startswith("http") and i > 0:
            prev_name = rows[i - 1][0].strip()
            wiki[prev_name] = {"en": r[0].strip(), "ja": r[1].strip()}
    return pairs, wiki


def fix_formula(dist, tex):
    if tex is None:
        return None
    tex = tex.replace("\\mbox", "\\text")
    tex = tex.strip()
    if dist == "ncChisq" and tex.endswith("\\") and not tex.endswith("\\\\"):
        tex = tex[:-1].rstrip()
    return tex


def main():
    specs = {s["dist"]: s for s in json.load(open(SPECS))}
    pairs, wiki = load_translations()
    distributions = []
    for dist_id in ORDER:
        s = specs[dist_id]
        data = json.load(open(os.path.join(DATA_DIR, f"{dist_id}.json")))
        params = []
        for p in s["params"]:
            values = data["values"][p["name"]]
            step = round(values[1] - values[0], 10) if len(values) > 1 else None
            params.append({
                "name": p["name"],
                "label": {"en": p["label"], "ja": pairs.get(p["label"], p["label"])},
                "symbol": p["symbol"],
                "min": values[0],
                "max": values[-1],
                "default": p["value"],
                "step": step,
            })
        mean_str = s["mean_str"]
        if dist_id == "t_dist":
            mean_str = "0"  # 現行アプリでは対数正規の数式になっていたため修正
        distributions.append({
            "id": dist_id,
            # 超幾何だけはファイルサイズの都合で4分割（shard_hyper.py）
            "files": ([f"hyper_{i}.json" for i in range(4)] if dist_id == "hyper"
                      else [f"{dist_id}.json"]),
            "type": "continuous" if s["c_or_d"] == "c" else "discrete",
            "name": {"en": s["name"], "ja": pairs.get(s["name"], s["name"])},
            "wiki": wiki.get(s["name"], {"en": None, "ja": None}),
            "formula": fix_formula(dist_id, s["formula"]),
            "mean_str": mean_str,
            "variance_str": s["variance_str"],
            "range": {
                "min": s["range"]["min"],
                "max": s["range"]["max"],
                "default": s["range"]["value"],
                "step": s["range"]["step"],
            },
            "params": params,
        })
    meta = {"distributions": distributions, "i18n": pairs}
    out = os.path.join(DATA_DIR, "meta.json")
    with open(out, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print(f"meta.json written: {os.path.getsize(out)} bytes, {len(distributions)} distributions")


if __name__ == "__main__":
    main()
