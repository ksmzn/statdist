#!/usr/bin/env Rscript
# statdist 生成データの検証スクリプト
#
# data/<dist>.json の中から各分布ごとに組み合わせをサンプルし、Rの統計関数で
# その場で再計算した値と突き合わせる。生成スクリプトとは独立に定義を書き直して
# あるので、生成側のタイプミスがあればここで検出できる。
# あわせて、現行アプリの数式と矛盾していた4件の修正（ベータ分散、対数正規分散、
# 離散一様PMF、t分布の平均の数式）が意図どおりになっているかを個別に確認する。
#
# 使い方: Rscript scripts/validate_data.R [データディレクトリ]

suppressMessages({
  library(jsonlite)
  library(hypergeo)
})

DATA_DIR <- if (length(commandArgs(trailingOnly = TRUE)) >= 1)
  commandArgs(trailingOnly = TRUE)[1] else "data"

set.seed(42)
failures <- 0
note_fail <- function(...) {
  failures <<- failures + 1
  cat("FAIL:", ..., "\n")
}
# 有効数字4桁の丸めを許容する比較
close_enough <- function(a, b) {
  if (is.null(b) || length(b) == 0 || !is.finite(b)) return(is.na(a) || is.null(a))
  if (is.na(a)) return(FALSE)
  abs(a - b) <= 2e-3 * max(1, abs(b))
}
check_val <- function(dist, key, what, stored, expected) {
  if (!close_enough(stored, expected))
    note_fail(dist, key, what, "stored=", stored, "expected=", expected)
}

# 独立に書き直した定義（d/p は密度・累積、mean/var は教科書どおりの式）
DEFS <- list(
  norm     = list(d = function(x, p) dnorm(x, p$mean, p$sd), p = function(x, p) pnorm(x, p$mean, p$sd),
                  mean = function(p) p$mean, var = function(p) p$sd^2),
  erlang   = list(d = function(x, p) dgamma(x, shape = p$shape, scale = p$scale), p = function(x, p) pgamma(x, shape = p$shape, scale = p$scale),
                  mean = function(p) p$shape * p$scale, var = function(p) p$shape * p$scale^2),
  f        = list(d = function(x, p) df(x, p$df1, p$df2), p = function(x, p) pf(x, p$df1, p$df2),
                  mean = function(p) p$df2 / (p$df2 - 2),
                  var = function(p) 2 * p$df2^2 * (p$df1 + p$df2 - 2) / (p$df1 * (p$df2 - 2)^2 * (p$df2 - 4))),
  ncf      = list(d = function(x, p) df(x, p$df1, p$df2, ncp = p$ncp), p = function(x, p) pf(x, p$df1, p$df2, ncp = p$ncp),
                  mean = function(p) if (p$df2 <= 2) NULL else p$df2 * (p$df1 + p$ncp) / (p$df1 * (p$df2 - 2)),
                  var = function(p) if (p$df2 <= 4) NULL else 2 * p$df2^2 * ((p$df1 + p$ncp)^2 + (p$df1 + 2 * p$ncp) * (p$df2 - 2)) / (p$df1^2 * (p$df2 - 2)^2 * (p$df2 - 4))),
  chisq    = list(d = function(x, p) dchisq(x, p$df), p = function(x, p) pchisq(x, p$df),
                  mean = function(p) p$df, var = function(p) 2 * p$df),
  ncChisq  = list(d = function(x, p) dchisq(x, p$df, ncp = p$ncp), p = function(x, p) pchisq(x, p$df, ncp = p$ncp),
                  mean = function(p) p$df + p$ncp, var = function(p) 2 * (p$df + 2 * p$ncp)),
  gamma    = list(d = function(x, p) dgamma(x, shape = p$shape, scale = p$scale), p = function(x, p) pgamma(x, shape = p$shape, scale = p$scale),
                  mean = function(p) p$shape * p$scale, var = function(p) p$shape * p$scale^2),
  cauchy   = list(d = function(x, p) dcauchy(x, p$location, p$scale), p = function(x, p) pcauchy(x, p$location, p$scale),
                  mean = function(p) NULL, var = function(p) NULL),
  exp_dist = list(d = function(x, p) dexp(x, p$rate), p = function(x, p) pexp(x, p$rate),
                  mean = function(p) 1 / p$rate, var = function(p) 1 / p$rate^2),
  lnormal  = list(d = function(x, p) dlnorm(x, p$meanlog, p$sdlog), p = function(x, p) plnorm(x, p$meanlog, p$sdlog),
                  mean = function(p) exp(p$meanlog + p$sdlog^2 / 2),
                  var = function(p) (exp(p$sdlog^2) - 1) * exp(2 * p$meanlog + p$sdlog^2)),
  t_dist   = list(d = function(x, p) dt(x, p$df), p = function(x, p) pt(x, p$df),
                  mean = function(p) 0, var = function(p) if (p$df <= 2) Inf else p$df / (p$df - 2)),
  nct      = list(d = function(x, p) dt(x, p$df, ncp = p$ncp), p = function(x, p) pt(x, p$df, ncp = p$ncp),
                  mean = function(p) if (p$df <= 1) NULL else p$ncp * sqrt(p$df / 2) * gamma((p$df - 1) / 2) / gamma(p$df / 2),
                  var = function(p) if (p$df <= 2) NULL else p$df * (1 + p$ncp^2) / (p$df - 2) - (p$ncp^2 * p$df / 2) * (gamma((p$df - 1) / 2) / gamma(p$df / 2))^2),
  beta     = list(d = function(x, p) dbeta(x, p$shape1, p$shape2), p = function(x, p) pbeta(x, p$shape1, p$shape2),
                  mean = function(p) p$shape1 / (p$shape1 + p$shape2),
                  var = function(p) p$shape1 * p$shape2 / ((p$shape1 + p$shape2)^2 * (p$shape1 + p$shape2 + 1))),
  ncbeta   = list(d = function(x, p) dbeta(x, p$shape1, p$shape2, ncp = p$ncp), p = function(x, p) pbeta(x, p$shape1, p$shape2, ncp = p$ncp),
                  mean = function(p) exp(-p$ncp / 2) * p$shape1 * genhypergeo(c(p$shape1 + 1, p$shape1 + p$shape2), c(p$shape1, 1 + p$shape1 + p$shape2), p$ncp / 2) / (p$shape1 + p$shape2),
                  var = function(p) { m <- exp(-p$ncp / 2) * p$shape1 * genhypergeo(c(p$shape1 + 1, p$shape1 + p$shape2), c(p$shape1, 1 + p$shape1 + p$shape2), p$ncp / 2) / (p$shape1 + p$shape2)
                    exp(-p$ncp / 2) * p$shape1 * (p$shape1 + 1) * genhypergeo(c(p$shape1 + 1, p$shape1 + p$shape2), c(p$shape1, 1 + p$shape1 + p$shape2), p$ncp / 2) / ((p$shape1 + p$shape2) * (p$shape1 + p$shape2 + 1)) - m^2 }),
  unif     = list(d = function(x, p) dunif(x, p$min, p$max), p = function(x, p) punif(x, p$min, p$max),
                  mean = function(p) (p$min + p$max) / 2, var = function(p) (p$max - p$min)^2 / 12),
  logis    = list(d = function(x, p) dlogis(x, p$location, p$scale), p = function(x, p) plogis(x, p$location, p$scale),
                  mean = function(p) p$location, var = function(p) (p$scale * pi)^2 / 3),
  weibull  = list(d = function(x, p) dweibull(x, p$shape, p$scale), p = function(x, p) pweibull(x, p$shape, p$scale),
                  mean = function(p) p$scale * gamma(1 + 1 / p$shape),
                  var = function(p) p$scale^2 * (gamma(1 + 2 / p$shape) - gamma(1 + 1 / p$shape)^2)),
  geom     = list(d = function(x, p) dgeom(x, p$prob),
                  mean = function(p) (1 - p$prob) / p$prob, var = function(p) (1 - p$prob) / p$prob^2),
  hyper    = list(d = function(x, p) dhyper(x, p$m, p$n, p$k),
                  mean = function(p) p$k * p$m / (p$m + p$n),
                  var = function(p) p$k * p$m * p$n * (p$m + p$n - p$k) / ((p$m + p$n)^2 * (p$m + p$n - 1))),
  binom    = list(d = function(x, p) dbinom(x, p$size, p$prob),
                  mean = function(p) p$size * p$prob, var = function(p) p$size * p$prob * (1 - p$prob)),
  nbinom   = list(d = function(x, p) dnbinom(x, p$size, p$prob),
                  mean = function(p) if (p$prob == 0) Inf else p$size / p$prob,
                  var = function(p) if (p$prob == 0) Inf else p$size * (1 - p$prob) / p$prob^2),
  pois     = list(d = function(x, p) dpois(x, p$lambda),
                  mean = function(p) p$lambda, var = function(p) p$lambda),
  dunif    = list(d = function(x, p) ifelse(x >= p$min & x <= p$max, 1 / (p$max - p$min + 1), 0),
                  mean = function(p) (p$min + p$max) / 2, var = function(p) ((p$max - p$min + 1)^2 - 1) / 12)
)

for (dist_id in names(DEFS)) {
  dat <- fromJSON(file.path(DATA_DIR, paste0(dist_id, ".json")),
                  simplifyVector = TRUE, simplifyDataFrame = FALSE)
  def <- DEFS[[dist_id]]
  keys <- names(dat$combos)
  sample_keys <- unique(c(keys[1], keys[length(keys)],
                          sample(keys, min(25, length(keys)))))
  for (key in sample_keys) {
    idx <- as.integer(strsplit(key, ",")[[1]])
    p <- lapply(seq_along(idx), function(j) dat$values[[j]][idx[j] + 1])
    names(p) <- dat$params
    combo <- dat$combos[[key]]
    check_val(dist_id, key, "mean", combo$mean, def$mean(p))
    check_val(dist_id, key, "var", combo$var, def$var(p))
    if (dat$type == "continuous") {
      xs <- dat$x
      pts <- unique(c(1, 125, 250, 375, 500, sample(500, 10)))
      exp_pdf <- def$d(xs[pts], p); exp_cdf <- def$p(xs[pts], p)
      for (k in seq_along(pts)) {
        stored_pdf <- combo$pdf[pts[k]]; stored_cdf <- combo$cdf[pts[k]]
        # x_filter で除かれた点は null になっているはず。それ以外を照合する
        if (!is.na(stored_pdf)) check_val(dist_id, key, paste0("pdf@", pts[k]), stored_pdf, exp_pdf[k])
        if (!is.na(stored_cdf)) check_val(dist_id, key, paste0("cdf@", pts[k]), stored_cdf, exp_cdf[k])
      }
    } else {
      if (length(combo$pmf) > 0) {
        xs <- combo$x0 + seq_along(combo$pmf) - 1
        exp_pmf <- def$d(xs, p)
        for (k in seq_along(xs))
          check_val(dist_id, key, paste0("pmf@", xs[k]), combo$pmf[k], exp_pmf[k])
        s <- sum(combo$pmf)
        # 幾何・負の二項は表示範囲（x <= 100）で台が切れるため、合計は
        # その範囲までの累積確率と一致すればよい。それ以外は合計1。
        expected_sum <- if (dist_id == "geom") {
          pgeom(max(xs), p$prob)
        } else if (dist_id == "nbinom") {
          pnbinom(max(xs), size = p$size, prob = p$prob)
        } else 1
        if (abs(s - expected_sum) > 0.01)
          note_fail(dist_id, key, "pmf sum", s, "expected", expected_sum)
      }
    }
  }
  cat(sprintf("%-9s sampled %d combos OK so far (failures=%d)\n",
              dist_id, length(sample_keys), failures))
}

# 修正4件の個別確認
cat("--- targeted checks ---\n")
beta <- fromJSON(file.path(DATA_DIR, "beta.json"),
                 simplifyVector = TRUE, simplifyDataFrame = FALSE)
# shape1=2, shape2=3: 値グリッドは 0,1,2,... なので index は (2,3)
bv <- beta$combos[["2,3"]]$var
cat("beta var(2,3) =", bv, "(correct 0.04, buggy 0.048)\n")
if (!close_enough(bv, 0.04)) note_fail("beta", "2,3", "variance fix", bv, 0.04)
ln <- fromJSON(file.path(DATA_DIR, "lnormal.json"),
               simplifyVector = TRUE, simplifyDataFrame = FALSE)
# meanlog=0 (index 15: -30,-28,...,0), sdlog=2 (index 4: 0,0.5,1,1.5,2)
lv <- ln$combos[["15,4"]]$var
expected_lv <- (exp(4) - 1) * exp(4)
cat("lnormal var(0,2) =", lv, "(correct", expected_lv, ", buggy", (exp(4) - 1) * exp(2), ")\n")
if (!close_enough(lv, expected_lv)) note_fail("lnormal", "15,4", "variance fix", lv, expected_lv)
du <- fromJSON(file.path(DATA_DIR, "dunif.json"),
               simplifyVector = TRUE, simplifyDataFrame = FALSE)
# min=2, max=5 (index そのまま): PMF は各 0.25、合計 1
dc <- du$combos[["2,5"]]
cat("dunif pmf(2..5) =", paste(dc$pmf, collapse = ","), "sum =", sum(dc$pmf), "\n")
if (!close_enough(sum(dc$pmf), 1)) note_fail("dunif", "2,5", "pmf fix", sum(dc$pmf), 1)
meta <- fromJSON(file.path(DATA_DIR, "meta.json"),
                 simplifyVector = TRUE, simplifyDataFrame = FALSE)
tmean <- Filter(function(d) d$id == "t_dist", meta$distributions)[[1]]$mean_str
cat("t_dist mean_str =", tmean, "\n")
if (tmean != "0") note_fail("meta", "t_dist", "mean_str fix", tmean, "0")

cat(if (failures == 0) "ALL CHECKS PASSED\n" else sprintf("%d FAILURES\n", failures))
