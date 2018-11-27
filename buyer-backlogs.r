# buyer-backlogs.r
# Created by: Mickey Guo
# To Wrangle Data for Req Backlog Data per Buyer

# Note: This code is also a style experiment,
#       Variable names are in snake_case,
#       Function names are in dot.case,
#       Function argument fields are in camelCase

# Init, Library, and File Imports -----------------------------------------

#setwd("/home/ubuntu/Projects/buyer-backlogs/")

library(tidyverse)
library(kableExtra)
library(readxl)
library(knitr)
library(plotly)
library(scales)
library(RColorBrewer)

backlog_raw <- readxl::read_excel(backlog_data_path, skip = 1)

# Constant Definitions ----------------------------------------------------

# Buyer Category Definition, now residing in a different file
source("buyer-group-definition.r")

# Buyer Category Factors, for ordering
buyer_cat_fct <- c("NINV", "SE", "INV")

# Tibble of Buyers and their Categories
buyers_cat<- bind_rows(sourcing_execs, inventory_buyers, non_inventory_buyers)

# Date to be used as Today. Use the dynamic definition unless otherwise needed.
date_now <- today()
# date_now <- ymd("2018-09-24")

# FROM date of the filtering
date_from <- ymd("2000-01-01")

# TO date of the filtering, end of current FY
date_to <- ymd("2019-06-30")

# (Util) Function Definitions ---------------------------------------------

# Date -> Int; Outputs the FY of the given date
get.fy <- function(givenDate) {
  if (month(givenDate) < 7) {year(givenDate)} else {year(givenDate) + 1}
}

# Date -> Bool; Checks if the given date is in current FY
is.current.fy <- function(givenDate) {
  get.fy(today()) == get.fy(givenDate)
}

# Date, Int -> Bool; Checks if the given date is in the given FY
is.given.fy <- function(givenDate, intGivenFy) {
  get.fy(givenDate) == intGivenFy
}

# DF/Tibble, String -> DF/Tibble; removes NA from a specific column
na.rm.at <- function(data, colName) {
  data %>% filter(!is.na(!!enquo(colName)))
}

# Data Wrangling ----------------------------------------------------------

# Add "days ago" field, buyer category, and filters out any buyers that is
#   not in the buyers_cat table above. Also removed NA buyers.
backlog_raw <- backlog_raw %>%
  mutate(Age = date_now - date(`Date of Approval`)) %>%
  select(Age, everything()) %>%
  full_join(., buyers_cat, by = "Buyer") %>%
  na.rm.at(Buyer) %>%
  na.rm.at(Category) %>%
  filter(`Date of Approval` >= date_from & `Date of Approval` <= date_to) %>%
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct))

# Split on hold from non-hold ones
backlog_nohold <- backlog_raw %>%
  filter(`Hold From Further Processing` == "N" & `Out-to-Bid` == "Not Requested")

# NOTE: In a perfect world, Holds and Out-to-Bid status should be mutually
#         exclusive -- there should not be cases where a Req has both statuses.
#         However, some Reqs might not have their hold status removed in FMIS, 
#         and when they are sent out to bid, both hold and out-to-bid markers
#         would be true in FMIS. Thus, to prevent double counting, this code will
#         will assume all Reqs with both Hold and Out-to-bid status are not on hold
#         and are out-to-bid only; hence the filtering below.
backlog_hold <- backlog_raw %>%
  filter(`Hold From Further Processing` == "Y" & !`Out-to-Bid` == "Requested")

# Split Out-to-bid
backlog_out_to_bid <- backlog_raw %>%
  filter(`Out-to-Bid` == "Requested")

# DF/Tibble -> Tibble; Bins the Age for the incoming dataframe
age.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((Age >= 0 & Age < 30), 0,
                                 if_else((Age >= 30 & Age < 60), 30,
                                         if_else((Age >= 60 & Age < 90), 60, 90))))
}

# DF/Tibble -> Tibble; Bins the amount for the incoming dataframe
amount.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((`Req Total` >= 0 & `Req Total` < 250000), 0,
                                 if_else((`Req Total` >= 250000 & `Req Total` < 500000), 250000, 500000)))
}

# DF/Tibble -> Tibble; Sums bins and spread them into columns. Does not
#   remove NAs since we will do that later anyways.
# NOTE: If a bin is not present in the data, the corresponding column will NOT
#         be created. Function 'validate.~.bins.hard()' is designed to patch this.
bin.counts.hard <- function(data) {
  data %>%
    group_by(Buyer, Bins) %>%
    summarise(Cnt = n()) %>%
    spread(Bins, Cnt)
  #replace(is.na(.), 0)
}

# DF/Tibble -> Tibble; Creates Bin Columns of 0s in case not present, for Amount bins
validate.amount.bins.hard <- function(data) {
  data <- if (!has_name(data, "0")) {mutate(data, `0` = c(0))} else {data}
  data <- if (!has_name(data, "250000")) {mutate(data, `250000` = c(0))} else {data}
  data <- if (!has_name(data, "5e+05")) {mutate(data, `5e+05` = c(0))} else {data}
  data
}

# DF/Tibble -> Tibble; Creates Bin Columns of 0s in case not present, for Age bins
validate.age.bins.hard <- function(data) {
  data <- if (!has_name(data, "0")) {mutate(data, `0` = c(0))} else {data}
  data <- if (!has_name(data, "30")) {mutate(data, `30` = c(0))} else {data}
  data <- if (!has_name(data, "60")) {mutate(data, `60` = c(0))} else {data}
  data <- if (!has_name(data, "90")) {mutate(data, `90` = c(0))} else {data}
  data
}

# Applies binning to Reqs not on hold & not out-to-bid
backlog_bins_nohold <- backlog_nohold %>%
  age.binning.hard() %>%
  bin.counts.hard() %>%
  validate.age.bins.hard() %>%
  # re-arrange data since the func above will mess with order when triggered
  select(Buyer, `0`, `30`, `60`, `90`) %>%
  rename(`0 to 30` = `0`, `30 to 60` = `30`, `60 to 90` = `60`, `90+` = `90`)

# Hold Count
backlog_cnt_hold <- backlog_hold %>%
  group_by(Buyer) %>%
  summarise(`Hold Count` = n())

# Out-to-bit Count
backlog_cnt_out_to_bid <- backlog_out_to_bid %>%
  group_by(Buyer) %>%
  summarise(`Out-to-Bid Count` = n())

# Summary Table Binning by Age for All Backlogs
# Joins Regular, On Hold, and Out-to-bid tables, add total count and category
backlog_all_table <- full_join(backlog_bins_nohold, backlog_cnt_hold, by = "Buyer") %>%
  full_join(., backlog_cnt_out_to_bid, by = "Buyer") %>%
  replace(is.na(.), 0) %>%
  mutate(Total = `0 to 30` + `30 to 60` + `60 to 90` + `90+` + `Hold Count` + `Out-to-Bid Count`) %>%
  left_join(., buyers_cat, by = "Buyer") %>%
  select(Category, everything()) %>%
  arrange(Category, Buyer)

# Abbreviate Buyer Names for Kable output
backlog_kable_source <- backlog_all_table %>%
  ungroup(Buyer) %>%
  mutate_at("Buyer", substr, start = 0, stop = 2)

# Subtotal by category, for Kable output
backlog_subtotal_kable <- backlog_kable_source %>%
  group_by(Category) %>%
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>%
  mutate(Buyer = "Subtotal") %>%
  select(Category, Buyer, everything())

# Total Count of all backlog Reqs, for Kable Output
backlog_total_kable <- backlog_subtotal_kable %>%
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>%
  mutate(Buyer = " ", Category = "Total") %>%
  select(Category, Buyer, everything())

# Combine source, subtotal and total in the correct order, hide categories
backlog_kable <- bind_rows(
                           filter(backlog_kable_source, Category == "NINV"),
                           filter(backlog_subtotal_kable, Category == "NINV"),
                           filter(backlog_kable_source, Category == "SE"),
                           filter(backlog_subtotal_kable, Category == "SE"),
                           filter(backlog_kable_source, Category == "INV"),
                           filter(backlog_subtotal_kable, Category == "INV"), backlog_total_kable) %>%
select(-Category)


# Number of Rows per category, for auto-adjusting groups and styles for the kable
backlog_age_kable_col_count <- backlog_kable_source %>%
  group_by(Category) %>%
  summarise(n()) %>%
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct)) %>%
  arrange(Category)

# Buyer Stacked Bar Graph -------------------------------------------------

# Buyers and their out-to-bit count
backlog_out_to_bid_plot <- backlog_raw %>% filter(`Out-to-Bid` == "Requested") %>% group_by(Buyer) %>% summarize(OtBCnt = n ())

# Buyers and their regular backlog count
backlog_not_out_to_bid <- backlog_raw %>% filter(`Out-to-Bid` == "Not Requested") %>% filter(`Hold From Further Processing` == "N") %>% group_by(Buyer) %>% summarise(NOtBCnt = n())

# Buyers and their on hold count
backlog_on_hold <- backlog_hold %>% group_by(Buyer) %>% summarise(OnHoldCnt = n())

# Join the 3 tables above, add Buyer Category, Rename Rows, Transpose the count, and abbreviate the Buyer name
backlog_plot <- full_join(full_join(backlog_out_to_bid_plot, backlog_not_out_to_bid, by = "Buyer"), backlog_on_hold, by = "Buyer") %>%
  replace(is.na(.), 0) %>%
  full_join(.,buyers_cat, by = "Buyer") %>%
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct)) %>%
  select(Buyer, Category, everything()) %>%
  rename(`Out-To-Bid` = `OtBCnt`, `Actionable` = `NOtBCnt`, `On Hold` = `OnHoldCnt`) %>%
  gather(Type, Count, -Buyer, -Category) %>%
  arrange(Category, desc(Buyer)) %>%
  mutate_at("Buyer", substr, start = 0, stop = 2)


# Omitted Buyer Display for the Bar Graph ---------------------------------

active_buyers <- backlog_all_table %>% ungroup(Buyer) %>% select(Buyer)
all_buyers <- buyers_cat %>% select(Buyer)

hidden_buyers <- anti_join(all_buyers, active_buyers) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2)
