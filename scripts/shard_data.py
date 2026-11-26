#!/usr/bin/env python3
"""大きな分布JSONを第1パラメータのインデックス範囲で分割する。

GitHub へのプッシュには1回あたりのサイズ上限があるため、4MBを超える
データファイルは <dist>_0.json, <dist>_1.json, ... に分割する。
各パートは単体で完結したJSON（ヘッダ情報＋その範囲の combos）で、
表示側は meta.json の files に従って全パートを読み込み、combos をマージする。

使い方: python3 scripts/shard_data.py [データディレクトリ] <dist_id> [...]
"""
import json
import math
import os
import sys

TARGET_BYTES = 3_000_000


def shard(data_dir, dist_id):
    src = os.path.join(data_dir, f"{dist_id}.json")
    size = os.path.getsize(src)
    if size <= 4_000_000:
        print(f"{dist_id}: {size / 1e6:.2f} MB, no sharding needed")
        return
    d = json.load(open(src))
    n_indices = len(d["values"][d["params"][0]])
    k = math.ceil(size / TARGET_BYTES)
    bounds = [round(i * n_indices / k) for i in range(k + 1)]
    total = 0
    for i in range(k):
        lo, hi = bounds[i], bounds[i + 1] - 1
        combos = {key: v for key, v in d["combos"].items()
                  if lo <= int(key.split(",")[0]) <= hi}
        total += len(combos)
        out = dict(d, combos=combos)
        path = os.path.join(data_dir, f"{dist_id}_{i}.json")
        with open(path, "w") as f:
            json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        print(f"{dist_id}_{i}.json: first-param index {lo}-{hi}, "
              f"{len(combos)} combos, {os.path.getsize(path) / 1e6:.2f} MB")
    assert total == len(d["combos"]), f"{dist_id}: shard partition mismatch"
    print(f"{dist_id}: partition OK, {total} combos in {k} shards")


if __name__ == "__main__":
    args = sys.argv[1:]
    data_dir = "data"
    if args and os.path.isdir(args[0]):
        data_dir = args.pop(0)
    for dist_id in args:
        shard(data_dir, dist_id)
