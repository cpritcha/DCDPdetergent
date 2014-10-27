setwd("~/Google Drive/School/Masters/FinalPaper/src")
library(foreign)
library(data.table)
library(ggplot2)

directory <- "data/pbutter/"

load(paste(directory, "data.RData", sep=""))
data <- data.table(read.dta("data/pbutter.dta"))
hhs <- unique(data$hh_id)

d <- subset(data,hh_id==hhs[30])
t <- 1:nrow(d) %% 52

plot(d$cpn_ctl)
plot(d$cpn_jif)
plot(d$cpn_ptr)
plot(d$cpn_skp)
plot(d$cpn_oth)

setkey(data, week)
plot(data[,list(volume=mean(vol)), by=week],type = "l",
     main="Laundry Detergent Purchased per Person",
     ylab="Volume (oz)",
     xlab="Time (yyyyww)")

utility <- function(consumption, wtg, stockout_cost_params=c(2,5),invholding_cost_params=c(0.1,0.2)) {
  stockout_cost <- ifelse(wtg <= 0, stockout_cost_params[1] + stockout_cost_params[2]*consumption, 0)
  invholding_cost <- invholding_cost_params[1]*wtg + invholding_cost_params[2]*wtg^2
  
  return(stockout_cost + invholding_cost)
}

# Demographics
setkey(data, hh_id)
setkey(hh.demog, hh_id)

demodata <- merge(data,hh.demog)

longest_stockout <- function(wks_to_g) {
  res <- rle(wks_to_g)
  max(res$lengths[res$values == 0])
}

# Income by Max Stockout
library(reshape2)
income_stockout <- demodata[,list(hh_income = unique(hh_income), 
                                  wks_to_g = as.integer(longest_stockout(wks_to_g))),by=hh_id]

xtabs(wks_to_g ~ hh_income, data=income_stockout)

d <- ggplot(demodata, aes(purch, wks_to_g))
d + ylim(0,10)+ stat_bin2d()
d + stat_sum(aes(size = ..n..))

dd <- demodata[,list(count=length(hh_id)),by=c("vol","wks_to_g")]
ggplot(data=dd, aes(x = vol, fill = wks_to_g)) + geom_bar()

d2 <- ggplot(data=dd, aes(vol, wks_to_g))
d2 + stat_sum(aes(group = count))


library(nnet)
x <- multinom(purch ~ wks_to_g + I(wks_to_g^2) + cons,data=data)
y <- multinom(purch ~ 1, data=data)

# pseudo R-Square
(y$deviance - x$deviance)/y$deviance


# Plots

# Kernel Density: weeks to go by consumption_category 
data[,cons_cat := factor(round(cons/5), levels=0:13, labels=paste(0:13*5,1:14*5,sep="-"))]

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

lp_tot_vol_by_brand <- qplot(x = date, y = tot_vol, 
  data = tot_vol_ph_upc, 
  facets = brand ~ ., geom = "line",
  ylab = "total vol (oz)",
  main = "Total Peanut Butter Vol Sold by Brand") + theme_bw()
lp_tot_vol_by_brand

# Stacked Line plot: # of purchases by vol category per week
setkey(ph_upc, hh_id, week)
setkey(data, hh_id, week)
ph_upc_data <- merge(ph_upc, data)
tot_purch_ph_upc <- ph_upc_data[, list(npurch = .N), by=c("date","brand","vol")]

slp_tot_purch_by_vol_cat <- ggplot(data = tot_purch_ph_upc) +
  scale_color_discrete("Volume Cat.") +
  scale_y_log10() +
  geom_line(aes(x = date, y = npurch, colour = factor(vol))) +
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

lp_prices <- ggplot(prices, aes(x = date, colour=factor(vol))) +
  geom_line(aes(y = mean_net_unit_price/vol)) +
  scale_color_discrete("Volume Cat.") +
  facet_grid(brand ~ .) +
  theme_bw() + 
  labs(y = "mean unit gross price ($/oz)",
       title = "Prices")
lp_prices

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

# Mean Price / Shopping Frequency
ph_upc_data[, store_id := as.integer(store_id)]
setkey(ph_upc_data, hh_id)
setkey(shopoccasion, hh_id)
shpocc <- shopoccasion[,list(ntrips=.N, tot_spent=sum(dollars_spent > 2000)),by=c("hh_id")]

mean_price_by_freq <- ph_upc_data_shpocc[,list(mean_gross_unit_price=sum(gross_unit_price)/sum(vol)),
                                         by=hh_id]
setkey(shpocc, hh_id)
setkey(mean_price_by_freq, hh_id)
mean_price_by_freq <- merge(mean_price_by_freq, shpocc)

price_by_shopocc <- ggplot(data = mean_price_by_freq) +
  geom_point(aes(x = mean_gross_unit_price, y = tot_spent)) +
  theme_bw()
price_by_shopocc

# Mean Price / Income
setkey(ph_upc_data, hh_id)
setkey(hh.demog, hh_id)

ph_upc_data_demog <- merge(ph_upc_data, hh.demog, all.x = TRUE)
mean_price_by_income <- ph_upc_data_demog[, list(mean_gross_unit_price=sum(gross_unit_price)/sum(vol)),
                                          by=c("hh_income")]
setkey(mean_price_by_income, hh_income)
price_by_income <- ggplot(data = mean_price_by_income) + 
  geom_bar(aes(x = factor(hh_income), 
               y=mean_gross_unit_price), alpha=0.5, 
           stat="identity",
           position = "dodge")
price_by_income

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
     kd_wtg_by_consumption, file =  "graphics/plot.RData")
#ggsave(filename = "price_by_store.pdf",plot = price_by_store)
load("graphics/plot.RData")