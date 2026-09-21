# Run from the repository root: Rscript scripts/run_analysis.R
# Original exploratory work: August 2026. Reproducibility extension: September 21, 2026.
suppressPackageStartupMessages(library(ggplot2))
dir.create("results", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)
h <- read.csv("data/train.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
stopifnot(nrow(h) == 1460L, ncol(h) == 81L, !anyDuplicated(h$Id), all(h$SalePrice > 0))
before <- colSums(is.na(h))
set_none <- function(v, condition) { h[[v]][is.na(h[[v]]) & condition] <<- "None" }
set_none("PoolQC", h$PoolArea == 0)
set_none("FireplaceQu", h$Fireplaces == 0)
for (v in c("GarageType", "GarageFinish", "GarageQual", "GarageCond")) set_none(v, h$GarageCars == 0 & h$GarageArea == 0)
for (v in c("BsmtExposure", "BsmtFinType2", "BsmtQual", "BsmtCond", "BsmtFinType1")) set_none(v, h$TotalBsmtSF == 0)
set_none("MiscFeature", h$MiscVal == 0)
set_none("Alley", rep(TRUE, nrow(h)))
set_none("Fence", rep(TRUE, nrow(h)))
audit <- data.frame(variable = names(h), missing_before = before, missing_after = colSums(is.na(h)))
audit$structural_absence_recoded <- audit$missing_before - audit$missing_after
write.csv(audit, "results/missingness_audit.csv", row.names = FALSE)
nums <- setdiff(names(h)[vapply(h, is.numeric, logical(1))], c("Id", "SalePrice", "MSSubClass", "MoSold", "YrSold"))
cors <- data.frame(variable = nums, pearson = sapply(nums, function(v) cor(h[[v]], h$SalePrice, use="complete.obs")), spearman = sapply(nums, function(v) cor(h[[v]], h$SalePrice, use="complete.obs", method="spearman")))
cors <- cors[order(-abs(cors$pearson)), ]
write.csv(cors, "results/price_correlations.csv", row.names = FALSE)
write.csv(as.data.frame(table(h$GarageCars)), "results/garage_capacity_counts.csv", row.names = FALSE)
p <- ggplot(h, aes(GrLivArea, SalePrice)) + geom_point(alpha=.4, color="#24618C") + geom_smooth(method="lm", se=FALSE, color="#A34B27") + theme_minimal(base_size=12) + labs(title="Living area and sale price", x="Above-ground living area (sq ft)", y="Sale price (USD)")
ggsave("figures/living_area.png", p, width=8, height=5, dpi=160)
p <- ggplot(h, aes(reorder(Neighborhood, SalePrice, median), SalePrice)) + geom_boxplot(fill="#BDD8E8", outlier.alpha=.35) + coord_flip() + theme_minimal(base_size=11) + labs(title="Sale price by neighborhood", x=NULL, y="Sale price (USD)")
ggsave("figures/neighborhoods.png", p, width=8, height=7, dpi=160)
# Exploratory benchmark: prior full-data EDA means this is not a pristine holdout.
# Fixed numeric specification avoids rare category issues. No rows are removed as outliers.
set.seed(20260921)
train_idx <- sample(seq_len(nrow(h)), floor(.8*nrow(h)))
train <- h[train_idx, ]; test <- h[-train_idx, ]
features <- c("OverallQual", "GrLivArea", "YearBuilt", "GarageCars", "TotalBsmtSF", "FullBath")
stopifnot(!anyNA(h[c(features,"SalePrice")]))
fit <- lm(log(SalePrice) ~ OverallQual + GrLivArea + YearBuilt + GarageCars + TotalBsmtSF + FullBath, data=train)
# Duan smearing correction estimated on training residuals only.
smearing <- mean(exp(residuals(fit)))
pred <- exp(predict(fit, newdata=test))*smearing
baseline <- rep(mean(train$SalePrice), nrow(test))
score <- function(p) c(RMSE=sqrt(mean((test$SalePrice-p)^2)), MAE=mean(abs(test$SalePrice-p)), R2=1-sum((test$SalePrice-p)^2)/sum((test$SalePrice-mean(test$SalePrice))^2), RMSLE=sqrt(mean((log1p(test$SalePrice)-log1p(p))^2)))
metrics <- rbind(training_mean_baseline=score(baseline), log_linear_benchmark=score(pred))
write.csv(metrics, "results/benchmark_metrics.csv")
write.csv(data.frame(Id=test$Id, actual=test$SalePrice, predicted=pred), "results/benchmark_predictions.csv", row.names=FALSE)
write.csv(data.frame(Id=h$Id, split=ifelse(seq_len(nrow(h)) %in% train_idx,"train","test")), "results/split_assignment.csv", row.names=FALSE)
capture.output(summary(fit), file="results/model_summary.txt")
capture.output(sessionInfo(), file="results/session_info.txt")
print(data.frame(rows=nrow(h), fields=ncol(h), neighborhoods=length(unique(h$Neighborhood)), recoded=sum(audit$structural_absence_recoded), train=nrow(train), test=nrow(test)))
print(metrics)
p <- ggplot(h, aes(factor(OverallCond), SalePrice)) + geom_boxplot(fill="#BDD8E8") + theme_minimal(base_size=12) + labs(title="Sale price by overall condition",x="Overall condition rating",y="Sale price (USD)")
ggsave("figures/overall_condition.png",p,width=8,height=5,dpi=160)
