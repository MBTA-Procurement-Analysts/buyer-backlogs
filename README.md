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

| Columns   | Use                                                                |
| --------- | ------------------------------------------------------------------ |
| User      | Not used                                                           |
| Status    | Not used                                                           |
| OperID    | Not used                                                           |
| Date/Time | Date/Time of the worklist entry                                    |
| Unit      | Not used                                                           |
| PO No.    | Unique Identifier, to poll rubix PO apis                           |
| Origin    | Not used                                                           |
| Merch_Amt | Dollar amount of Line item                                         |
| Line      | Line Identifier, used to remove duplicates and summarize PO amount |

For the data pipe, `data_import.r` is used to specify the path, date and code version upon runtime. For local development or debugging, `data_import_manual.r` is used. See the `Project Structure / Call Flow` section for more information. 

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

These intermediate `json` files are created for loading historical data from rubix mongodb into the current run. These files are not in this repo and they are overwritten during every run.

| File Name | Corresponding mongodb Path | Use |
| --------- | -------------------------- | --- |
| `approval_worklist_timemachine.json` | `test/timemachine_pp_worklist` | Stores historical approver data |
| `timemachine_backlog_hold.json` | `test/timemachine_backlog_hold` | Stores historical on-hold backlog REQ data |
| `timemachine_backlog_out_to_bid.json` |  `test/timemachine_out_to_bid` | Stores historical out-to-bid backlog REQ data |
| `timemachine_backlog_plain.json` | `test/timemachine_plain` | Stores historical regular backlog REQ data |


### Output File(s)

This project will export `buyer-backlogs.html` to the directory specified in `main.r`. It will also create a directory called `buyer-backlogs_files/` for all of its dependencies.

### Call Flow

If using an data pipe:

1. `data_run.sh` is called from another machine using ssh, with a parameter of date in `mmddyyyy-hhmmss`. This shell script then constructs the `data_import.r` file so the filename for the query (excel) files would match. It then calls `R` to execute `main.r`.

If importing the input files manually:

1. Modify `data_import_manual.r` to set the path for the two import files, as well as the date of the data. (Code version does not matter).
2. Modify `buyer-backlogs.rmd` to use the line `source("./data_import_manual.r")` (around Line 16).
3. Run `R -f main.r` from the command line. Change the output path of the html file in `main.r` if needed.

Then, the code does the following:

1. `main.r` imports and calls `rmarkdown` to render the `buyer-backlogs.rmd` rmarkdown file.
2. In `buyer-backlogs.rmd`, the `data_import*.r` is sourced. The path of the input files are now available as string variables.
3. Consequent code files are sourced, using the file path variables.
4. The output `buyer-backlogs.html` is exported to the path specified in `main.r`.

## Troubleshooting

### Common Errors

With the automatic data pipe, mail sent after each `cron` job can be very useful for debugging. This section lists some common errors found in the logs. Consult the data pipe manual for common errors found in other parts of the pipe.

#### Path Does not Exist

```
Quitting from lines 6-18 (buyer-backlogs.rmd)
Error: `path` does not exist: '/SOME-PATH/10242018-144501/BACKLOG-10242018-144501.xlsx'

Execution halted
```

It is highly likely that this issue is external to this project.

If the path in the error log does not have a date string (e.g., `10242018-144501`), check the upstream bash script responsible for uploading the files. If not, it is likely that the upstream program failed to download the files (DB maintenance, etc).

#### Object 'mongo_...' not Found

```
Quitting from lines 6-18 (buyer-backlogs.rmd)
Error in eval(ei, envir) : object 'mongo_approval_worklist' not found
Calls: <Anonymous> ... eval -> eval -> source -> withVisible -> eval -> eval

Execution halted
```

There is likely a conflict between the `use_time_machine` boolean and the sourcing of `time_machine-*.r`. It has been fixed as of 11/27/2018.