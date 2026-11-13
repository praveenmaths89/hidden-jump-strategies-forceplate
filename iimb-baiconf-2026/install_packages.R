# Install the R packages used by the pipeline (CRAN). Tested with R 4.5.3.
pk <- c("dplyr", "tidyr", "ggplot2", "patchwork", "nlme", "arrow", "jsonlite")
install.packages(setdiff(pk, rownames(installed.packages())), repos = "https://cloud.r-project.org")
