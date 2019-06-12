# buyer-backlogs-amounts.r
# Created by: Mickey Guo
# To display backlog req data that is binned by amount, instead of days.
# This section only applies to Reqs that is 90 day+ old.

# NOTE: This file depends on the "buyer-backlogs.r" and "buyer-backlogs-90dayplus.r" files
#         and should not be run by itself. Source the file above or run in an environment that
#         has sourced it. 

# Data Wrangling ----------------------------------------------------------

# Bins Reqs by Amounts
backlog_amt_bins_nohold_90dayplus <- backlog_nohold_90dayplus %>% 
  amount.binning.hard() %>% 
  bin.counts.hard() %>% 
  validate.amount.bins.hard() %>%
  select(Buyer, `0`, `250000`, `5e+05`) %>%
  rename(`< $250k` = `0`, `$250k to $500k` = `250000`, `$500k+` = `5e+05`)

# Creates Table of 90 day+ Reqs Count
# Actionable (Plain):(<$250k, $250 to $500k, $500k+), On Hold Counts, Out-to-bid Counts
backlog_amt_all_table <- full_join(backlog_amt_bins_nohold_90dayplus, backlog_cnt_hold_90dayplus, by = "Buyer") %>% 
  full_join(., backlog_cnt_out_to_bid_90dayplus, by = "Buyer") %>% 
  replace(is.na(.), 0) %>% 
  mutate(Total = `< $250k` + `$250k to $500k` + `$500k+` + `90+ On Hold Count` + `90+ Out-to-Bid Count`) %>% 
  left_join(., buyers_cat, by = "Buyer") %>% 
  select(Category, everything()) %>% 
  arrange(Category, Buyer)

# Abbreviates buyer names
backlog_amt_kable_source <- backlog_amt_all_table %>% 
  ungroup(Buyer) %>% 
  mutate_at("Buyer", substr, start = 0, stop = 2)

# DF/Tibble -> Tibble; Validate that all buyer categories exist, add 0-value column if not
validate.90dayplus.amt.kable.buyer.category <- function (data) {
  data <- if (data %>% filter(Category == "NINV") %>% nrow() == 0) {bind_rows(data, tibble(Category="NINV", "n()"=0))} else {data}
  data <- if (data %>% filter(Category == "SE") %>% nrow() == 0) {bind_rows(data, tibble(Category="SE", "n()"=0))} else {data}
  data <- if (data %>% filter(Category == "INV") %>% nrow() == 0) {bind_rows(data, tibble(Category="INV", "n()"=0))} else {data}
  data
}

# Categorizes Buyers
backlog_amt_kable_col_count <- backlog_amt_kable_source %>% 
  group_by(Category) %>% 
  summarise(n()) %>% 
  validate.90dayplus.amt.kable.buyer.category() %>% 
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct)) %>% 
  arrange(Category)

# Produces the Subtotoal lines (per buyer category) of the 90day+ kable
backlog_amount_subtotal_kable <- backlog_amt_kable_source %>% 
  group_by(Category) %>% 
  summarise_at(vars(everything(), -Buyer), sum) %>% 
  mutate(Buyer = "Subtotal") %>% 
  select(Category, Buyer, everything())

# Produces the "Total" line of the 90day+ kable
backlog_amount_total_kable <- backlog_amount_subtotal_kable %>% 
  summarise_at(vars(everything(), -Category, -Buyer), sum) %>% 
  mutate(Buyer = " ", Category = "Total") %>% 
  select(Category, Buyer, everything())

# Bind buyer categories and subtotal, total rows together to form the final kable
backlog_amount_kable <- bind_rows(
  filter(backlog_amt_kable_source, Category == "NINV"),
  filter(backlog_amount_subtotal_kable, Category == "NINV"),
  filter(backlog_amt_kable_source, Category == "SE"),
  filter(backlog_amount_subtotal_kable, Category == "SE"),
  filter(backlog_amt_kable_source, Category == "INV"),
  filter(backlog_amount_subtotal_kable, Category == "INV"), backlog_amount_total_kable) %>% 
  select(-Category)
