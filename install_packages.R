# install_packages.R - installs the CRAN packages used by R/run_all.R (versions used are in packages.csv)
pk <- read.csv("packages.csv")$package
install.packages(setdiff(pk, rownames(installed.packages())), repos = "https://cloud.r-project.org")
