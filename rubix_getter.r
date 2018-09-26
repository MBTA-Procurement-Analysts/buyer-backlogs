# rubix_getter.r
# Created by: Mickey Guo
# Interface with Rubix from R

library(curl)
library(jsonlite)
library(tidyverse)

get.req.tibble <- function (po_num) {
  result <- tryCatch( {po_request <- curl_fetch_memory(paste("http://10.108.198.117:3000/api/po/", po_num, sep = "", collapse = ""))
  po_json <- fromJSON(rawToChar(po_request$content))
  req_num <- trimws(po_json$lines[[1]]$Requisition[[1]])
  
  req_request <- curl_fetch_memory(paste("http://10.108.198.117:3000/api/req/", req_num, sep = "", collapse = ""))
  
  req_json <- fromJSON(rawToChar(req_request$content))
  req_approval_date <- date(parse_date_time(substr(req_json$Approved_On, 1, 10), "%Y-%m-%d"))
  
  req_description <- req_json$lines[[1]]$More_Info
  
  req_requester <- req_json$Requester
  
  req_tibble <- tibble(req_description, req_approval_date, req_requester)},
  
  error = function(cond) {
    req_tibble <- tibble(`req_description` = "", `req_approval_date` = NA, `req_requester` = "") 
  }, finally <- {
    req_tibble
  }
  )
}

pos <- approval_raw %>% select(`PO No.`) %>% as_vector()

pos <- c("7000006211", "7000005825", "oijfe", "9000006758")

View(bind_rows(map(pos, get.req.tibble)))
