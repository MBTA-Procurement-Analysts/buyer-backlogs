# data_import_manual-sample.r
# Created by: Mickey Guo
# Gather variables for data import in one place

# data path for backlog req data
backlog_data_path <- "./data/rubix/11142018-140001/BACKLOG-11142018-140001.xlsx"

# data path for approver worklist data
approver_data_path <- "./data/rubix/11142018-140001/APPROVER-BACKLOG-11142018-140001.xlsx"

# date of data download from fmis
# In data_import.r this field would contain hms data, thus the function call to
#   parse the string is ymd_hms. It should not make a diffence since the output
#   does not care about the actual type of this variable.
data_date <- ymd("2018-11-14")

code_version <- "33"