setwd("~/Google Drive/School/Masters/FinalPaper/src")
library(foreign)
library(data.table)
library(ggplot2)
library(stringr)

directory <- "data/pbutter/"

load(paste(directory, "data.RData", sep=""))
data <- data.table(read.dta("data/pbutter.dta"))
fulldata <- data.table(read.dta("data/pbutterFull.dta"))

# Kernel Density: weeks to go by consumption_category 
data[, cons_cat := factor(round(cons/5), levels=0:13, labels=paste(0:13*5,1:14*5,sep="-"))]

kd_wtg_by_consumption <- ggplot(data = data, aes(x = wks_to_g, colour = cons_cat)) + 
  geom_density(xlab = "Weeks to go") +
  labs(x = "weeks of peanut butter remaining",
       title = "Consumer Inventory") +
  scale_color_discrete("Oz of P.B./Week") +
  theme_bw()

# Line plot: tot volume by brand per week
week_to_year <- function(x) {
  year <- as.double(str_sub(x,1,4))
  week <- as.double(str_sub(x,5,6))
  year + week/52
}

purchhist[, hh_id := as.integer(hh_id)]
purchhist[, week := as.integer(week)]
purchhist[, date := week_to_year(week)]
purchhist[, unit_wght := as.integer(unit_wght)/1000]
purchhist[, units_purch := as.integer(units_purch)/100]
purchhist[, tot_wght := unit_wght*units_purch]

setkey(purchhist, upc_id)
brands <- c("CTL", "JIF", "PETER", "SKIPPY")
upcdata[,brand := {
  brd <- str_extract(desc, "\\w+")
  ifelse(brd %in% brands, brd, "OTHER")
}]
ph_upc <- merge(purchhist, upcdata)
tot_vol_ph_upc <- ph_upc[,list(tot_vol=sum(tot_wght)), by=c("date", "brand")]
setkey(tot_vol_ph_upc, date, brand)

tot_ph_upc <- ph_upc[,list(sz=sum(unit_wght.x)), by=c("hh_id", "week")]
bar_tot_vol <- ggplot(data = tot_ph_upc[,list(cnt=length(hh_id)), by=sz]) +
  geom_bar(aes(x = sz,
               y = cnt), alpha=0.5,
           stat="identity",
           position="dodge") +
  labs(x = "total purchase size (Oz)",
       y = "count") +
  #xlim(c(0,81)) +
  theme_bw()
bar_tot_vol
  #  geom_bar(aes(x = factor(hh_income), 
  #               y=mean_gross_unit_price), alpha=0.5, 
  #           stat="identity",
  #           position = "dodge")

lp_tot_vol_by_brand <- qplot(x = date, y = tot_vol, 
  data = tot_vol_ph_upc, 
  facets = brand ~ ., geom = "line",
  ylab = "total vol (Oz)",
  main = "Total Peanut Butter Vol Sold by Brand") + theme_bw()
lp_tot_vol_by_brand

# Stacked Line plot: # of purchases by vol category per week
setkey(ph_upc, hh_id, week)
setkey(data, hh_id, week)
ph_upc_data <- merge(ph_upc, data)
tot_purch_ph_upc <- ph_upc_data[, list(npurch = .N), by=c("date","brand","vol")]

slp_tot_purch_by_vol_cat <- ggplot(data = tot_purch_ph_upc) +
  scale_y_log10() +
  scale_linetype_discrete("Volume (Oz)") +
  geom_line(aes(x = date, y = npurch, linetype=factor(vol))) +
  facet_grid(brand ~ .) +
  theme_bw() +
  labs(y="number of sales",
       title="Total Sales by Volume Category")
slp_tot_purch_by_vol_cat

# Prices
ph_upc_data[, extended_price := as.double(extended_price)/100]
ph_upc_data[, units_purch_store := as.integer(units_purch_store)]
ph_upc_data[, tot_coupon_val_store := as.integer(tot_coupon_val_store)]
ph_upc_data[, units_purch_manu := as.integer(units_purch_val_manu)]
ph_upc_data[, tot_coupon_val_manu := as.integer(tot_coupon_val_manu)]

ph_upc_data[, gross_unit_price := extended_price/units_purch]
ph_upc_data[, gross_unit_coupon := 
              ifelse(units_purch_store > 0, tot_coupon_val_store/units_purch_store, 0) +
              ifelse(units_purch_manu > 0, tot_coupon_val_manu/units_purch_manu, 0)]
ph_upc_data[, net_unit_price := gross_unit_price - gross_unit_coupon]
prices <- ph_upc_data[, list(npurch = .N, 
                             mean_gross_unit_price=sum(gross_unit_price)/.N,
                             mean_gross_unit_coupon=sum(gross_unit_coupon)/.N,
                             mean_net_unit_price=sum(net_unit_price)/.N),
                      by=c("date","brand","vol")]
setkey(prices, date, brand, vol)

lp_prices <- ggplot(prices, aes(x = date, linetype=factor(vol))) +
  geom_line(aes(y = mean_net_unit_price/vol)) +
  scale_linetype_discrete("Volume (Oz)") +
  facet_grid(brand ~ .) +
  theme_bw() + 
  labs(y = "mean unit gross price ($/Oz)",
       title = "Prices")
lp_prices

# Imputation difference
library(plyr)
tab_inv_comp <- 
  sapply(
    data.frame(fulldata)[, c("cons", "dpurchased", "wtg1", "wtg2")], 
    each(min, max, mean, sd, median, IQR))

# Price / Weeks to go
price_wtg <- ph_upc_data[, list(wtg=max(wks_to_g), 
                                mean_net_unit_price=sum(net_unit_price)/.N), 
                         by=c("hh_id", "date", "vol")]
sp_price_wtg <- ggplot(price_wtg, aes(x = wtg, y = mean_net_unit_price/vol)) +
  geom_point(alpha=0.025, size=3) +
  facet_grid(vol ~ .) +
  labs(x = "weeks of peanut butter remaining",
       y = "mean net unit price ($/Oz)",
       title = "Mean Price Inventory Purchase Pattern") +
  theme_bw()
  #stat_density2d(geom="tile", aes(fill = ..density.., geom="polygon"), contour=FALSE)
sp_price_wtg

# Sizes

# Mean Price / Shopping Frequency
ph_upc_data[, store_id := as.integer(store_id)]
setkey(ph_upc_data, hh_id)
setkey(shopoccasion, hh_id)
shpocc <- shopoccasion[,list(ntrips=.N, tot_spent=sum(dollars_spent > 2000)),by=c("hh_id")]

ph_upc_data_shpocc <- merge(ph_upc_data, shpocc)

mean_price_by_freq <- ph_upc_data_shpocc[,list(mean_gross_unit_price=sum(gross_unit_price)/sum(vol)),
                                         by=hh_id]
setkey(shpocc, hh_id)
setkey(mean_price_by_freq, hh_id)
mean_price_by_freq <- merge(mean_price_by_freq, shpocc)

price_by_shopocc <- ggplot(data = mean_price_by_freq) +
  geom_point(aes(x = mean_gross_unit_price, y = tot_spent)) +
  labs(x = "mean gross unit price ($/Oz)",
       y = "N trips (> $20)") +
  theme_bw()
price_by_shopocc

# Mean Price / Income
setkey(ph_upc_data, hh_id)
setkey(hh.demog, hh_id)

ph_upc_data_demog <- merge(ph_upc_data, hh.demog, all.x = TRUE)
mean_price_by_income <- ph_upc_data_demog[, list(mean_gross_unit_price=sum(gross_unit_price)/sum(vol)),
                                          by=c("hh_income")]
setkey(mean_price_by_income, hh_income)
#price_by_income <- ggplot(data = mean_price_by_income) + 
#  geom_bar(aes(x = factor(hh_income), 
#               y=mean_gross_unit_price), alpha=0.5, 
#           stat="identity",
#           position = "dodge")
#price_by_income

price_by_income <- tapply(ph_upc_data_demog$net_unit_price/ph_upc_data_demog$unit_wght.x, 
                          factor(ph_upc_data_demog$hh_income,
                                 labels = c("< $5K",
                                            "$[5,10)K",
                                            "$[10,15)K",
                                            "$[15,20)K",
                                            "$[20,25)K",
                                            "$[25,30]K",
                                            "$[30,35)K",
                                            "$[35,40)K",
                                            "$[40,45)K",
                                            "$[45,50)K",
                                            "$[50,60)K",
                                            "$[60,75)K",
                                            "$[75,100]K",
                                            "> $100K")),
                          mean)
price_by_income <- data.frame(price_by_income)
colnames(price_by_income) <- ("Mean Net Unit Price ($/Oz)")

# Mean Price by Store
mean_price_by_store <- ph_upc_data[,list(mean_gross_unit_price = mean(gross_unit_price)),
                                    by=c("store_id", "vol")]

price_by_store <- ggplot(data = mean_price_by_store) +
  geom_tile(aes(x = factor(store_id), 
                y = factor(vol),
                fill = mean_gross_unit_price/vol)) +
  scale_fill_gradient2("Unit Price Per Oz") +
  theme_bw() + 
  labs(x = "Store ID",
       y = "Vol Cat.",
       title = "Store ID by Mean Price") +
  theme(axis.text.x=element_text(angle=90))
price_by_store

save(lp_tot_vol_by_brand, 
     slp_tot_purch_by_vol_cat, 
     lp_prices, 
     sp_price_wtg,
     price_by_shopocc,
     price_by_store, 
     price_by_income,
     kd_wtg_by_consumption, 
     bar_tot_vol,
     tab_inv_comp, file =  "graphics/plot.RData")
#ggsave(filename = "price_by_store.pdf",plot = price_by_store)
load("graphics/plot.RData")