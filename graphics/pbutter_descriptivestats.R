setwd("~/Google Drive/School/Masters/FinalPaper/src")
library(foreign)
library(data.table)

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

demodata[,hh_income := factor(hh_income,levels = 1:14,
                              labels=c("< $5K",
                                       "$5K-$10K",
                                       "$10K-$15K",
                                       "$15K-$20K",
                                       "$20K-$25K",
                                       "$25K-$30K",
                                       "$30K-$35K",
                                       "$35K-$40K",
                                       "$40K-$45K",
                                       "$45K-$50K",
                                       "$50K-$60K",
                                       "$60K-$75K",
                                       "$75K-$100K",
                                       "$100K+"))]

longest_stockout <- function(wks_to_g) {
  res <- rle(wks_to_g)
  max(res$lengths[res$values == 0])
}

# Income by Max Stockout
library(reshape2)
income_stockout <- demodata[,list(hh_income = unique(hh_income), 
                                  wks_to_g = as.integer(longest_stockout(wks_to_g))),by=hh_id]

xtabs(wks_to_g ~ hh_income, data=income_stockout)


library(ggplot2)

d <- ggplot(demodata, aes(purch, wks_to_g))
d + ylim(0,10)+ stat_bin2d()
d + stat_sum(aes(size = ..n..))

dd <- demodata[,list(count=length(hh_id)),by=c("vol","wks_to_g")]
ggplot(data=dd, aes(x = vol, fill = wks_to_g)) + geom_bar()

d2 <- ggplot(data=dd, aes(vol, wks_to_g))
d2 + stat_sum(aes(group = count))
