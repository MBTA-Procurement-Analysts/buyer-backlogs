# approver-backlogs.r
# Created by: Mickey Guo
# To get, tidy, and display backlog information for Approver

# NOTE: This file is a part of "buyer-backlogs.rmd" report, and it depends
#         on the dependencies of the report.

# Init, File Imports ------------------------------------------------------

library(scales)

# source functions that gets rubixs data
source("./rubix_getter.r")

approver_raw <- readxl::read_excel(approver_data_path, skip = 1)

# Function Definition -----------------------------------------------------

# Dollar Formatting for Tables
usd <- dollar_format(largest_with_cents = 5000, prefix = "$")

# Data Wrangling ----------------------------------------------------------

# Data Processing for raw data before 2018-10-11, those older data has
#   duplication in Sum amount on the FMIS query level, and the downstream
#   categorization of <$50K is affected. 
# This function is left here for future references.

# approver_raw <- approver_raw %>% 
#   distinct(`PO No.`, .keep_all = TRUE) %>% 
#   mutate(Age = date_now - date(`Date/Time`))

# Deduped since upstream query returns duplicate data

approver_raw <- approver_raw %>% 
  distinct(`PO No.`, `Line`, `Amount`, .keep_all = TRUE) %>% 
  group_by(`PO No.`) %>% 
  mutate(`Sum_of_PO_Amt` = sum(`Amount`)) %>% 
  select(-Line, -Amount) %>% 
  distinct(`PO No.`, .keep_all = TRUE) %>% 
  mutate(Age = date_now - date(`Date/Time`)) %>% 
  ungroup(`PO No.`)

# DF/Tibble -> Tibble; Bins the Age for the incoming dataframe, designed for approver use
approver.age.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((Age >= 0 & Age < 7), 0,
                                 if_else((Age >=7 & Age < 14), 7, 
                                         if_else((Age >= 14 & Age < 30), 14, 30))))
}

# DF/Tibble -> Tibble; Bins the Amount for the incoming dataframe, designed for approver use
approver.amount.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((`Sum_of_PO_Amt` >= 0 & `Sum_of_PO_Amt` < 50000), 0,
                                 if_else((`Sum_of_PO_Amt` >= 50000 & `Sum_of_PO_Amt` < 250000), 50000, 
                                         if_else((`Sum_of_PO_Amt` >= 250000 & `Sum_of_PO_Amt` < 500000), 250000, 500000))))
}

# DF/Tibble -> Tibble; Sums bins and spread them into columns. Does not
#   remove NAs since we will do that later anyways. Designed for approver use (Removed Buyer Groups)
approver.bin.counts.hard <- function(data) {
  data %>% 
    group_by(Bins) %>% 
    summarise(Cnt = n()) %>% 
    spread(Bins, Cnt) 
  #replace(is.na(.), 0)
}

# DF/Tibble -> Tibble; Creates Bin Columns of 0s in case column is not present, for approver amount bins
validate.approver.amt.bins.hard <- function(data) {
  data <- if (!has_name(data, "0")) {mutate(data, `0` = c(0))} else {data}
  data <- if (!has_name(data, "50000")) {mutate(data, `50000` = c(0))} else {data}
  data <- if (!has_name(data, "250000")) {mutate(data, `250000` = c(0))} else {data}
  data <- if (!has_name(data, "5e+05")) {mutate(data, `5e+05` = c(0))} else {data}
  data
}

# DF/Tibble -> Tibble; Creates Bin Columns of 0s in case column is not present, for approver count bins
validate.approver.cnt.bins.hard <- function(data) {
  data <- if (!has_name(data, "0")) {mutate(data, `0` = c(0))} else {data}
  data <- if (!has_name(data, "7")) {mutate(data, `7` = c(0))} else {data}
  data <- if (!has_name(data, "14")) {mutate(data, `14` = c(0))} else {data}
  data <- if (!has_name(data, "30")) {mutate(data, `30` = c(0))} else {data}
  data
}

# Applies Age binning to approver backlogs
approver_cnt_bins <- approver_raw %>% 
  approver.age.binning.hard() %>% 
  approver.bin.counts.hard() %>%
  validate.approver.cnt.bins.hard() %>%
  # re-arrange data since the func above will mess with order when triggered
  select(`0`, `7`, `14`, `30`) %>%
  rename(`0 to 7` = `0`, `7 to 14` = `7`, `14 to 30` = `14`, `30+` = `30`)

# Applies Age binning to approver backlogs
approver_amt_bins <- approver_raw %>% 
  approver.amount.binning.hard() %>% 
  approver.bin.counts.hard() %>% 
  validate.approver.amt.bins.hard() %>%
  # re-arrange data since the func above will mess with order when triggered
  select(`0`, `50000`, `250000`, `5e+05`) %>%
  rename(`< $50k` = `0`, `$50k to $250k` = `50000`, `$250k to $500k` = `250000`, `$500k+` = `5e+05`)

# Kable for Approver Overview Table, with Age bins and Amount bins, and totals
approver_kable <- bind_cols(approver_cnt_bins, approver_amt_bins) %>% 
  mutate(Total = `0 to 7` + `7 to 14` + `14 to 30` + `30+`)

# PO side of the Approver backlog detailed table.
# (PO No., Amount, Worklist Age)
# Note that the detailed table only shows entries over $50k
approver_detail_table_po <- approver_raw %>% 
  filter(`Sum_of_PO_Amt` >= 50000) %>% 
  rename(`Worklist Time` = `Date/Time`, `Amount` = `Sum_of_PO_Amt`, `Worklist Age` = `Age`) %>% 
  mutate_at("Amount", usd) %>% 
  select(`PO No.`, `Amount`, `Worklist Age`)

# Req size of the Approver backlog detailed table.
# (Line 1 Description, Buyer, Approval Date)
# Note that the detailed table only shows entries over $50k
approver_detail_table_req <- approver_raw %>%
  filter(`Sum_of_PO_Amt` >= 50000) %>% 
  select(`PO No.`) %>%
  as_vector() %>%
  get.reqs.tibble() %>% 
  rename(`Line 1 Description` = `req_description`, `Req Approval Date` = `req_approval_date`, `Buyer` = `req_buyer`) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2) 

# Combines the Req and PO size of the detailed table, calculates the Req age,
#   then puts it at the front and sort by it.
approver_detail_table <- bind_cols(approver_detail_table_po, approver_detail_table_req) %>% 
  mutate(`Overall Age` = date_now - `Req Approval Date` ) %>% 
  select(`Overall Age`, everything(), -`Req Approval Date`) %>% 
  arrange(desc(`Overall Age`))

# Number of entries that the detail table (>= $50k) have
approver_detail_count <- count(approver_detail_table)

# Total number of entries that the approver have, to calculate the # of omitted
#   entries from the detail table.
approver_total_count <-count(approver_raw)
