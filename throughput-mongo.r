# throughput-mongo.r
# Created by: Mickey Guo
# Displays Buyer throughput data per calendar week

# NOTE: This file depends on the "buyer-backlogs.r" file and should not be
#         run by itself. Source the file above or run in an environment that
#         has sourced it. 

# Init, Library Imports ---------------------------------------------------

library(mongolite)
library(jsonlite)
library(tidyverse)
library(lubridate)

# Detects current system, assumes localbox or ohio if running on linux, 
#   otherwise use local box IP
db_url <- if (Sys.info()[[1]] == "Linux") {"mongodb://127.0.0.1:27017"} else {"mongodb://10.108.198.117:27017"}
environment <- "prod"
serverlocation <- Sys.getenv("RUBIXLOCATION")
#serverlocation <- "local"

# Constructs DB name
db_name <- paste("rubix", serverlocation, environment, sep = "-", collapse = "")

# Buyer Category Order to use in this report
buyer_cat_fct_throughput <- c("INV", "NINV", "SE")

# Mongodb Connection and Query --------------------------------------------

mongo_raw_po <- mongo(collection = "PO_DATA", db = db_name, url = db_url)

# Querying every PO of Status "Apprv", "Comp", and "Dispt", that is created
#   after 2018-10-15, keeping POID, Date, Buyer, and Lines field.
mongo_query <- mongo_raw_po$find('{"PO_Date": 
                                    {"$gt": 
                                      {"$date": "2018-10-15T00:00:00Z"}},
                                   "Status": 
                                    {"$in": ["A", "C", "D"]}}',
                                 fields = '{"PO_No": true, 
                                            "PO_Date": true, 
                                            "Buyer": true, 
                                            "_id": false,
                                            "lines": true}')

mongo_po_tibble <- as_tibble(mongo_query)

# Data Wrangling ----------------------------------------------------------

# date/datetime -> date/datetime
# Returns the Sunday of the given date's week, by subtracting day of week
# from the date
date.of.week <- function(dt) {
  dt - wday(dt, label = FALSE) + 1
}

# DF/Tibble -> Tibble
# Appends Buyer Category Factor, and substrings the buyer's name
# This function will ignore the buyers defined in the "IGNORE" group
buyer.category.buyer.names <- function(data) {
  data %>% 
    left_join(., buyers_cat, by = "Buyer") %>% 
    filter(!`Category` =="IGNORE") %>% 
    mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct_throughput)) %>% 
    arrange(`Category`, `Buyer`) %>% 
    select(`Buyer`, everything(), -Category) %>%
    mutate_at("Buyer", substr, start = 0, stop = 2)
}

# Changes datetimes to dates, and adds the week date
mongo_po_tibble <- mongo_po_tibble %>% 
  mutate_at("PO_Date", date) %>% 
  mutate(`WeekNo` = date.of.week(`PO_Date`)) %>% 
  mutate_at("WeekNo", ~paste(month(.), day(.), sep = "/"))

# PO Count by Buyer and by Week, ignores "IGNORE" buyers
throughput_hdr_tibble <- mongo_po_tibble %>% 
  group_by(`Buyer`, `WeekNo`) %>% 
  summarise(Cnt = n()) %>% 
  ungroup(`Buyer`, `WeekNo`) %>% 
  select(Buyer, `WeekNo`, `Cnt`) %>% 
  spread(`WeekNo`, `Cnt`) %>% 
  replace(is.na(.), 0) %>% 
  buyer.category.buyer.names()

# PO Line Count by Buyer and by Week, ignores "IGNORE" buyers
throughput_lines_tibble <- mongo_po_tibble %>% 
  mutate(`LineCnt` = map_dbl(lines, NROW)) %>% 
  group_by(`Buyer`, `WeekNo`) %>% 
  summarise(LineSum = sum(LineCnt)) %>% 
  ungroup(`Buyer`, `WeekNo`) %>% 
  select(Buyer, `WeekNo`, `LineSum`) %>% 
  spread(`WeekNo`, `LineSum`) %>% 
  replace(is.na(.), 0) %>% 
  buyer.category.buyer.names()

# Number of Rows per category, for auto-adjusting groups labels for the kable.
# Joining the category table and factorizing it is repetitive, but since 
#   categorizing and sorting and removing of the "Category" column is done
#   in a function, it is hard to achieve similar results with less code.
throughput_cat_cnt_tibble <- mongo_po_tibble %>% 
  distinct(`Buyer`) %>% 
  left_join(., buyers_cat, by = "Buyer") %>% 
  filter(!`Category` =="IGNORE") %>% 
  mutate_at("Category", ~parse_factor(., levels = buyer_cat_fct_throughput)) %>% 
  group_by(Category) %>% 
  summarize(n()) %>% 
  arrange(Category)

