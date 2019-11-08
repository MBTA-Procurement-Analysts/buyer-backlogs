# approver-throughput.r
# Created by: Mickey Guo
# To get, tidy, and display throughput information for Approver

# NOTE: This file is a part of "buyer-backlogs.rmd" report, and it depends
#         on the dependencies of the report.


# Init, Library and Database Imports --------------------------------------

approval_historical_data_raw <- read_excel(approver_historical_data_path, skip = 1) 


# Data Wrangling ----------------------------------------------------------

approval_historical_data <- approval_historical_data_raw %>% 
  filter(`Worked_DTTM` >= (data_date - months(3)), Status == 2) %>% 
  mutate(Date = date(`Worked_DTTM`)) %>% 
  mutate(`WeekNo` = date.of.week(`Date`)) %>% 
  mutate_at("WeekNo", ~format(., "%m/%d/%y")) %>% 
  select(-Line, -`More Info`, -Amount, -`Worked_DTTM`, -Instance, -Selected_DTTM) %>% 
  distinct()

approval_historical_tibble <- approval_historical_data %>% 
  group_by(WeekNo) %>%
  summarize(Cnt = n()) %>% 
  spread(`WeekNo`, `Cnt`) %>% 
  replace(is.na(.), 0)
