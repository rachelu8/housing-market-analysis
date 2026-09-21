packages <- c("tidyverse", "knitr", "rmarkdown", "corrplot", "forcats")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
