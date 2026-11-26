#!/usr/bin/env python3
"""超幾何分布の data/hyper.json を hyper_0.json 〜 hyper_3.json に分割する。

hyper.json は約18MBあり、GitHubへの一括プッシュ上限（16MiB）に収まらないため、
第1パラメータ m のインデックス範囲で4分割する。各シャードは単体で完結した
JSON（ヘッダ情報＋その範囲の combos）で、表示側は4ファイルを読み込んで
combos をマージする（meta.json の files に一覧がある）。

使い方: python3 scripts/shard_hyper.py [データディレクトリ]
"""
import json
import os
import sys

DATA_DIR = sys.argv[1] if len(sys.argv) > 1 else "data"
SHARDS = [(0, 12), (13, 25), (26, 38), (39, 50)]  # m のインデックス範囲（含む）


def main():
    src = os.path.join(DATA_DIR, "hyper.json")
    d = json.load(open(src))
    total = 0
    for i, (lo, hi) in enumerate(SHARDS):
        combos = {k: v for k, v in d["combos"].items()
                  if lo <= int(k.split(",")[0]) <= hi}
        total += len(combos)
        out = dict(d, combos=combos)
        path = os.path.join(DATA_DIR, f"hyper_{i}.json")
        with open(path, "w") as f:
            json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        print(f"hyper_{i}.json: m index {lo}-{hi}, {len(combos)} combos, "
              f"{os.path.getsize(path) / 1e6:.2f} MB")
    assert total == len(d["combos"]), "shard partition mismatch"
    print(f"partition OK: {total} combos in {len(SHARDS)} shards")


if __name__ == "__main__":
    main()
