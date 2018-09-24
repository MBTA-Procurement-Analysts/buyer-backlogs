# approver-backlogs.r
# Created by: Mickey Guo
# To get, tidy, and display backlog information for Approver (Peter)

# NOTE: This file is a part of "buyer-backlogs.rmd" report, and it depends
#         on the dependencies of the report. 


# Init, File Imports ------------------------------------------------------

library(scales)

approval_raw <- readxl::read_excel(approver_data_path, skip = 1)

# Function Definition -----------------------------------------------------

# Dollar Formatting for Tables
usd <- dollar_format(largest_with_cents = 1e+15, prefix = "$")

# Data Wrangling ----------------------------------------------------------

approval_raw <- approval_raw %>% 
  mutate(Age = date_now - date(`Date/Time`))

# DF/Tibble -> Tibble; Bins the Age for the incoming dataframe, designed for approver use
approver.age.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((Age >= 0 & Age < 7), 0,
                                 if_else((Age >=7 & Age < 14), 7, 
                                         if_else((Age >= 14 & Age < 30), 14, 30))))
}

approver.amount.binning.hard <- function(data) {
  data %>% mutate(Bins = if_else((`Sum_of_PO_Amt` >= 0 & `Sum_of_PO_Amt` < 250000), 0,
                                 if_else((`Sum_of_PO_Amt` >= 250000 & `Sum_of_PO_Amt` < 500000), 250000, 500000)))
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

approver_cnt_bins <- approval_raw %>% 
  approver.age.binning.hard() %>% 
  approver.bin.counts.hard() %>%
  rename(`0 to 7` = `0`, `7 to 14` = `7`, `14 to 30` = `14`, `30+` = `30`)
  

approver_amt_bins <- approval_raw %>% 
  approver.amount.binning.hard() %>% 
  approver.bin.counts.hard() %>% 
  rename(`< $250k` = `0`, `$250k to $500k` = `250000`, `$500k+` = `5e+05`)

approval_kable <- bind_cols(approver_cnt_bins, approver_amt_bins) %>% 
  mutate(Total = `0 to 7` + `7 to 14` + `14 to 30` + `30+`)

approval_30days_detail_table <- approval_raw %>% 
  #filter(Age >= 30) %>% 
  mutate(`Line 1 Description` = c(""), `Req Approval Date` = c(""), `Requisitioner` = c(" ")) %>% 
  rename(`Worklist Time` = `Date/Time`, `Amount` = `Sum_of_PO_Amt`) %>% 
  mutate_at("Amount", usd) %>% 
  arrange(desc(Age)) %>% 
  select(`Age`, `PO No.`, `Worklist Time`, `Amount`, `Line 1 Description`, `Req Approval Date`, `Requisitioner`)

approval_30days_count <- count(approval_30days_detail_table)
