# time_machine-graphs.r
# Created by: Mickey Guo
# To grab data from mongo-timemachine and make graphs out of them 

# NOTE: This file is a part of "buyer-backlogs.rmd" report, and it depends
#         on the dependencies of the report.


# Init, Library Imports ---------------------------------------------------

library(mongolite)
library(jsonlite)

db_url <- if (Sys.info()[[1]] == "Linux") {"mongodb://127.0.0.1:27017"} else {"mongodb://10.108.198.117:27017"}


# Approver Backlog Graphs -------------------------------------------------

# Re-using connections, see notes around L54 in this file. 
# mongo_approval_worklist <- mongo(collection = "timemachine_pp_worklist", db = "test", url = db_url)

# Export to temp file
mongo_approval_worklist$export(file("approval_worklist_timemachine.json"))

# Read temp file as Dataframe
approval_worklist_timemachine_json <- stream_in(file("approval_worklist_timemachine.json"))

# Slice mongodb id off and tibble conversion, otherwise as_tibble won't work 
approval_worklist_timemachine <- as_tibble(approval_worklist_timemachine_json[2:11])

# New Function of Wrangling Approver Backlog:
# This function simply filters non-PP (<$50k) entries, per discussion of the total amount of backlogs
#   being no longer necessary.
approval_worklist_timemachine <- approval_worklist_timemachine %>% 
  filter(Sum_of_PO_Amt >= 50000) %>% 
  group_by(Archive_Time) %>% 
  summarize(Cnt = n()) 


# Buyers Backlog Graphs ---------------------------------------------------

# Re-using the connections from the time_machine-mongo.r file, so we don't need
#   them in the pipeline. But they are still useful for debug so don't break
#   their dreams.

# mongo_backlog_plain <- mongo(collection = "timemachine_backlog_plain", db = "test", url = db_url)
# mongo_backlog_hold <- mongo(collection = "timemachine_backlog_hold", db = "test", url = db_url)
# mongo_backlog_out_to_bid <- mongo(collection = "timemachine_backlog_out_to_bid", db = "test", url = db_url)

mongo_backlog_plain$export(file("timemachine_backlog_plain.json"))
mongo_backlog_hold$export(file("timemachine_backlog_hold.json"))
mongo_backlog_out_to_bid$export(file("timemachine_backlog_out_to_bid.json"))

backlog_plain_timemachine_json <- stream_in(file("timemachine_backlog_plain.json"))
backlog_hold_timemachine_json <- stream_in(file("timemachine_backlog_hold.json"))
backlog_out_to_bid_timemachine_json <- stream_in(file("timemachine_backlog_out_to_bid.json"))

backlog_plain_timemachine_raw <- as_tibble(backlog_plain_timemachine_json[2:16])
backlog_hold_timemachine_raw <- as_tibble(backlog_hold_timemachine_json[2:16])
backlog_out_to_bid_timemachine_raw <- as_tibble(backlog_out_to_bid_timemachine_json[2:16])

# DF/Tibble , bool -> Tibble
# Summarizes Data for Buyer Backlog Timemachine Trend Graphs
# Copying code to 6 different places is hard, so...
summarize.time.machine.hard <- function(data, is90dayPlus) {
  if (is90dayPlus) {
    data <- data %>% filter(Age >= 90)
  }
  data %>% 
    group_by(Archive_Time, Category) %>% 
    summarize(Cnt = n()) %>% 
    ungroup(Archive_Time)
}

backlog_plain_timemachine_90dayplus <- summarize.time.machine.hard(backlog_plain_timemachine_raw, TRUE)
backlog_hold_timemachine_90dayplus <- summarize.time.machine.hard(backlog_hold_timemachine_raw, TRUE)
backlog_out_to_bid_timemachine_90dayplus <- summarize.time.machine.hard(backlog_out_to_bid_timemachine_raw, TRUE)

backlog_plain_timemachine <- summarize.time.machine.hard(backlog_plain_timemachine_raw, FALSE)
backlog_hold_timemachine <- summarize.time.machine.hard(backlog_hold_timemachine_raw, FALSE)
backlog_out_to_bid_timemachine <- summarize.time.machine.hard(backlog_out_to_bid_timemachine_raw, FALSE)


# Buyer Backlog Over 90 Days (Summing Plain/Hold/Out-to-Bids) -------------

backlog_plain_timemachine_90dayplus_sum <- backlog_plain_timemachine_90dayplus %>% 
  rename(`plainCnt` = `Cnt`)
backlog_hold_timemachine_90dayplus_sum <- backlog_hold_timemachine_90dayplus %>% 
  rename(`holdCnt` = `Cnt`)
backlog_out_to_bid_timemachine_90dayplus_sum <- backlog_out_to_bid_timemachine_90dayplus %>% 
  rename(`out_to_bidCnt` = `Cnt`)

backlog_timemachine_90dayplus_sum <- 
  full_join(
    full_join(backlog_plain_timemachine_90dayplus_sum, 
              backlog_hold_timemachine_90dayplus_sum), 
    backlog_out_to_bid_timemachine_90dayplus_sum) %>% 
  replace_na(list(holdCnt = 0)) %>% 
  mutate(Cnt = plainCnt + holdCnt + out_to_bidCnt)


# Weekly Performance Report -----------------------------------------------


