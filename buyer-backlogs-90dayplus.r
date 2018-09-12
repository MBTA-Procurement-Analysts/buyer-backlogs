# buyer-backlogs-90dayplus.r
# Created by: Mickey Guo
# To display backlog req data that is older than 90 days for each buyer

# NOTE: This file depends on the "buyer-backlogs.r" file and should not be
#         run by itself. Source the file above or run in an environment that
#         has sourced it. 



# Load Dependencies -------------------------------------------------------

#setwd("C:/Users/nguo/Documents/github/buyer-backlogs/")
#source("./buyer-backlogs.r")


# Data Wrangling ----------------------------------------------------------

backlog_raw_90dayplus <- backlog_raw %>% 
  filter(Age >= 90)

# Split on hold from non-hold ones
backlog_nohold_90dayplus <- backlog_raw_90dayplus %>%
  filter(`Hold From Further Processing` == "N" & `Out-to-Bid` == "Not Requested")

backlog_hold_90dayplus <- backlog_raw_90dayplus %>% 
  filter(`Hold From Further Processing` == "Y")

backlog_out_to_bid_90dayplus <- backlog_raw_90dayplus %>%
  filter(`Out-to-Bid` == "Requested")

backlog_cnt_nohold_90dayplus <- backlog_nohold_90dayplus %>% 
  group_by(Buyer) %>%
  summarise(`90+ Actionable Count` = n())

backlog_cnt_hold_90dayplus <- backlog_hold_90dayplus %>% 
  group_by(Buyer) %>% 
  summarise(`90+ On Hold Count` = n())

backlog_cnt_out_to_bid_90dayplus <- backlog_out_to_bid_90dayplus %>% 
  group_by(Buyer) %>% 
  summarise(`90+ Out-to-Bid Count` = n())

backlog_all_table_90days <- full_join(backlog_cnt_nohold_90dayplus, backlog_cnt_hold_90dayplus, by = "Buyer") %>% 
  full_join(., backlog_cnt_out_to_bid_90dayplus, by = "Buyer") %>% 
  replace(is.na(.), 0) %>% 
  left_join(., buyers_cat, by = "Buyer") %>% 
  select(Category, everything()) %>% 
  arrange(Category, Buyer)

backlog_plot_90dayplus <- backlog_all_table_90days %>% 
  rename(`Out-to-Bid` = `90+ Out-to-Bid Count`, `On Hold` = `90+ On Hold Count`, `Actionable` = `90+ Actionable Count`) %>% 
  gather(Type, Count, -Buyer, -Category) %>%
  arrange(Category, desc(Buyer)) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2)

