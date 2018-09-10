# buyer-backlogs-amounts.r
# Created by: Mickey Guo
# To display backlog req data that is binned by amount, instead of days.

# NOTE: This file depends on the "buyer-backlogs.r" and "buyer-backlogs-90dayplus.r" files
#         and should not be run by itself. Source the file above or run in an environment that
#         has sourced it. 


# Load Dependencies -------------------------------------------------------

 setwd("C:/Users/nguo/Documents/github/buyer-backlogs/")
 source("./buyer-backlogs.r")
 source("./buyer-backlogs-90dayplus.r")

# Data Wrangling ----------------------------------------------------------

backlog_amt_bins_nohold <- backlog_nohold_90dayplus %>% 
  amount.binning.hard() %>% 
  bin.counts.hard() %>% 
  rename(`< $250k` = `0`, `$250k to $500k` = `250000`, `$500k+` = `5e+05`)

backlog_amt_all_table <- full_join(backlog_amt_bins_nohold, backlog_cnt_hold_90dayplus, by = "Buyer") %>% 
  full_join(., backlog_cnt_out_to_bid_90dayplus, by = "Buyer") %>% 
  replace(is.na(.), 0) %>% 
  mutate(Total = `< $250k` + `$250k to $500k` + `$500k+` + `90+ On Hold Count` + `90+ Out-to-Bid Count`) %>% 
  left_join(., buyers_cat, by = "Buyer") %>% 
  select(Category, everything()) %>% 
  arrange(Category, Buyer)

# Used to render kable, removed Category Column for manual grouping
backlog_amount_subtotal_kable <- backlog_amt_all_table %>% 
  group_by(Category) %>% 
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>% 
  mutate(Buyer = "Subtotal") %>% 
  select(Category, Buyer, everything())

backlog_amount_total_kable <- backlog_amount_subtotal_kable %>% 
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>% 
  mutate(Buyer = " ", Category = "Total") %>% 
  select(Category, Buyer, everything())

backlog_amount_kable <- bind_rows(
  filter(backlog_amt_all_table, Category == "NINV"),
  filter(backlog_amount_subtotal_kable, Category == "NINV"),
  filter(backlog_amt_all_table, Category == "SE"),
  filter(backlog_amount_subtotal_kable, Category == "SE"),
  filter(backlog_amt_all_table, Category == "INV"),
  filter(backlog_amount_subtotal_kable, Category == "INV"), backlog_amount_total_kable) %>% 
  select(-Category)
