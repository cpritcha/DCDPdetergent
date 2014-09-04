library("data.table")
library("ggplot2")
setwd("~/Google Drive/School/Masters/FinalPaper/data")

lbls <- c("Cheer", "Oxidol", "Surf", "Tide", "Wisk", "Rest")

# Purchase data
purch <- read.csv(file="purch.txt", sep="\t", header=T)
purch$brand <- factor(x=purch$brand,
                   labels=lbls)
purch <- data.table(purch)
setkeyv(purch, "id")

# Household data
hhchar <- data.table(read.csv(file="hhchar.txt", sep="\t", header=T))
colnames(hhchar) <- c("id", "income", "size", "insample", "outsample")
setkeyv(hhchar, "id") 
  
# Price data
prices <- data.table(read.csv(file="prices.txt", sep="\t", header=T))
colnames(prices) <- c("sid", "week", "brand", "price", "display")
setkeyv(prices, c("sid","week","brand"))

# Weights (Bridge table)
wghts <- data.table(read.csv(file="weights.txt", sep="\t", header=T))
setkeyv(wghts, c("id","sid"))

# discretize into sale/no sale variable
# plot the price over time of different laundry detergent brands by store

purhh <- merge(purch, hhchar)
pricewght <- merge(prices[1:100,], wghts[1:100], by="sid", allow.cartesian=T)


# create prices by (brand, id, date)

# add on the price information

# discretize 
# - prices into sale / not on sale
# - display variable
# - align week variable with date variable
# - estimate initial laundry detergent stock
# - realign variables to make them Ox compatible
# - export data in Ox friendly format


# plots
# - prices by brand
# - 

# generate inventory data assuming initial inventory and constant consumption

laundry.cons <- function(purchases, start=3, bin.size=2.5) {
  n <- length(purchases)
  s <- seq(0,500,by=bin.size)
  ave.cons <- which.min(abs(s-mean(purchases)))
  
  inventory <- rep(0,n)
  inventory[1] <- start*ave.cons + purchases[1]
  #inventory[2:n] <- purchases[2:n] - ave.cons
  #inventory <- cumsum(sapply(inventory, max, 0))
  for (i in 2:n) {
    inventory[i] <- max(inventory[i-1] + purchases[i] - ave.cons,0)
  }
  inventory
}

get.dry.only <- function(inventory, run.length=3) {
  # determines if there are any long periods when a household is expected to be out of detergent
  tmp <- rle(inventory)
  any(tmp$values[tmp$lengths < run.length] <= 0.0001)
}

data <- data.table(read.csv("data.csv",header=T,sep=","))

# simple model
# - aggregate price/display across brand
# - only ~50000 rows
# - discretize vol/size into 50oz bins
# - discretize inventory into 2.5oz/person bins

discprice <- cut(data[,price], 0:6*0.01, labels=F)
data[,dprice := discprice]
data[,dvol := as.integer(as.vector(cut(vol,breaks=c(-1,0,17,33,65,129,257,401),labels=c(0,16,32,64,128,256,400))))]
data[,inventory := as.numeric(laundry.cons(dvol/size)),by=id]

# select only individuals that buy dry laundry detergent regularly throughout the year
ids <- data[,get.dry.only(inventory), by=id]
setkey(ids, V1)
ids <- ids[ids$V1,id]

train.ids <- sample(ids, size=ceiling(2*length(ids)/3))
test.ids <- setdiff(ids, train.ids)

setkey(data, id)
train.data <- data[data$id %in% train.ids,]
# note: the data does not have a time subscript, data is already ordered

write.csv(train.data, file="train.csv")

# want data to be only 