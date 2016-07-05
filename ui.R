
# This is the GUI definition for Device Fraud Prediction Shiny application.

# Author O.Trofilov
# Ver 1.0  5-Feb-2016

library(shiny)
library(shinyjs)
library(plotly)

shinyUI(
    
    navbarPage(useShinyjs(),title="Prepay Device Fraud Prediction application", id="navbar_main",

  # Sidebar with a slider input for number of bins
  tabPanel(title="Train the model",  value = "tab_train",
    sidebarLayout(
        sidebarPanel(
            helpText("Please, set the period for the training data model. Usually, more data used in the training model improve prediction accuracy."),  
            dateInput("date_from", "Start date:", value = "2015-05-01", min = "2015-05-01", max="2015-09-30"),  
            dateInput("date_end",  "End date:", value = "2015-09-30", min = "2015-08-01", max="2015-09-30"),
            #disabled(
                actionButton("btn_load_train", "Load & Train")
            #)
        ),    
        mainPanel(
            tabsetPanel(
                tabPanel("RF statistics", verbatimTextOutput("rf_statistics")),
                tabPanel("Gini importance", plotOutput("GiniPlot", height = 800)),
                tabPanel("ROC curve", plotOutput("RocPlot", height = 600)),
                tabPanel("Explore data", 
                         uiOutput("list_variables"),
                         sliderInput("sliderQuantile", "Quantile", min=0.950, max=1, value=0.995, step=0.005, round=FALSE),
                         textOutput("slidervalue"),
                         plotlyOutput("TrainDataPlot")
                )
                
            )
            )  
  )
  ),
  tabPanel(title="Predict the status", value="tab_predict",
     sidebarLayout(
         sidebarPanel(
                 uiOutput("list_msisdn_output"),  
                 helpText("Please, indicate the price, number of installment months, and initial fee"),
                 uiOutput("num_price_output"),
                 uiOutput("num_months_output"),
                 uiOutput("num_advance_output"),
                 actionButton("btn_predict", "Predict status")
             ), 
         mainPanel(
             tabsetPanel(
                 tabPanel(title = "Prediction", 
                     h3(textOutput("currentMSISDN")),
                     br(),
                     br(),
                     h4("Original prediction"),
                     tableOutput("MsisdnStat"),
                     br(),
                     br(),
                     h4("Prediction with changed parameters"),
                     tableOutput("PredictStat")
                     ),
                 tabPanel(title = "Customer info",
                          dataTableOutput("CustInfo")
                          )
                 ) 
             )
         
  )
  ), 
  tabPanel(title="Info", value="tab_info",
         sidebarLayout(
         sidebarPanel = NULL,    
         mainPanel(
             includeMarkdown("Readme.md")
         )
         )
  )
)
)

