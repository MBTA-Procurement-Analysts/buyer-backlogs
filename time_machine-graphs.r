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

mongo_approval_worklist <- mongo(collection = "timemachine_pp_worklist", db = "test", url = db_url)

# Export to temp file
mongo_approval_worklist$export(file("approval_worklist_timemachine.json"))

# Read temp file as Dataframe
approval_worklist_timemachine_json <- stream_in(file("approval_worklist_timemachine.json"))

# Slice mongodb id off and tibble conversion, otherwise as_tibble won't work 
approval_worklist_timemachine <- as_tibble(approval_worklist_timemachine_json[2:11])

# (WIP)
approval_worklist_timemachine <- approval_worklist_timemachine %>% 
  mutate("50K+" = if_else(Sum_of_PO_Amt > 50000, "PP", "Total")) %>% 
  group_by(`50K+`, Archive_Time) %>% 
  summarize(Cnt = n()) %>% 
 # mutate_at("Archive_Time", ymd) %>% 
  group_by(Archive_Time) %>%
  mutate(Cnt = if_else(`50K+` == "Total", sum(Cnt), Cnt)) %>% 
  spread(., "50K+", Cnt) %>% 
  ungroup(Archive_Time)
  

plot_ly(data = approval_worklist_timemachine) %>% 
  add_lines(x = ~Archive_Time, y = ~PP, name = "PP's List (> $50K)") %>% 
  add_lines(x = ~Archive_Time, y = ~Total, name = "Total") %>% 
  layout(xaxis = list(title = "Date"), yaxis = list(title = "Count")) 

# Buyers Backlog Graphs ---------------------------------------------------

mongo_backlog_plain <- mongo(collection = "timemachine_backlog_plain", db = "test", url = db_url)
mongo_backlog_hold <- mongo(collection = "timemachine_backlog_hold", db = "test", url = db_url)
mongo_backlog_out_to_bid <- mongo(collection = "timemachine_backlog_out_to_bid", db = "test", url = db_url)

mongo_backlog_plain$export(file("timemachine_backlog_plain.json"))
mongo_backlog_hold$export(file("timemachine_backlog_hold.json"))
mongo_backlog_out_to_bid$export(file("timemachine_backlog_out_to_bid.json"))


backlog_plain_timemachine_json <- stream_in(file("timemachine_backlog_plain.json"))
backlog_hold_timemachine_json <- stream_in(file("timemachine_backlog_hold.json"))
backlog_out_to_bid_timemachine_json <- stream_in(file("timemachine_backlog_out_to_bid.json"))

backlog_plain_timemachine <- as_tibble(backlog_plain_timemachine_json[2:16])
backlog_hold_timemachine <- as_tibble(backlog_hold_timemachine_json[2:16])
backlog_out_to_bid_timemachine <- as_tibble(backlog_out_to_bid_timemachine_json[2:16])

backlog_plain_timemachine <- backlog_plain_timemachine %>% 
  group_by(Archive_Time, Category) %>% 
  summarize(Cnt = n()) %>% 
  ungroup(Archive_Time)

backlog_hold_timemachine <- backlog_hold_timemachine %>% 
  group_by(Archive_Time, Category) %>%
  summarize(Cnt = n()) %>% 
  ungroup(Archive_Time)
  
backlog_out_to_bid_timemachine <- backlog_out_to_bid_timemachine %>% 
  group_by(Archive_Time, Category) %>% 
  summarize(Cnt = n()) %>% 
  ungroup(Archive_Time)


# A tibble: 2 x 3
# Groups:   50K+ [?]
#`50K+` Archive_Time   Cnt
#<lgl>  <date>       <int>
#  1 FALSE  2018-10-11       1
#2 TRUE   2018-10-11      13

#`50K+` Archive_Time          Cnt
#<lgl>  <dttm>              <int>
#  1 FALSE  2018-10-11 16:47:17     1
#2 FALSE  2018-10-12 17:47:11     3
#3 FALSE  2018-10-15 19:45:15     6
#4 FALSE  2018-10-16 16:27:57     5
#5 TRUE   2018-10-11 16:47:17    13
#6 TRUE   2018-10-12 17:47:11    11
#7 TRUE   2018-10-15 19:45:15    12
#8 TRUE   2018-10-16 16:27:57    12
