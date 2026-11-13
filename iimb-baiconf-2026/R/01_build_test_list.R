# =============================================================================
# 01_build_test_list.R  (R port of athlete_table() + deidentify() in the original
# Python pipeline, football-cmj-curve-analysis/scripts/02_process.py)
# Input : raw/vald/tests.csv, raw/vald/profiles.json,
#         raw/private_keys/03_athlete_sports_gender_mapping.csv (sport + sex, has names)
#         raw/private_keys/codebook.json (VALD id -> pseudonymous code key)
# Output: data/interim/tests_coverage.csv (one row per football test, no names)
# Check : compared with validation/tests_coverage_python_reference.csv
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(jsonlite) })
dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)

tests    <- read.csv("raw/vald/tests.csv", stringsAsFactors = FALSE)
profiles <- fromJSON("raw/vald/profiles.json")
mapping  <- read.csv("raw/private_keys/03_athlete_sports_gender_mapping.csv", stringsAsFactors = FALSE)
codebook <- fromJSON("raw/private_keys/codebook.json")

# football athletes; drop profiles with conflicting sex, keep first duplicate
mp <- mapping %>% filter(sport == "Football Overall Data") %>% select(profile_id, gender)
conflict <- mp %>% group_by(profile_id) %>% summarise(n = n_distinct(gender)) %>% filter(n > 1)
mp <- mp %>% filter(!profile_id %in% conflict$profile_id) %>%
  distinct(profile_id, .keep_all = TRUE) %>% rename(profileId = profile_id, sex = gender)

prof <- data.frame(profileId = profiles$profileId, dateOfBirth = profiles$dateOfBirth,
                   stringsAsFactors = FALSE)
t <- tests %>% inner_join(mp, by = "profileId") %>% left_join(prof, by = "profileId")
rec <- as.POSIXct(sub("Z$", "", t$recordedDateUtc), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
dob <- as.POSIXct(substr(t$dateOfBirth, 1, 19), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
days <- floor(as.numeric(difftime(rec, dob, units = "days")))   # pandas .dt.days = whole days
t$age <- round(days / 365.25, 1)                                  # rounded to 0.1 y for privacy
t$band <- as.character(cut(t$age, c(0, 13, 15, 17, 19, 99), right = FALSE,
                           labels = c("U13", "U15", "U17", "U19", "Senior")))
t$athlete   <- unname(unlist(codebook$athlete)[t$profileId])
t$test_code <- unname(unlist(codebook$test)[t$testId])

cov <- t %>% select(testType, sex, age, band, athlete, test_code)
write.csv(cov, "data/interim/tests_coverage.csv", row.names = FALSE)

# --- check against the coverage table written by the original Python pipeline
ref <- read.csv("validation/tests_coverage_python_reference.csv", stringsAsFactors = FALSE)
cmp <- merge(cov, ref, by = "test_code", suffixes = c("", ".ref"), all = TRUE)
same <- with(cmp, testType == testType.ref & sex == sex.ref & athlete == athlete.ref &
               ((is.na(age) & is.na(age.ref)) | abs(age - age.ref) < 1e-9))
cat(sprintf("[01] %d football tests built from raw; reference %d; identical rows %d; mismatches %d\n",
            nrow(cov), nrow(ref), sum(same, na.rm = TRUE), sum(!same | is.na(same))))
if (any(!same | is.na(same))) print(head(cmp[!same | is.na(same), ], 20))
