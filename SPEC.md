# statdist リニューアル仕様書（フェーズ0成果物）

現行アプリ（ksmzn/ProbabilityDistributionsViewer）のRソースから抽出した仕様と、静的化に向けたデータ設計の確定事項をまとめる。全体計画は [PLAN.md](PLAN.md) を参照。

## 1. 分布仕様一覧（現行仕様の抽出）

パラメータ表の「刻み」は現行Shinyアプリのスライダー刻み。「新刻み」は第3節のポリシーで決めた新仕様。

### Normal distribution（正規分布） / `norm` / 連続

- 表示範囲: -100 〜 100（初期表示 -10 〜 10、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| mean（Mean） | \mu | -50 〜 50 | 0 | 1 | 5 |
| sd（Standard deviation） | \sigma | 0 〜 10 | 1 | 0.5 | 0.5 |

### Erlang distribution（アーラン分布） / `erlang` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| shape（Shape） | k | 1 〜 20 | 1 | 1 | 1 |
| scale（Scale） | \theta | 0.5 〜 20 | 1 | 0.1 | 1 |

### F-distribution（F分布） / `f` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df1（Degrees of freedom） | d_1 | 1 〜 20 | 1 | 1 | 1 |
| df2（Degrees of freedom） | d_2 | 1 〜 20 | 1 | 1 | 1 |

### Noncentral F-distribution（非心F分布） / `ncf` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: `if (df1 == 1) { x <- x[x != 0] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df1（Degrees of freedom） | \nu_1 | 1 〜 20 | 1 | 1 | 2 |
| df2（Degrees of freedom） | \nu_2 | 1 〜 20 | 1 | 1 | 2 |
| ncp（Noncentrality parameter） | \lambda | 0 〜 20 | 0 | 0.1 | 2 |

### Chi-squared distribution（カイ二乗分布） / `chisq` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: `if (df == 1) { x <- x[x != 0] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df（Degrees of freedom） | k | 1 〜 20 | 1 | 1 | 1 |

### Noncentral chi-squared distribution（非心カイ二乗分布） / `ncChisq` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: `if (df == 1) { x <- x[x != 0] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df（Degrees of freedom） | k | 1 〜 20 | 1 | 1 | 1 |
| ncp（Noncentrality parameter） | \lambda | 0 〜 20 | 0 | 0.1 | 1 |

### Gamma distribution（ガンマ分布） / `gamma` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: `if (shape < 1) { x <- x[x != 0] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| shape（Shape） | k | 0 〜 20 | 1 | 0.1 | 1 |
| scale（Scale） | \theta | 0 〜 20 | 1 | 0.1 | 1 |

### Cauchy distribution（コーシー分布） / `cauchy` / 連続

- 表示範囲: -100 〜 100（初期表示 -10 〜 10、範囲スライダー刻み 0.5）
- x_filter: なし
- 平均・分散: 定義なし（現行アプリでも Undefined 表示）

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| location（Location） | x_0 | -20 〜 20 | 0 | 0.1 | 2 |
| scale（Scale） | \gamma | 0 〜 20 | 1 | 0.1 | 1 |

### Exponential distribution（指数分布） / `exp_dist` / 連続

- 表示範囲: -10 〜 50（初期表示 0 〜 5、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| rate（） | \lambda | 0 〜 20 | 1 | 0.1 | 0.2 |

### Log-normal distribution（対数正規分布） / `lnormal` / 連続

- 表示範囲: 0 〜 200（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| meanlog（Mean Log） | \mu | -30 〜 30 | 0 | 0.05 | 2 |
| sdlog（Standard deviation Log） | \sigma | 0 〜 10 | 1 | 0.05 | 0.5 |

### Student's t-distribution（t分布） / `t_dist` / 連続

- 表示範囲: -100 〜 100（初期表示 -10 〜 10、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df（Degrees of freedom） | \nu | 1 〜 20 | 1 | 1 | 1 |

### Noncentral t-distribution（非心t分布） / `nct` / 連続

- 表示範囲: -100 〜 100（初期表示 -10 〜 10、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| df（Degrees of freedom） | \nu | 1 〜 20 | 1 | 1 | 1 |
| ncp（Noncentrality parameter） | \mu | 0 〜 20 | 0 | 0.1 | 1 |

### Beta distribution（ベータ分布） / `beta` / 連続

- 表示範囲: 0 〜 1（初期表示 0 〜 1、範囲スライダー刻み 0.01）
- x_filter: `if (shape1 < 1) { x <- x[x != 0] } if (shape2 < 1) { x <- x[x != 1] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| shape1（Shape） | \alpha | 0 〜 20 | 2 | 0.1 | 1 |
| shape2（Shape） | \beta | 0 〜 20 | 2 | 0.1 | 1 |

### Noncentral beta distribution（非心ベータ分布） / `ncbeta` / 連続

- 表示範囲: 0 〜 1（初期表示 0 〜 1、範囲スライダー刻み 0.01）
- x_filter: `if (shape1 < 1) { x <- x[x != 0] } if (shape2 < 1) { x <- x[x != 1] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| shape1（Shape） | \alpha | 0 〜 20 | 2 | 0.1 | 2 |
| shape2（Shape） | \beta | 0 〜 20 | 2 | 0.1 | 2 |
| ncp（Noncentrality parameter） | \lambda | 0 〜 20 | 0 | 0.1 | 2 |

### Uniform distribution (continuous)（連続一様分布） / `unif` / 連続

- 表示範囲: -50 〜 50（初期表示 0 〜 1、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| min（Min） | a | -50 〜 50 | 0 | 0.5 | 5 |
| max（Max） | b | -50 〜 50 | 1 | 0.5 | 5 |

### Logistic distribution（ロジスティック分布） / `logis` / 連続

- 表示範囲: -100 〜 100（初期表示 -10 〜 10、範囲スライダー刻み 0.5）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| location（Location） | \mu | -20 〜 20 | 0 | 0.1 | 2 |
| scale（Scale） | s | 0 〜 20 | 1 | 0.1 | 1 |

### Weibull distribution（ワイブル分布） / `weibull` / 連続

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 0.5）
- x_filter: `if (shape < 1) { x <- x[x != 0] } return(x)`

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| shape（Shape） | m | 0.1 〜 20 | 1 | 0.1 | 1 |
| scale（Scale） | \eta | 0.1 〜 20 | 1 | 0.1 | 1 |

### Geometric distribution（幾何分布） / `geom` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| prob（Probability of successful trial） | p | 0 〜 1 | 0.5 | 0.01 | 0.01 |

### Hypergeometric distribution（超幾何分布） / `hyper` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 50、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| m（Number of white balls in the urn） | m | 0 〜 100 | 50 | 1 | 1 |
| n（Number of black balls in the urn） | n | 0 〜 100 | 50 | 1 | 1 |
| k（Number of balls drawn from the urn） | k | 0 〜 100 | 50 | 1 | 1 |

### Binomial distribution（二項分布） / `binom` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| size（Number of trials） | n | 0 〜 40 | 10 | 1 | 1 |
| prob（Probability of successful trial） | p | 0 〜 1 | 0.5 | 0.01 | 0.01 |

### Negative binomial distribution（負の二項分布） / `nbinom` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| size（target for number of successful trials） | r | 1 〜 20 | 1 | 1 | 1 |
| prob（Probability of successful trial） | p | 0 〜 1 | 0.5 | 0.01 | 0.01 |

### Poisson distribution（ポアソン分布） / `pois` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| lambda（） | \lambda | 1 〜 20 | 1 | 0.5 | 0.5 |

### Discrete uniform distribution（離散一様分布） / `dunif` / 離散

- 表示範囲: 0 〜 100（初期表示 0 〜 20、範囲スライダー刻み 1）
- x_filter: なし

| パラメータ | 記号 | 範囲 | 初期値 | 現行刻み | 新刻み |
|---|---|---|---|---|---|
| min（Min） | a | 0 〜 100 | 0 | 1 | 1 |
| max（Max） | b | 0 〜 100 | 20 | 1 | 1 |

## 2. データ量の確定見積もり

現行刻みのまま全組み合わせを計算すると、組み合わせ総数は **9,826,332通り**（最大は非心ベータの 8,120,601通り）。1曲線1,000点・PDFとCDFの両方・概算6バイト/数値で換算すると **約118GB** になり、そのままでは成立しない。

なお、これは PLAN.md の当初概算（約9.2GB）をフェーズ0の精密な数え直しで訂正した値である。当初概算は抽出漏れにより過小だった。

## 3. パラメータ刻みポリシー（新仕様として確定）

- 刻みは「きりのよい刻み幅」（…0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10…）の中から、値の数が上限以下になる最小のものを選ぶ。現行刻みより細かくはしない
- 値の数の上限: 連続・1パラメータ分布は101、2パラメータ分布は各31、3パラメータ分布は各13
- 連続分布の曲線は、表示範囲全体に対して500点で保存する。PDFとCDFの両方を保存し、数値は有効数字4桁に丸める
- 離散分布はPMFのみを保存し、CDFはブラウザ側で累積和を取る（元の値はすべてRの計算結果で、表示側は足し算のみ）。確率が0の範囲は保存しない
- 無効な組み合わせは生成しない（超幾何で k > m+n、連続一様で min ≥ max など）
- JSONは分布ごとに分割し、開いた分布のファイルだけを読み込む

| 分布 | 組み合わせ数（新仕様） | 推定サイズ |
|---|---|---|
| Normal distribution | 441 | 約2.43 MB |
| Erlang distribution | 420 | 約2.31 MB |
| F-distribution | 400 | 約2.20 MB |
| Noncentral F-distribution | 1,331 | 約7.32 MB |
| Chi-squared distribution | 20 | 約0.11 MB |
| Noncentral chi-squared distribution | 420 | 約2.31 MB |
| Gamma distribution | 441 | 約2.43 MB |
| Cauchy distribution | 441 | 約2.43 MB |
| Exponential distribution | 101 | 約0.56 MB |
| Log-normal distribution | 651 | 約3.58 MB |
| Student's t-distribution | 20 | 約0.11 MB |
| Noncentral t-distribution | 420 | 約2.31 MB |
| Beta distribution | 441 | 約2.43 MB |
| Noncentral beta distribution | 1,331 | 約7.32 MB |
| Uniform distribution (continuous) | 220 | 約1.21 MB |
| Logistic distribution | 441 | 約2.43 MB |
| Weibull distribution | 441 | 約2.43 MB |
| Geometric distribution | 101 | 約0.06 MB |
| Hypergeometric distribution | 110,551 | 約8.06 MB |
| Binomial distribution | 4,141 | 約0.48 MB |
| Negative binomial distribution | 2,020 | 約1.12 MB |
| Poisson distribution | 39 | 約0.02 MB |
| Discrete uniform distribution | 5,100 | 約1.40 MB |
| **合計** | | **約55 MB** |

合計は目標の100MB以内に収まる（超幾何の上限を50とした場合。第4節参照）。

刻みが現行より目立って粗くなる箇所:

- 正規分布の平均: 刻み 1 → 5
- 対数正規の平均パラメータ meanlog: 0.05 → 2、sdlog: 0.05 → 0.5
- コーシーとロジスティックの位置パラメータ: 0.1 → 2
- 非心Fと非心ベータ: 全パラメータの刻みが 2 になり、ファイルサイズも各約7.3MBと最大

個別に刻みを緩める（細かくする）場合は、その分布のファイルサイズが増える代わりに調整できる。

## 4. 超幾何分布のパラメータ範囲（要判断）

超幾何分布は3パラメータとも整数で刻みを粗くできず、現行範囲（各 0〜100）のままだと、PMFのみ・無効な組み合わせを除いても約122MBになり、全体を圧迫する。範囲の上限を下げた場合の見積もり:

| 上限 | 有効な組み合わせ数 | 推定サイズ | サイト全体の合計 |
|---|---|---|---|
| 100（現行どおり） | 858,601 | 約122 MB | 約169 MB |
| 50 | 110,551 | 約8.1 MB | 約55 MB |
| 40 | 57,441 | 約3.4 MB | 約50 MB |
| 30 | 24,831 | 約1.1 MB | 約48 MB |

推奨は上限50（全体約55MB）。最終判断は未決定事項とする。

## 5. KaTeX 検証結果

全23分布の数式・平均の数式・分散の数式・パラメータ記号、計108文字列を KaTeX（throwOnError、strict）で検証した。問題があったのは次の3件のみで、いずれもデータ生成時の機械的な変換で解決できる。KaTeXの採用に支障はない。

- アーラン分布と二項分布の数式: `\mbox` が KaTeX 未対応 → `\text` に置換して表示OK
- 非心カイ二乗分布の数式: 末尾に余分な改行（バックスラッシュ）が残っている → 除去して表示OK
- コーシー分布の平均・分散は、Rの定義自体が NULL（定義なし）のため検証対象外。現行どおり Undefined と表示する

## 6. 未決定事項

- 超幾何分布のパラメータ範囲の上限（第4節。推奨は50）
- 刻みを個別に緩める分布があるか（例: 正規分布の平均）
- Google Analytics を新サイトでも継続するか
- About の文面を現行のまま使うか、リニューアルに合わせて更新するか
