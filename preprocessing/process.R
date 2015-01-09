setwd("~/Google Drive/School/Masters/FinalPaper/data/drydet-2")
rm(list=ls())
library(data.table)
library(stringr)

root = "ssdrydet_"

# only works because weeks in study are not actual weeks
time.to.week <- function(time) {
  # converts time to date
  week <- (time + 24) %% 52 + 1
  year <- floor((time + 24) / 52) + 1986
  str_c(year, str_pad(week, 2, pad="0"))
}

week.to.time <- function(week) {
  year <- as.integer(str_sub(week, start = 1, end = 4)) - 1986
  n_week <- as.integer(str_sub(week, start = 5, end = 6))
  
  as.integer((year * 52) + n_week - 25)
}

#####
#  Purchase History
#####
purchhist <- read.fwf(str_c(root,"f1.dat"),
                      widths=c(2,2,6,1,1,8,13,4,1,5,7,7,3,3,5,3,5,11,4,rep(1,10)),
                      stringsAsFactors=F)
setnames(purchhist,
  c("cell_id",
    "market",
    "week",
    "day",
    "tripnum",
    "hh_id",
    "upc_id",
    "store_id",
    "store_type",
    "units_purch",
    "extended_price",
    "unit_wght",
    "coupon_code",
    "units_purch_store",
    "tot_coupon_val_store",
    "units_purch_val_manu",
    "tot_coupon_val_manu",
    "equiv_factor",
    "upc_line_from",
    "end_aisle",
    "front_aisle",
    "in_aisle",
    "other_display",
    "ad_code",
    "ad_type",
    "in_ad_coupon_code",
    "pop_code",
    "special_price_code",
    "coupon_factor"))

# make the market variable readable
purchhist <- data.table(purchhist, key=c("hh_id", "week"))
purchhist <- purchhist[complete.cases(purchhist),]
purchhist[, market := factor(market, labels=c("Sioux Falls", "Springfield"))]

purchhist[,hh_id := as.integer(as.character(hh_id))]
purchhist <- purchhist[!is.na(purchhist$hh_id),]
purchhist[,upc_id := str_sub(as.character(upc_id), 3L)]
purchhist[,display := ((end_aisle == "Y") | (front_aisle == "Y"))]
purchhist[,units_purch := round(as.integer(units_purch)/100)]
purchhist[,unit_wght := as.integer(unit_wght)/1000]
purchhist[,extended_price := extended_price/100]
setkey(purchhist, upc_id)

purchhist[, n_week := week.to.time(week)]

#####
#  UPC
#####

upcdata <- read.fwf(str_c(root,"f5.dat"),
                    widths=c(13,30,2,6,7,3,11,4))
colnames(upcdata) <-
  c("upc_id",
    "desc",
    "wght_code",
    "wght_desc",
    "unit_wght",
    "mult_pack",
    "equiv_factor",
    "upc_line_from")
upcdata <- data.table(upcdata, keys=c("upc_id"))
upcdata[, upc_id := as.character(upc_id)]


#####
#  Store
#####

store <- read.fwf(str_c(root,"f4.dat"),
                  widths=c(2,4,13,6,rep(1,8),7,2),
                  stringsAsFactors=F)
setnames(store,
         c("market",
           "store_id",
           "upc_id",
           "week",
           "end_aisle",
           "front_aisle",
           "in_aisle",
           "other_display",
           "ad_code",
           "ad_coupon",
           "pop_code",
           "price_code",
           "price",
           "price_multiple"))
store <- data.table(store, key=c("store_id", "upc_id", "week"))

store[, n_week := week.to.time(week)]

#####
# Retail Shopping Summary
#####
retail <- data.table(read.fwf(str_c(root,"f7.dat"),
                              widths=c(2,6,4,13,5,9,7,7,5,11,4,rep(1,9)),
                              stringsAsFactors=F))
setnames(retail,
         c("market",
           "week",
           "store_id",
           "upc_id",
           "units_purchased",
           "extended_price",
           "unit_wght",
           "tot_coupon_val_store",
           "tot_coupon_num_store",
           "equiv_factor",
           "upc_line_from",
           "end_aisle",
           "front_aisle",
           "in_aisle",
           "other_display",
           "ad_code",
           "ad_type",
           "in_ad_coupon_code",
           "pop_code",
           "special_price_code"))

retail[, purchased := as.integer(units_purchased)]
retail[, extended_price := as.integer(extended_price)]
retail[, unit_wght := as.integer(unit_wght)]
retail <- retail[complete.cases(retail),] # remove corrupted row
retail[, n_week := week.to.time(week)]
setkey(retail, week, upc_id, store_id)

#####
#  Shopping Occasion
#####
shopoccasion <- data.table(read.fwf(str_c(root, "f2.dat"),
                        widths=c(2,4,1,8,6,7), stringsAsFactors=F))
shopoccasion <- shopoccasion[1:(nrow(shopoccasion)-1),]
setnames(shopoccasion,
         c("market",
           "store_id",
           "store_type",
           "hh_id",
           "week",
           "dollars_spent"))
shopoccasion[, dollars_spent := as.integer(dollars_spent)]
shopoccasion[, hh_id := as.integer(hh_id)]
shopoccasion[, week := as.integer(week)]

# 1988 has 53 weeks but it's at the end at the study period
shopoccasion[, month := floor(as.integer(str_sub(as.character(week),start = 5, end = 6))/4)]
shopoccasion[, year := as.integer(str_sub(as.character(week), end = 4))-1986]
shopoccasion[, n_week := as.integer(str_sub(as.character(week),start = 5, end = 6))]
shopoccasion[, time := (52*year)+n_week-25]
shopoccasion[, time4 := floor(time/4)]

#####
#  Definitions
#####
brands <- c("TD", "CH") #, "SURF", "WISK"
breaks <- c(0,31,63,97,250,500)
vols <- c(17,42,72,160,400)

# might want to separate product types
definitions <- data.table(read.fwf(str_c(root, "f5.dat"),
                         widths=c(13,30,2,6,7,3,11,4), stringsAsFactors=F))
setnames(definitions,
         c("upc_id",
           "description",
           "wght_code",
           "wght_desc",
           "wght_amount",
           "multipack",
           "equiv_factor",
           "upc_line_from"))
definitions[, upc_id := as.character(upc_id)]
setkey(definitions,upc_id)
# aggregate decription into 5 brands
definitions[ , all_brands := sapply(str_split(description, " +", 2), function(x) x[1])]
definitions[, brand := all_brands]
definitions$brand[!(definitions$all_brands %in% brands)] <- "Other"
# aggregate weight into 6 volumes
definitions$vol <- cut(definitions$wght_amount/1000, breaks = breaks, labels = vols)

#####
#  Household Demographics
#####
hh.demog <- data.table(read.fwf(str_c(root, "f8.dat"),
                       widths=c(8,1,1,rep(2,4),rep(1,3),2,2,1,rep(2,3),rep(1,3),rep(2,3),1,1,6,rep(1,17))))
setnames(hh.demog,
         c("hh_id",
           "cable_status",
           "meter_status",
           "panelist_status",
           "n_cats",
           "n_dogs",
           "n_tvs",
           "res_type",
           "res_status",
           "res_duration",
           "hh_income",
           "hh_size",
           "m_head_status",
           "m_head_ave_work_hour",
           "m_head_occ",
           "m_head_edu",
           "m_head_hispanic",
           "m_head_race",
           "f_head_status",
           "f_head_ave_work_hour",
           "f_head_occ",
           "f_head_edu",
           "f_head_hispanic",
           "f_head_race",
           "demog_ch_rate",
           "washing_machine",
           "clothes_dryer",
           "dishwasher",
           "freezer",
           "toaster",
           "toaster_oven",
           "blender",
           "food_processor",
           "microwave",
           "convection_oven",
           "coffee_maker",
           "trash_compact",
           "grabage_disposal",
           "hair_dryer",
           "curl_iron",
           "hair_rollers",
           "vacuum_cleaner"))
setkey(hh.demog, hh_id)

#####
#  Export the results
#####
save(purchhist, upcdata, shopoccasion, definitions, retail, hh.demog, file="data.RData")

# must run "createdb marketing" in the terminal first

library("RPostgreSQL")
conn <- dbConnect(PostgreSQL(), host="localhost",
                 user="postgres", dbname="marketing")
clean <- function(str) str_replace(str, "\\.", "_")
for (dt in c("purchhist", "upcdata", "shopoccasion", "definitions", "retail", "hh.demog")) {
  dbWriteTable(conn, name=clean(dt), value=get(dt), overwrite=TRUE) 
}

# add indexes
#indexes <- paste(readLines("indexes.sql"), collapse="\n")
#dbSendQuery(conn, indexes)

# need to run pbutter_processing.sql, pbutter_functions.sql first
# retrieve data from db
res <- dbGetQuery(conn, 
                  "SELECT hh_id, week, vol, purchased, inv_lag AS wks_to_g, consumption, coupon_available_ch, coupon_available_other, coupon_available_td, dinventory
                   FROM done WHERE hh_id IN (SELECT DISTINCT hh_id FROM purchhist ORDER BY hh_id LIMIT 100) AND week < 198652 ORDER BY hh_id, week;")
res <- dbGetQuery(conn, 
                  "SELECT hh_id, week, vol, purchased, inv_lag AS wks_to_g, consumption, coupon_available_ch, coupon_available_other, coupon_available_td, dinventory
                   FROM done WHERE hh_id IN (SELECT DISTINCT hh_id FROM purchhist ORDER BY hh_id LIMIT 100) ORDER BY hh_id, week;")
colnames(res) <- c("hh_id", "week", "vol", "purch", "wks_to_g", "cons", "cpn_ch", "cpn_oth", "cpn_td", "inv")
write.dta(dataframe = res, file = "sample.dta", version = 11)
