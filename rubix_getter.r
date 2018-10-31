# rubix_getter.r
# Created by: Mickey Guo
# Interface with Rubix from R


# Library Init and Constant Definition ------------------------------------

library(curl)
library(jsonlite)
library(tidyverse)

# Base URL for Rubix APIs. Use local or ohio as needed.
#api_base_url = "http://10.108.198.117:3000/api/"
api_base_url = "http://rubikdata3.com/api/"


# Body --------------------------------------------------------------------

# String -> 1c Tibble
# Fetches Req Description, Approval Date, and Buyer Information and put it in a tibble

# Data Chain: 
#   PO ID -> PO[Lines][ReqID] -> REQ ID -> REQ
get.req.tibble <- function (poNum) {
  # init in case errors out
  req_tibble <- tibble(`req_description` = "", `req_approval_date` = NA, `req_buyer` = "") 
  result <- tryCatch(
    {
      po_request <- curl_fetch_memory(str_glue("{api_base_url}po/{poNum}"))
      po_json <- fromJSON(rawToChar(po_request$content))
      # It has been observed that the Order of variables in the JSON response
      #   is not stable (i.e., Req ID will be in [[1]] or [[2]], randomly).
      # The other field in the collection is the Req Line #.
      # Thus, with some rage-filled debug session, the call to get Req ID is 
      #   shaped below.
      req_num <- trimws(if_else(is.character(po_json$lines[[1]][1,]$Requisition[[1]]),
                                po_json$lines[[1]][1,]$Requisition[[1]],
                                as.character(po_json$lines[[1]][1,]$Requisition[[2]])))
      req_request <- curl_fetch_memory(str_glue("{api_base_url}req/{req_num}"))
      req_json <- fromJSON(rawToChar(req_request$content))
      req_approval_date <- date(parse_date_time(substr(req_json$Approved_On, 1, 10), "%Y-%m-%d"))
      req_description <- req_json$lines[[1]][1,]$More_Info %>% str_trunc(53)
      req_buyer <- if_else(is.nan(req_json$Buyer), "", req_json$Buyer)
      req_tibble <- tibble(req_description, req_approval_date, req_buyer)
    },
    error = function(cond) {
      print(cond)
      print(str_glue("Problem Getting PO info of {poNum}, it might not exist in Rubix DB."))
      #req_tibble <- tibble(`req_description` = "", `req_approval_date` = NA, `req_requester` = "") 
    }
  )
  # return
  print(req_tibble)
  req_tibble
}

# Vec<Chr> -> Tibble
# Wrapper for batch running get.req.table 
get.reqs.tibble <- function (poNums) {
  print(poNums)
  #print(map(poNums, get.req.tibble))
  bind_rows(map(poNums, get.req.tibble))
}
 