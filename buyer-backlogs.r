# buyer-backlogs.r
# Created by: Mickey Guo
# To display backlog req data for each buyer

# Note: This code is also a style experiment,
#       Variable names are in snake_case, 
#       Function names are in dot.case,
#       Function argument fields are in camelCase

# Init, Library, and File Imports -----------------------------------------

setwd("C:/Users/nguo/Documents/github/buyer-backlogs/")

library(tidyverse)
library(kableExtra)
library(readxl)
library(lubridate)
library(knitr)
library(plotly)
library(scales)
library(RColorBrewer)

# backlog_raw <- readxl::read_excel("data/MB_REQ_HOLD_REQS_NOT_SOURCED_1401443629_08302018.xlsx", skip = 1)
backlog_raw <- readxl::read_excel("data/collections/MB_REQ_HOLD_REQS_NOT_SOURCED_1145184834_09112018_1429.xlsx", skip = 1)

# date of data download from fmis
data_date <- ymd("2018-09-11")

# Constant Definitions ----------------------------------------------------

# Buyer Category Definition, now residing in a different file
source("buyer-group-definition.r")

# Buyer Category Factors, for ordering
buyer_cat_fct <- c("NINV", "SE", "INV")

# Tibble of Buyers and their Categories
buyers_cat<- bind_rows(sourcing_execs, inventory_buyers, non_inventory_buyers)

# Date to be used as Today. Use the dynamic definition unless otherwise needed.
date_now <- today()
# date_now <- ymd("2018-08-24")

# FROM date of the filtering
date_from <- ymd("2000-01-01")

# TO date of the filtering
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

backlog_hold <- backlog_raw %>% 
  filter(`Hold From Further Processing` == "Y")

backlog_out_to_bid <- backlog_raw %>%
  filter(`Out-to-Bid` == "Requested")

# DF/Tibble -> Tibble; Bins the Age for the incoming dataframe
age.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((Age >= 0 & Age < 30), 0,
                                  if_else((Age >= 30 & Age < 60), 30, 
                                          if_else((Age >= 60 & Age < 90), 60, 90))))
}

amount.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((`Req Total` >= 0 & `Req Total` < 250000), 0,
                                 if_else((`Req Total` >= 250000 & `Req Total` < 500000), 250000, 500000)))
}

# DF/Tibble -> Tibble; Sums bins and spread them into columns. Does not
#   remove NAs since we will do that later anyways.
bin.counts.hard <- function(data) {
  data %>% 
    group_by(Buyer, Bins) %>% 
    summarise(Cnt = n()) %>% 
    spread(Bins, Cnt) 
    #replace(is.na(.), 0)
}

backlog_bins_nohold <- backlog_nohold %>% 
  age.binning.hard() %>% 
  bin.counts.hard() %>% 
  rename(`0 to 30` = `0`, `30 to 60` = `30`, `60 to 90` = `60`, `90+` = `90`)


backlog_cnt_hold <- backlog_hold %>% 
  group_by(Buyer) %>% 
  summarise(`Hold Count` = n())

backlog_cnt_out_to_bid <- backlog_out_to_bid %>% 
  group_by(Buyer) %>% 
  summarise(`Out-to-Bid Count` = n())

backlog_all_table <- full_join(backlog_bins_nohold, backlog_cnt_hold, by = "Buyer") %>% 
  full_join(., backlog_cnt_out_to_bid, by = "Buyer") %>% 
  replace(is.na(.), 0) %>% 
  mutate(Total = `0 to 30` + `30 to 60` + `60 to 90` + `90+` + `Hold Count` + `Out-to-Bid Count`) %>% 
  left_join(., buyers_cat, by = "Buyer") %>% 
  select(Category, everything()) %>% 
  arrange(Category, Buyer)

backlog_kable_source <- backlog_all_table %>% 
  ungroup(Buyer) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2)

# Used to render kable, removed Category Column for manual grouping
backlog_subtotal_kable <- backlog_kable_source %>% 
  group_by(Category) %>% 
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>% 
  mutate(Buyer = "Subtotal") %>% 
  select(Category, Buyer, everything())

backlog_total_kable <- backlog_subtotal_kable %>% 
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>% 
  mutate(Buyer = " ", Category = "Total") %>% 
  select(Category, Buyer, everything())

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

backlog_out_to_bid_plot <- backlog_raw %>% filter(`Out-to-Bid` == "Requested") %>% group_by(Buyer) %>% summarize(OtBCnt = n ())

backlog_not_out_to_bid <- backlog_raw %>% filter(`Out-to-Bid` == "Not Requested") %>% filter(`Hold From Further Processing` == "N") %>% group_by(Buyer) %>% summarise(NOtBCnt = n())

backlog_on_hold <- backlog_hold %>% group_by(Buyer) %>% summarise(OnHoldCnt = n())

backlog_plot <- full_join(full_join(backlog_out_to_bid_plot, backlog_not_out_to_bid, by = "Buyer"), 
                          backlog_on_hold, by = "Buyer") %>% 
  replace(is.na(.), 0) %>% 
  full_join(.,buyers_cat, by = "Buyer") %>% 
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct)) %>% 
  select(Buyer, Category, everything()) %>% 
  rename(`Out-To-Bid` = `OtBCnt`, `Actionable` = `NOtBCnt`, `On Hold` = `OnHoldCnt`) %>% 
  gather(Type, Count, -Buyer, -Category) %>%
  arrange(Category, desc(Buyer)) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2)
