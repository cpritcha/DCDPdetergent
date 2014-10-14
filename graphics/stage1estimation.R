# load in data
setwd("~/Google Drive/School/Masters/FinalPaper/src")
directory <- "data/pbutter/"

data <- data.table(read.dta("data/pbutter.dta"))
hhs <- unique(data$hh_id)

set.seed(100)
df <- data.frame(x = rnorm(10) > 0)
df$xprev <- c(df$x[2:10],NA)

markov <- function(x) {
  xprev <- c(NA,x[1:length(x)-1])
  
  q1 <- (x & xprev)
  q2 <- (x & !xprev)
  
  c(mean(q1, na.rm = TRUE),mean(q2, na.rm = TRUE))
}

markovPanel <- function(x,ids) {
  res <- aggregate(x,list(factor(ids)), FUN = markov)
  sapply(data.frame(res[,2][,1],res[,2][,2]), mean)  
}

q_ctl <- markovPanel(data$cpn_ctl,data$hh_id)
q_jif <- markovPanel(data$cpn_jif,data$hh_id)
q_ptr <- markovPanel(data$cpn_ptr,data$hh_id)
q_skp <- markovPanel(data$cpn_skp,data$hh_id)
q_oth <- markovPanel(data$cpn_oth,data$hh_id)
