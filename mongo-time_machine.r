# mongo-time_machine.r
# Created by: Mickey Guo
# To Push Data to Rubix for Archival Purposes


# Init, Library Imports ---------------------------------------------------

library(mongolite)

rubix_mongo_url <- "mongodb://10.108.198.117:27017"

ohio_mongo_url <- "mongodb://127.0.0.1:27017"

# Backlog Table -----------------------------------------------------------


# Approver Worklist Table -------------------------------------------------

mongo_approval_worklist <- mongo(collection = "timemachine-pp_worklist", db = "test", url = rubix_mongo_url)

# Adds archive time and cast Age to int since mongolite can't handle date interval objs
approval_worklist_timemachine <- approval_raw %>% 
  mutate_at("Age", as.integer) %>% 
  mutate(Archive_Time = data_date)

mongo_approval_worklist$insert(approval_worklist_timemachine)


# Backlog Table -----------------------------------------------------------

mongo_backlog_plain <- mongo(collection = "timemachine-backlog_plain", db = "test", url = rubix_mongo_url)
mongo_backlog_hold <- mongo(collection = "timemachine-backlog_hold", db = "test", url = rubix_mongo_url)
mongo_backlog_out_to_bid <- mongo(collection = "timemachine-backlog_out_to_bid", db = "test", url = rubix_mongo_url)

# Tibble -> Tibble
# Tidies "Raw" backlog req data, keeping useful info and adding archive time
backlog.tidy.timemachine.hard <- function(df) {
  df %>% 
    mutate_at("Age", as.integer) %>% 
    mutate(Archive_Time = data_date) %>%
    select(-`Last Change Date`)
}

backlog_plain_timemachine <- backlog.tidy.timemachine.hard(backlog_nohold)
backlog_hold_timemachine <- backlog.tidy.timemachine.hard(backlog_hold)
backlog_out_to_bid_timemachine<- backlog.tidy.timemachine.hard(backlog_out_to_bid)

mongo_backlog_plain$insert(backlog_plain_timemachine)
mongo_backlog_hold$insert(backlog_hold_timemachine)
mongo_backlog_out_to_bid$insert(backlog_out_to_bid_timemachine)
