# Buyers Backlog Visualization

Version `6x`, as of November 21, 2018

## Purpose

To visualize the backlog data for each buyer, in terms of age (amount of days passed since approval) and amount. This project also includes backlog info of the approver, as well as historical trend of mentioned metrics. 

This project is designed to be a component of the data pipe, and is triggered every Monday to Friday 6am and 2pm. See documentation of the data pipe for more information. 

The product of this project, `buyer-backlogs.html` resides with Project Chromebook, as it is being accessed by end-users through the internet. 

## Install/Init

### Package Requirements

#### Software Packages

  * `R`
  * `pandoc` for `rmarkdown` to `html` conversion
  * `mongodb` for accessing historical PO and REQ data

#### R Packages

  * `rmarkdown` for generating the report in `html` format 
  * `lubridate` for date handling
  * `tidyverse` for data tidying
  * `kableExtra` for generating tables
  * `readxl` for importing data from excel
  * `knitr` **not used, TODO: Remove from code**
  * `plotly` for generating graphs
  * `scales` for handling currency format
  * `RColorBrewer` for generating colors for graphs. _Not used as of 11/21/2018_
  * `mongolite` for accessing (rubix) mongodb
  * `jsonlite` for importing data from mongo
  * `curl` for accessing rubix APIs

### Data Requirements

This project takes 2 excel files:

#### `BACKLOG-mmddyyyy-hhmmss.xlsx`

This excel should contain the following columns:

| Columns                      | Use                                       |
| ---------------------------- | ----------------------------------------- |
| Business Unit                | Not used                                  |
| Requisition ID               | Unique Identifier, to poll rubix REQ apis |
| Hold From Further Processing | Marks "Hold" Status [^1]                  |
| Requisition Date             | Not used                                  |
| Origin                       | Not used                                  |
| Requester                    | Not used                                  |
| Date of Approval             | Date identifier                           |
| Buyer                        | Buyer identifier                          |
| Last Change Date             | Not used                                  |
| Buyer Assignment             | Not used                                  |
| Hold Req Process             | Not used                                  |
| Out-to-Bid                   | Marks "Out-to-bid" status [^1]            |
| Req Total                    | Dollar amount of the Req                  |

[^1]: In theory, these two fields should be mutually exclusive (an `Out-to-bid` Req should not be on `Hold`, and vice versa). But there are cases where the `Hold` status is not removed before the Req is marked `Out-to-bid`. Thus the code considers the Req to be `Out-to-bid` only even if both fields are `True`.

#### `APPROVER-BACKLOG-mmddyyyy-hhmmss.xlsx`

This excel should contain the following fields:

| Columns   | Use                                                     |
| --------- | ------------------------------------------------------- |
| User      | Not used                                                |
| Status    | Not used                                                |
| OperID    | Not used                                                |
| Date/Time | Date/Time of the worklist entry                         |
| Unit      | Not used                                                |
| PO No.    | Unique Identifier, to poll rubix PO apis                |
| Origin    | Not used                                                |
| Merch_Amt | Dollar amount of Line item                              |
| Line      | Line Identifier, used to dedupe and summarize PO amount |

For the data pipe, `data_import.r` is used to specify the path, date and code version upon runtime. For local development or debugging, `data_import_manual.r` is used. See the `Project Structure / Call Flow` sction for more information. 

## Project Structure / Call Flow

Some required files are not included in this repository since they contains either potentially confidential information, or they are changed frequently by an automated data pipe or for debugging purposes. A sample of these files are stored in `./samples`.

The roles of the files are as follows:

### Code Files

| File Name | In Repo | Use |
| --------- | ------- | --- |
| `approver-backlogs.r` | Yes | Generates Approver backlog related variables. |
| `buyer-backlogs-90dayplus.r` | Yes | Generates data for Reqs of 90+ days old. |
| `buyer-backlogs-amounts.r` | Yes | Generates data for sorting Reqs by $ amt. |
| `buyer-backlogs-r` | Yes | Loads most dependencies, generates data for sorting Reqs by age. |
| `buyer-backlogs.rmd` | Yes | RMarkdown file for rendering, includes graphs and tables definitions. |
| `buyer-group-definition.r` | No | Defines buyer groups (INV, NINV, etc). Contains buyer names. |
| `data_import_manual.r` | No | Defines input file path, sets input date, and code version. Modify this file for dev/debug. |
| `data_import.r` | No | Defines input file path, sets input date, and code version. Edited by `data_run.sh` every time upon auto refresh. |
| `data_run.sh` | Yes | Triggered by data pipe upon auto refresh. Writes updated input file path, input file date, and code version to `data_import.r`. This file then runs `main.r` to generate the `html` output. Takes `mmddyyyy-hhmmss` as first and only parameter. |
| `main.r` | Yes | Called by `data_run.sh`, generates the `html` output using `buyer-backlogs.rmd`. |
| `README.md` | Yes | This file |
| `rubix_getter.r` | Yes | Functions for accessing rubix REQ and PO apis|
| `time_machine-graphs.r` | Yes | Reads rubix mongodb and generate data for historical trend data for Approver Backlogs and Reqs (`Plain`, `On Hold`, `Out-to-bid` for all and 90 day+ reqs) |
| `time_machine-mongo.r` | Yes | Writes to rubix mongodb with current data for Approver Backlogs and Reqs (`Plain`, `On Hold`, `Out-to-bid` for all and 90 day+ reqs) | 

### Intermediate Files

### Output File(s)

## Troubleshoot

## Next Steps
