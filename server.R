
# This is the server logic for Device Fraud Prediction Shiny Application.
# Author O.Trofilov
# Ver 1.0  5-Feb-2016


library(shiny)
library(shinyjs)
library(plotly)

# hide some controls (upon initialization)
hideControls <- function() {
    shinyjs::hide("rf_statistics")
    shinyjs::hide("GiniPlot")
    shinyjs::hide("RocPlot")
    shinyjs::hide("TrainDataPlot")
}

# show some controls (when data is available)
showControls <- function() {
    shinyjs::show("rf_statistics")
    shinyjs::show("GiniPlot")
    shinyjs::show("RocPlot")
    shinyjs::show("TrainDataPlot")
}


# draw Gini importance plot
getGiniPlot <- function(modfit) {
  q <- varImpPlot(modfit, type=2, scale=FALSE, color="darkgrey", bg="red", main="Gini importance for Random Forest algorithm")    
}

# draw ROC plot
getRocPlot <- function(modfit) {
    #This curve illustrates the performance of our randomForest binary classifier as a function of fall-out rate.
    
    t <- roc(modfit$votes[,1], factor(1 * (modfit$y=="BAD")))
    
    q <- ggplot(data=data.frame(x=t$fpr, y=t$tpr), aes(x, y, xmin=0, ymin=0))
    q <- q + geom_point(colour = "blue")    
    q <- q + xlab("False Positive rate (1-Specificity)")
    q <- q + ylab("True positive rate (sensitivity)") 
    q <- q + ggtitle("ROC curve")
    q <- q + geom_abline(slope=1, linetype=2, colour="darkgrey")
    q <- q + annotate(geom="text", label = paste0("AUC: ", format(auc(t)*100, digits=3), "%"), x = 0.7, y = 0.2, size = 8, colour = "lightblue")
    q
}

# calculate confusion matrix for the prediction
getRFStatistics <- function(modfit) {
    pred_rf <- predict(modfit, testing)
    cm <- confusionMatrix(pred_rf, testing$CATEGORY2)
    cm
}

# server logics    
shinyServer(function(input, output) {
    new_data <- data.frame()
    # container for reactive values
    values <- reactiveValues()
    # load data into application
    withProgress({
        setProgress(value=0.4)    
        hideControls()
        source("load_process_data.R")
        setProgress(value = 1)
        }, value = 0, message = "Loading data..."
    )
    # initalize some input variables
  output$list_msisdn_output <- renderUI({
      input$btn_load_train
      selectInput("list_msisdn", "Enter customer's MSISDN:", choices = (validation_subset$PREPAY_MSISDN))
      })
  
  # reaction on pressing of Train Model button 
  observeEvent(input$btn_load_train,  {
          withProgress({
              setProgress(value=0.1)
              reshuffle_data(input$date_from, input$date_end)
              output$list_variables <- renderUI({
                  selectInput(inputId="list_variables", label="Select variable", 
                              choices = setdiff(names(training), 
                                                c("CATEGORY2", "SALE_DATE", "SALES_AMOUNT_WITH_VAT", "PERCENT_ADVANCE_FEE", 
                                                  "INST_MONTHS", "ADVANCE_FEE", "INST_MONTHLY_SUM","TOPUP_STATUS_LAST")))
                  #names(training)[which(sapply(1:ncol(training), FUN=function(i) is.factor(training[,i])))]
              })
              setProgress(value=0.5)
              values$modfit_rf <- run_trainmodel() # train model
              setProgress(value=1)
              showControls()
          }, value = 0, message="Model training in process...")
  })
  
  # output RF statistics
  output$rf_statistics <- renderPrint({
      input$btn_load_train
      getRFStatistics(values$modfit_rf)  
  })
  
  # output Gini plot
  output$GiniPlot <- renderPlot({
      input$btn_load_train
      getGiniPlot(values$modfit_rf)
   })
  
  # output ROC plot
  output$RocPlot <- renderPlot({
      input$btn_load_train
      getRocPlot(values$modfit_rf)
   })
  
  # reaction on selection of MSISND from drop-down list
  observeEvent(input$list_msisdn, {
      validate(
         need(input$list_msisdn, "No trained model")
      )     
      newdata <- filter(validation_subset, PREPAY_MSISDN == as.character(input$list_msisdn))
      
      output$num_price_output <- renderUI({
          numericInput("num_price", "Device price:", value = newdata$SALES_AMOUNT_WITH_VAT, min=100, max=30000)
      })
      output$num_months_output <- renderUI({
          numericInput("num_months", "Installment months:", newdata$INST_MONTHS, min=2, max=48)
      })
      
      output$num_advance_output <- renderUI({
          numericInput("num_advance", "Initial fee:", newdata$ADVANCE_FEE, min=0, max=ifelse(is.null(input$num_price), 0, input$num_price))
      })
      
      shinyjs::hide("PredictStat")
      pred_rf <- predict(values$modfit_rf, newdata)
      
      values$ds1 <- data.frame(
          MSISDN=as.character(input$list_msisdn), 
          DEVICE_PRICE=newdata$SALES_AMOUNT_WITH_VAT,
          INSTALLMENT_MONTHS = newdata$INST_MONTHS, 
          ADVANCE_FEE=newdata$ADVANCE_FEE, 
          PREDICTED_STATUS = as.character(pred_rf), 
          ACTUAL_STATUS=as.character(newdata$CATEGORY2)
          #,PAYMENT_ABILITY = newdata$PAYMENT_ABILITY
      )
      tt <- newdata %>% select(-c(CATEGORY2, SALE_DATE, SALES_AMOUNT_WITH_VAT, PERCENT_ADVANCE_FEE, INST_MONTHS, ADVANCE_FEE, INST_MONTHLY_SUM))
      tt <- t(tt)
      values$ds2 <- as.data.frame(cbind(Indicator = rownames(tt), Value = tt[,1]))
  })
  
  
  output$MsisdnStat <- renderTable({ 
      values$ds1
  })
  
  output$CustInfo <- renderDataTable(
      values$ds2,
      options = list(
          pageLength = 5
      )
  )
      
  output$currentMSISDN <- renderText({
      paste0("MSISDN: ", as.character(input$list_msisdn)) 
  })
  
  # reaction on Prediction button => make prediction and 
  observeEvent(input$btn_predict, {
      newdata1 <- validation_subset %>% 
          filter(PREPAY_MSISDN == as.character(input$list_msisdn)) %>%
          mutate(
              SALES_AMOUNT_WITH_VAT=as.numeric(input$num_price),
              INST_MONTHS = as.numeric(input$num_months),
              ADVANCE_FEE = as.numeric(input$num_advance),
              PTM = ifelse(PREPAY_TENURE_MONTHS == 0, 1, PREPAY_TENURE_MONTHS),
              INST_MONTHLY_SUM = (SALES_AMOUNT_WITH_VAT - ADVANCE_FEE)/INST_MONTHS
              #,PAYMENT_ABILITY = TOPUP_AVG_MONTHLY * INST_MONTHS / (SALES_AMOUNT_WITH_VAT - ADVANCE_FEE) * ifelse(PTM > INST_MONTHS, 1, PTM/INST_MONTHS)
          ) %>%
          select(-c(PREPAY_MSISDN, SALE_DATE, PTM))
      
      shinyjs::show("PredictStat")
      pred_rf1 <- predict(values$modfit_rf, newdata1) # prediction
      values$df <- data.frame(
          MSISDN=as.character(input$list_msisdn), 
          DEVICE_PRICE=as.numeric(input$num_price),
          INSTALLMENT_MONTHS = as.numeric(input$num_months), 
          ADVANCE_FEE=as.numeric(input$num_advance), 
          PREDICTED_STATUS = as.character(pred_rf1)
          #,PAYMENT_ABILITY = newdata1$PAYMENT_ABILITY
      )
  })
  
  # rednder data frame with prediction result                    
  output$PredictStat <- renderTable({
     values$df
  })      
  
  # exploratory plots for trainig data set variables
  output$TrainDataPlot <- renderPlotly({
      validate(
          need(input$list_variables, "Needs list of variables")
      )
      get_plotX <- function(vv, pp=0.995) {
          nd <- subset(training, training[,vv] <= quantile(training[,vv], probs=pp)) 
          p <- ggplot(nd, aes_string(x=vv, colour="CATEGORY2")) + geom_density() 
          p         
      }
      ggplotly(get_plotX(as.character(input$list_variables), input$sliderQuantile))
  })

})
