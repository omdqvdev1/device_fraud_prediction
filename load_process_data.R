#This a source code to load and pre-process data for handset fraud prediction model

# Author O.Trofilov
# Ver 1.0  2-Feb-2016

library(ROracle)
library(dplyr)
library(ggplot2)
library(tidyr)
library(randomForest)
library(caret)
library(kernlab)
library(AUC)

# global variables to use in server.R and ui.R
validation_subset <- NULL
training <- NULL
testing <- NULL
nmin <- NULL


#This function is to establish connection to data warehouse
f_connect_MIS <- function(usern, passwd) {
    drv <- dbDriver("Oracle")
    connect.string <- paste(
        "(DESCRIPTION=",
        "(ADDRESS=(PROTOCOL=TCP)(HOST=xxxx)(PORT=1521))",
        "(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=YYYY)(INSTANCE_NAME=YYYYY))
    )", 
      sep=""
    )
    cn <- dbConnect(drv, username = usern, password = passwd, dbname = connect.string)
}

con <- f_connect_MIS("UUUUU","PPPPPP")
sqlstr <- "select * from SSSS.TTTTTTTT"
rs <- dbSendQuery(con, sqlstr)
tbl_ext <- fetch(rs)     
dbdisc <- dbDisconnect(con)

# preprocess data
tbl_ext <- tbl_ext[complete.cases(tbl_ext),]


tbl_ext <- tbl_ext %>% select(-CATEGORY2) %>% 
    rename(CATEGORY2=CATEGORY2_UPD) %>% 
    mutate(CATEGORY2 = factor(CATEGORY2), 
                              FUNCTION_TYPE = factor(FUNCTION_TYPE),
                              TOPUP_PREFIX_LAST = factor(TOPUP_PREFIX_LAST),
                              FUNCTION_TYPE = factor(FUNCTION_TYPE),
                              SALES_CHANNEL = factor(SALES_CHANNEL),
                              TOPUP_STATUS_LAST = factor(TOPUP_STATUS_LAST),
                              DEALER_REGION = factor(DEALER_REGION),
                              POSTPAID_TENURE_MONTHS = factor(POSTPAID_TENURE_MONTHS)  
)

names(tbl_ext) <- sub("$", ".", names(tbl_ext), fixed=TRUE)

tbl_ext1 <- subset(tbl_ext, select = -c(LINE_NO, TOPUP_DATE_LAST, ITEM_NAME, BEGIN_WORK,APP.N, APP.UP,LOGDATE, DEALER_NAME,TOPUP_PREFIX_LAST, USER_NAME, DEALER_REGION, OPERATION_CENTER,
                                        SALES_CHANNEL, DEALER_REGION, RCH_MAX_INTERVAL, RCH_TOTAL_INTERVAL, EME_TOTAL_INTERVAL))

tbl_ext1 <- tbl_ext1 %>% mutate(
    INST_MONTHLY_SUM = (SALES_AMOUNT_WITH_VAT - ADVANCE_FEE)/INST_MONTHS,
    EME_TO_RCH_RATIO_QTY = EME_QTY/RCH_QTY,
    EME_SUM = EME_QTY*EME_AVG_CREDIT,
    RCH_SUM = RCH_QTY*RCH_AVG_CREDIT,
    PTM = ifelse(PREPAY_TENURE_MONTHS == 0, 1, PREPAY_TENURE_MONTHS),
    TOPUP_AVG_MONTHLY = (EME_SUM+RCH_SUM)/PTM,
    EME_TO_RCH_SUM_RATIO = EME_SUM/RCH_SUM
    #,PAYMENT_ABILITY = TOPUP_AVG_MONTHLY * INST_MONTHS / (SALES_AMOUNT_WITH_VAT - ADVANCE_FEE) * ifelse(PTM > INST_MONTHS, 1, PTM/INST_MONTHS)
) %>% select(-PTM)

tbl_ext1 <- subset(tbl_ext1, select = -nearZeroVar(tbl_ext1[, -1]))

transformdate <- function(da) {
    strptime(as.character(da), "%Y-%m-%d")
}

# build training, testing and validation datasets
reshuffle_data <- function(fd, td) {
    tbl_subset <- tbl_ext1 %>% filter(SALE_DATE >= as.POSIXct(as.Date(fd)), SALE_DATE < as.POSIXct(as.Date(td)+1))
    set.seed(987654)
    subsetrows <- nrow(tbl_subset)
    validationrows <- sample(subsetrows, trunc(subsetrows*0.10))
    validation_subset <<- tbl_subset[validationrows, ]

    model_subset <- tbl_subset[-validationrows, ]
    modelrows <- nrow(model_subset)
    inTrain <- sample(modelrows, trunc(modelrows*0.70))
    training <<- model_subset[inTrain,] %>% select(-c(PREPAY_MSISDN, SALE_DATE))
    testing <<- model_subset[-inTrain,] %>% select(-c(PREPAY_MSISDN, SALE_DATE))
    
    training <<- na.roughfix(training)
    nmin <<- min(table(training$CATEGORY2))
}

# apply Random Forest algorithm for building prediction model
run_trainmodel <- function() {
    res <- randomForest(
            CATEGORY2 ~., 
            data=training, 
            mtry=10, 
            importance =FALSE, 
            strata=training$CATEGORY2,
            sampsize = rep(nmin, 2),
            ntree = 1500,
            replace = TRUE
        )

    res    
}    


