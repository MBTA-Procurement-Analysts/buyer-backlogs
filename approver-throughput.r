# approver-throughput.r
# Created by: Mickey Guo
# To get, tidy, and display throughput information for Approver

# NOTE: This file is a part of "buyer-backlogs.rmd" report, and it depends
#         on the dependencies of the report.


# Init, Library and Database Imports --------------------------------------

approver_historical_data_raw <- read_excel(approver_historical_data_path, skip = 1) 


# Data Wrangling ----------------------------------------------------------

# Tidy Procedures:
# - Drop unnecessary columns (User, Available_DTTM, Unit, Origin, Instance,
#     Selected_DTTM)
# - Filter by last 3 months by Worked_DTTM, and Status of 2
# - Dealing with PO Line with multiple observations of different amounts:
#   - Group by all but amount, created new column of max amount per PO Line
#   - Drop Amount column, this will make duplicate PO Lines have the same
#       (max) amount
#   - distinct() on all 
# - Dealing with multiple buyers in the same PO:
#   - Sort by PO# and Descending Worked_DTTM
#   - distinct() by OperID (BuyerID)
#   * This workes since distinct() keeps only first found instance

approver_historical_data_all <- approver_historical_data_raw %>% 
  select(-User, -Available_DTTM, -Unit, -Origin, -Instance, -Selected_DTTM) %>% 
  filter(`Worked_DTTM` >= (data_date - weeks(13)), Status == 2) %>% 
  group_by_at(vars(everything(), -Amount)) %>% 
  summarise(Max_Amount = max(Amount)) %>% 
  ungroup() %>% 
  arrange(`PO No.`, desc(Worked_DTTM)) %>% 
  distinct(Status, `PO No.`, `Line`, `More Info`, `Max_Amount`, .keep_all=TRUE)
  
# Mutate Procedures:
# - Extract Date from Worked_DTTM (downstream function can't take timestamps)
# - Calculate the Sunday of the week, formats it as string
# - Unselect Line Specific information, calculate sum amount for PO
approver_historical_data_all <- approver_historical_data_all %>% 
  mutate(Date = date(`Worked_DTTM`)) %>% 
  mutate(`WeekNo` = date.of.week(`Date`)) %>% 
  mutate_at("WeekNo", ~format(., "%m/%d/%y")) %>% 
  select(-Line, -`More Info`, -`Worked_DTTM`) %>% 
  group_by_at(vars(everything(), -Max_Amount)) %>% 
  summarise(Total_Amount = sum(Max_Amount)) %>% 
  ungroup()

# Split All from Over 50k 
approver_historical_data_over50k <- approver_historical_data_all %>% 
  filter(Total_Amount > 500000)


# Last select() call is for dropping the first week (column).
# Since in upstream the data is filtered by weeks from data date (today), the
#   first week will likely contain impartial data, making the counts of POs
#   for that week inaccurate. Thus is it dropped.
approver_historical_tibble_all <- approver_historical_data_all %>%
  group_by(WeekNo) %>%
  summarize(Cnt = n()) %>% 
  spread(`WeekNo`, `Cnt`) %>% 
  replace(is.na(.), 0) %>% 
  select(-c(1))

approver_historical_tibble_over50k <- approver_historical_data_over50k %>% 
  group_by(WeekNo) %>%
  summarize(Cnt = n()) %>% 
  spread(`WeekNo`, `Cnt`) %>% 
  replace(is.na(.), 0) %>% 
  select(-c(1))

approver_historical_tibble <- 
  bind_rows(approver_historical_tibble_all, approver_historical_tibble_over50k) %>% 
  bind_cols(tibble(" " = c("All", "50k+")), .)
