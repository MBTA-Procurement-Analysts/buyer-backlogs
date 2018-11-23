# buyer-group-definition-sample.r
# Created by: Mickey Guo
# Stores the categorizations of usernames,
#   should not be commited to version control or prod.

sourcing_execs <- tibble(Category = "SE",
                         Buyer = c("USERNAME1", "USERNAME2"))

inventory_buyers <- tibble(Category = "INV",
                           Buyer = c("USERNAME3", "USERNAME4"))

non_inventory_buyers <- tibble(Category = "NINV",
                               Buyer = c("USERNAME5", "USERNAME6"))
