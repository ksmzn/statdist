#!/usr/bin/env Rscript
# statdist データ生成スクリプト
#
# 現行アプリ（ksmzn/ProbabilityDistributionsViewer）の仕様（SPEC.md）に基づき、
# 全23分布について「パラメータの組み合わせ -> 曲線・平均・分散」をRで事前計算し、
# 分布ごとのJSONファイル（data/<dist>.json）として出力する。
# ブラウザ側はこのJSONを表示するだけで、統計計算は行わない。
#
# 使い方:
#   Rscript scripts/generate_data.R [出力先ディレクトリ] [dist_id ...]
#   例) Rscript scripts/generate_data.R data            # 全分布
#       Rscript scripts/generate_data.R data norm       # 正規分布のみ
#
# 仕様の要点（SPEC.md 第3節）:
#   - パラメータの刻みは新仕様（値の数の上限あり）。値のグリッドが正本。
#   - 連続分布: 表示範囲全体に500点、PDFとCDFの両方を保存。有効数字4桁。
#   - 離散分布: PMFのみ保存（CDFは表示側で累積和）。確率が0の範囲は切り落とす。
#   - 無効な組み合わせ（超幾何で k > m+n、連続一様で min >= max）は生成しない。
#   - 平均・分散が定義できない場合は null（表示側で Undefined と出す）。
#
# 現行アプリのコードが自身の表示数式と矛盾していた箇所は、表示数式（仕様）に
# 合わせて修正した。該当箇所には [修正] と記した。内容はSPEC.mdの追補を参照。
#   1. ベータ分布の分散: (α+α+1) となっていた分母を (α+β+1) に修正
#   2. 対数正規分布の分散: exp(2μ+σ) となっていた第1因子を exp(2μ+σ^2) に修正
#   3. 離散一様分布のPMF: dunif の 1/(b-a) ではなく 1/(b-a+1) を使用
# （t分布の平均の数式文字列 "0" への修正は meta.json 側で行う）

suppressMessages({
  library(jsonlite)
  library(hypergeo) # 非心ベータ分布の平均・分散（超幾何関数 2F2）で使用
})

args <- commandArgs(trailingOnly = TRUE)
OUT_DIR <- if (length(args) >= 1) args[1] else "data"
ONLY <- if (length(args) >= 2) args[-1] else NULL
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

N_POINTS <- 500L # 連続分布の曲線の点数

# パラメータ定義のヘルパー
P <- function(name, min, max, step) list(name = name, min = min, max = max, step = step)

# x_filter（現行アプリの挙動）: 条件に合う x をプロットから除く（JSONでは null にする）
xf_beta <- function(x, p) {
  keep <- rep(TRUE, length(x))
  if (p$shape1 < 1) keep[x == 0] <- FALSE
  if (p$shape2 < 1) keep[x == 1] <- FALSE
  keep
}
xf_gamma <- function(x, p) {
  keep <- rep(TRUE, length(x))
  if (p$shape < 1) keep[x == 0] <- FALSE
  keep
}
xf_chisq <- function(x, p) {
  keep <- rep(TRUE, length(x))
  if (p$df == 1) keep[x == 0] <- FALSE
  keep
}
xf_ncf <- function(x, p) {
  keep <- rep(TRUE, length(x))
  if (p$df1 == 1) keep[x == 0] <- FALSE
  keep
}

# 非心ベータ分布の平均・分散（現行アプリの実装どおり。超幾何関数 2F2 を使用）
ncbeta_mean <- function(p) {
  exp(-p$ncp / 2) * p$shape1 *
    genhypergeo(U = c(p$shape1 + 1, p$shape1 + p$shape2),
                L = c(p$shape1, 1 + p$shape1 + p$shape2),
                z = p$ncp / 2) / (p$shape1 + p$shape2)
}
ncbeta_var <- function(p) {
  m <- ncbeta_mean(p)
  exp(-p$ncp / 2) * p$shape1 * (p$shape1 + 1) *
    genhypergeo(U = c(p$shape1 + 1, p$shape1 + p$shape2),
                L = c(p$shape1, 1 + p$shape1 + p$shape2),
                z = p$ncp / 2) /
    ((p$shape1 + p$shape2) * (p$shape1 + p$shape2 + 1)) - m^2
}

# 分布定義の一覧。
#   d, p: 密度・累積の関数（x とパラメータの名前付きリストを受け取る）
#   mean, var: 平均・分散の関数（NULL を返すと「定義なし」）
#   support: 離散分布の台（確率が正になりうる x の範囲）を返す関数
DISTS <- list(
  norm = list(
    type = "continuous", range = c(-100, 100),
    params = list(P("mean", -50, 50, 5), P("sd", 0, 10, 0.5)),
    d = function(x, p) dnorm(x, mean = p$mean, sd = p$sd),
    p = function(x, p) pnorm(x, mean = p$mean, sd = p$sd),
    mean = function(p) p$mean,
    var = function(p) p$sd^2
  ),
  erlang = list(
    type = "continuous", range = c(0, 100),
    params = list(P("shape", 1, 20, 1), P("scale", 0.5, 20, 1)),
    d = function(x, p) dgamma(x, shape = p$shape, scale = p$scale),
    p = function(x, p) pgamma(x, shape = p$shape, scale = p$scale),
    mean = function(p) p$shape * p$scale,
    var = function(p) p$shape * p$scale^2
  ),
  f = list(
    type = "continuous", range = c(0, 100),
    params = list(P("df1", 1, 20, 1), P("df2", 1, 20, 1)),
    d = function(x, p) df(x, df1 = p$df1, df2 = p$df2),
    p = function(x, p) pf(x, df1 = p$df1, df2 = p$df2),
    mean = function(p) p$df2 / (p$df2 - 2),
    var = function(p) (2 * p$df2^2) * (p$df1 + p$df2 - 2) /
      (p$df1 * (p$df2 - 2)^2 * (p$df2 - 4))
  ),
  ncf = list(
    type = "continuous", range = c(0, 100),
    params = list(P("df1", 1, 20, 2), P("df2", 1, 20, 2), P("ncp", 0, 20, 2)),
    d = function(x, p) df(x, df1 = p$df1, df2 = p$df2, ncp = p$ncp),
    p = function(x, p) pf(x, df1 = p$df1, df2 = p$df2, ncp = p$ncp),
    mean = function(p) if (p$df2 <= 2) NULL else (p$df2 * (p$df1 + p$ncp)) / (p$df1 * (p$df2 - 2)),
    var = function(p) if (p$df2 <= 4) NULL else
      (2 * p$df2^2 * ((p$df1 + p$ncp)^2 + (p$df1 + 2 * p$ncp) * (p$df2 - 2))) /
        (p$df1^2 * (p$df2 - 2)^2 * (p$df2 - 4)),
    xfilter = xf_ncf
  ),
  chisq = list(
    type = "continuous", range = c(0, 100),
    params = list(P("df", 1, 20, 1)),
    d = function(x, p) dchisq(x, df = p$df),
    p = function(x, p) pchisq(x, df = p$df),
    mean = function(p) p$df,
    var = function(p) 2 * p$df,
    xfilter = xf_chisq
  ),
  ncChisq = list(
    type = "continuous", range = c(0, 100),
    params = list(P("df", 1, 20, 1), P("ncp", 0, 20, 1)),
    d = function(x, p) dchisq(x, df = p$df, ncp = p$ncp),
    p = function(x, p) pchisq(x, df = p$df, ncp = p$ncp),
    mean = function(p) p$df + p$ncp,
    var = function(p) 2 * (p$df + 2 * p$ncp)
  ),
  gamma = list(
    type = "continuous", range = c(0, 100),
    params = list(P("shape", 0, 20, 1), P("scale", 0, 20, 1)),
    d = function(x, p) dgamma(x, shape = p$shape, scale = p$scale),
    p = function(x, p) pgamma(x, shape = p$shape, scale = p$scale),
    mean = function(p) p$shape * p$scale,
    var = function(p) p$shape * p$scale^2,
    xfilter = xf_gamma
  ),
  cauchy = list(
    type = "continuous", range = c(-100, 100),
    params = list(P("location", -20, 20, 2), P("scale", 0, 20, 1)),
    d = function(x, p) dcauchy(x, location = p$location, scale = p$scale),
    p = function(x, p) pcauchy(x, location = p$location, scale = p$scale),
    mean = function(p) NULL,
    var = function(p) NULL
  ),
  exp_dist = list(
    type = "continuous", range = c(-10, 50),
    params = list(P("rate", 0, 20, 0.2)),
    d = function(x, p) dexp(x, rate = p$rate),
    p = function(x, p) pexp(x, rate = p$rate),
    mean = function(p) 1 / p$rate,
    var = function(p) 1 / p$rate^2
  ),
  lnormal = list(
    type = "continuous", range = c(0, 200),
    params = list(P("meanlog", -30, 30, 2), P("sdlog", 0, 10, 0.5)),
    d = function(x, p) dlnorm(x, meanlog = p$meanlog, sdlog = p$sdlog),
    p = function(x, p) plnorm(x, meanlog = p$meanlog, sdlog = p$sdlog),
    mean = function(p) exp(p$meanlog + p$sdlog^2 / 2),
    # [修正] 現行コードは exp(2*meanlog + sdlog) だったが、表示数式どおり exp(2*meanlog + sdlog^2)
    var = function(p) exp(2 * p$meanlog + p$sdlog^2) * (exp(p$sdlog^2) - 1)
  ),
  t_dist = list(
    type = "continuous", range = c(-100, 100),
    params = list(P("df", 1, 20, 1)),
    d = function(x, p) dt(x, df = p$df),
    p = function(x, p) pt(x, df = p$df),
    mean = function(p) 0,
    var = function(p) if (p$df <= 2) Inf else p$df / (p$df - 2)
  ),
  nct = list(
    type = "continuous", range = c(-100, 100),
    params = list(P("df", 1, 20, 1), P("ncp", 0, 20, 1)),
    d = function(x, p) dt(x, df = p$df, ncp = p$ncp),
    p = function(x, p) pt(x, df = p$df, ncp = p$ncp),
    mean = function(p) if (p$df <= 1) NULL else
      p$ncp * sqrt(p$df / 2) * gamma((p$df - 1) / 2) / gamma(p$df / 2),
    var = function(p) if (p$df <= 2) NULL else
      (p$df * (1 + p$ncp^2)) / (p$df - 2) -
        (p$ncp^2 * p$df / 2) * (gamma((p$df - 1) / 2) / gamma(p$df / 2))^2
  ),
  beta = list(
    type = "continuous", range = c(0, 1),
    params = list(P("shape1", 0, 20, 1), P("shape2", 0, 20, 1)),
    d = function(x, p) dbeta(x, shape1 = p$shape1, shape2 = p$shape2),
    p = function(x, p) pbeta(x, shape1 = p$shape1, shape2 = p$shape2),
    mean = function(p) p$shape1 / (p$shape1 + p$shape2),
    # [修正] 現行コードは分母が (shape1 + shape1 + 1) だったが、表示数式どおり (shape1 + shape2 + 1)
    var = function(p) (p$shape1 * p$shape2) /
      ((p$shape1 + p$shape2)^2 * (p$shape1 + p$shape2 + 1)),
    xfilter = xf_beta
  ),
  ncbeta = list(
    type = "continuous", range = c(0, 1),
    params = list(P("shape1", 0, 20, 2), P("shape2", 0, 20, 2), P("ncp", 0, 20, 2)),
    d = function(x, p) dbeta(x, shape1 = p$shape1, shape2 = p$shape2, ncp = p$ncp),
    p = function(x, p) pbeta(x, shape1 = p$shape1, shape2 = p$shape2, ncp = p$ncp),
    mean = ncbeta_mean,
    var = ncbeta_var,
    xfilter = xf_beta
  ),
  unif = list(
    type = "continuous", range = c(-50, 50),
    params = list(P("min", -50, 50, 5), P("max", -50, 50, 5)),
    d = function(x, p) dunif(x, min = p$min, max = p$max),
    p = function(x, p) punif(x, min = p$min, max = p$max),
    mean = function(p) (p$min + p$max) / 2,
    var = function(p) (p$max - p$min)^2 / 12,
    valid = function(p) p$min < p$max
  ),
  logis = list(
    type = "continuous", range = c(-100, 100),
    params = list(P("location", -20, 20, 2), P("scale", 0, 20, 1)),
    d = function(x, p) dlogis(x, location = p$location, scale = p$scale),
    p = function(x, p) plogis(x, location = p$location, scale = p$scale),
    mean = function(p) p$location,
    var = function(p) (p$scale * pi)^2 / 3
  ),
  weibull = list(
    type = "continuous", range = c(0, 100),
    params = list(P("shape", 0.1, 20, 1), P("scale", 0.1, 20, 1)),
    d = function(x, p) dweibull(x, shape = p$shape, scale = p$scale),
    p = function(x, p) pweibull(x, shape = p$shape, scale = p$scale),
    mean = function(p) p$scale * gamma(1 + 1 / p$shape),
    var = function(p) p$scale^2 * (gamma(1 + 2 / p$shape) - gamma(1 + 1 / p$shape)^2)
  ),
  geom = list(
    type = "discrete", range = c(0, 100),
    params = list(P("prob", 0, 1, 0.01)),
    d = function(x, p) dgeom(x, prob = p$prob),
    mean = function(p) (1 - p$prob) / p$prob,
    var = function(p) (1 - p$prob) / p$prob^2,
    support = function(p) c(0, 100)
  ),
  hyper = list(
    type = "discrete", range = c(0, 100),
    # パラメータの上限は50で確定（SPEC.md 第4節）
    params = list(P("m", 0, 50, 1), P("n", 0, 50, 1), P("k", 0, 50, 1)),
    d = function(x, p) dhyper(x, m = p$m, n = p$n, k = p$k),
    mean = function(p) p$k * p$m / (p$m + p$n),
    var = function(p) p$k * p$m * p$n * (p$m + p$n - p$k) /
      ((p$m + p$n)^2 * (p$m + p$n - 1)),
    support = function(p) c(max(0, p$k - p$n), min(p$k, p$m)),
    valid = function(p) p$k <= p$m + p$n
  ),
  binom = list(
    type = "discrete", range = c(0, 100),
    params = list(P("size", 0, 40, 1), P("prob", 0, 1, 0.01)),
    d = function(x, p) dbinom(x, size = p$size, prob = p$prob),
    mean = function(p) p$size * p$prob,
    var = function(p) p$size * p$prob * (1 - p$prob),
    support = function(p) c(0, p$size)
  ),
  nbinom = list(
    type = "discrete", range = c(0, 100),
    params = list(P("size", 1, 20, 1), P("prob", 0, 1, 0.01)),
    d = function(x, p) dnbinom(x, size = p$size, prob = p$prob),
    # 現行アプリの平均・分散は「成功回数までの試行回数」型の定義（数式表示と一致）。
    # プロットする dnbinom（失敗回数型）とは平均が size だけずれる。現行どおりとする。
    mean = function(p) if (p$prob == 0) Inf else p$size / p$prob,
    var = function(p) if (p$prob == 0) Inf else p$size * (1 - p$prob) / p$prob^2,
    support = function(p) c(0, 100)
  ),
  pois = list(
    type = "discrete", range = c(0, 100),
    params = list(P("lambda", 1, 20, 0.5)),
    d = function(x, p) dpois(x, lambda = p$lambda),
    mean = function(p) p$lambda,
    var = function(p) p$lambda,
    support = function(p) c(0, 100)
  ),
  dunif = list(
    type = "discrete", range = c(0, 100),
    params = list(P("min", 0, 100, 1), P("max", 0, 100, 1)),
    # [修正] 現行アプリは dunif（連続一様の密度 1/(b-a)）を流用していたが、
    # 数式表示 1/n（n = b-a+1）と分散の定義に合わせて 1/(b-a+1) を使用する
    d = function(x, p) ifelse(x >= p$min & x <= p$max, 1 / (p$max - p$min + 1), 0),
    mean = function(p) (p$min + p$max) / 2,
    var = function(p) ((p$max - p$min + 1)^2 - 1) / 12,
    support = function(p) c(p$min, p$max),
    valid = function(p) p$min <= p$max
  )
)

# 値のグリッド（刻みで生成。端数は浮動小数の誤差を除く）
grid_values <- function(param) {
  v <- seq(param$min, param$max, by = param$step)
  round(v, 10)
}

# 平均・分散の値をJSON用に整える（NULL・非有限は NA = null）
moment_value <- function(f, p) {
  v <- tryCatch(f(p), error = function(e) NULL)
  if (is.null(v) || length(v) == 0 || !is.finite(v)) return(NA_real_)
  v
}

clean_curve <- function(y) {
  y[!is.finite(y)] <- NA_real_
  y
}

generate <- function(dist_id, def) {
  grids <- lapply(def$params, grid_values)
  names(grids) <- sapply(def$params, `[[`, "name")
  idx_grid <- expand.grid(lapply(grids, function(g) seq_along(g) - 1L))
  combos <- list()
  skipped <- 0L

  if (def$type == "continuous") {
    x <- seq(def$range[1], def$range[2], length.out = N_POINTS)
  }

  for (i in seq_len(nrow(idx_grid))) {
    idx <- as.integer(idx_grid[i, ])
    p <- lapply(seq_along(grids), function(j) grids[[j]][idx[j] + 1L])
    names(p) <- names(grids)
    if (!is.null(def$valid) && !def$valid(p)) {
      skipped <- skipped + 1L
      next
    }
    key <- paste(idx, collapse = ",")
    m <- moment_value(def$mean, p)
    v <- moment_value(def$var, p)
    if (def$type == "continuous") {
      pdf <- clean_curve(def$d(x, p))
      cdf <- clean_curve(def$p(x, p))
      if (!is.null(def$xfilter)) {
        keep <- def$xfilter(x, p)
        pdf[!keep] <- NA_real_
        cdf[!keep] <- NA_real_
      }
      combos[[key]] <- list(pdf = pdf, cdf = cdf, mean = m, var = v)
    } else {
      sup <- def$support(p)
      xs <- seq(sup[1], sup[2])
      pmf <- def$d(xs, p)
      pmf[!is.finite(pmf)] <- 0
      rounded <- signif(pmf, 4)
      nonzero <- which(rounded > 0)
      if (length(nonzero) == 0) {
        combos[[key]] <- list(x0 = as.integer(sup[1]), pmf = list(), mean = m, var = v)
      } else {
        lo <- min(nonzero); hi <- max(nonzero)
        combos[[key]] <- list(
          x0 = as.integer(xs[lo]),
          pmf = I(pmf[lo:hi]), # I() で長さ1でも配列のまま出力させる
          mean = m, var = v
        )
      }
    }
  }

  out <- list(
    dist = dist_id,
    type = def$type,
    params = names(grids),
    values = grids,
    combos = combos
  )
  if (def$type == "continuous") {
    out <- c(list(dist = dist_id, type = def$type, x = x), out[-(1:2)])
  }
  path <- file.path(OUT_DIR, paste0(dist_id, ".json"))
  writeLines(toJSON(out, auto_unbox = TRUE, digits = I(4), na = "null", pretty = FALSE), path)
  size_mb <- file.info(path)$size / 1e6
  cat(sprintf("%-9s combos=%6d (skipped %d)  %6.2f MB\n",
              dist_id, length(combos), skipped, size_mb))
  invisible(size_mb)
}

targets <- if (!is.null(ONLY)) ONLY else names(DISTS)
total <- 0
for (dist_id in targets) {
  total <- total + generate(dist_id, DISTS[[dist_id]])
}
cat(sprintf("TOTAL: %.2f MB\n", total))
