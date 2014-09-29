setwd("~/Google Drive/School/Masters/FinalPaper/src")
library(foreign)
library(data.table)

data <- data.table(read.dta("data/sample.dta"))
hhs <- unique(data$hh_id)

forecast <- function(x, prob) {
  ifelse(x == 1, prob
}

d <- subset(data,hh_id==hhs[30])
t <- 1:nrow(t) %% 52
plot(d$cpn_ch)
plot(d$cpn_td)
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

utility(5,0:10)

f <- function(x) 2.46885*x -0.22295*x^2
