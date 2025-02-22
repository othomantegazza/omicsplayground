##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2020 BigOmics Analytics Sagl. All rights reserved.
##

message(">>> sourcing UserBoard")

UserInputs <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
               HTML("<h3>User Settings</h3><br><br>"),
               shiny::uiOutput(ns("description"))
               ## shiny::uiOutput(ns("inputsUI"))
           )
}

UserUI <- function(id) {
    ns <- shiny::NS(id)  ## namespace
    shiny::fillCol(
               height = 750,
               shiny::tabsetPanel(
                          id = ns("tabs"),
                          shiny::tabPanel("User settings",uiOutput(ns("userinfo_UI")))
                          ## shiny::tabPanel("Visitors map",uiOutput(ns("usersmap_UI")))
                          ## shiny::tabPanel("Community forum",uiOutput(ns("forum_UI")))
                      )
           )
}

UserBoard <- function(input, output, session, env)
{
    ns <- session$ns ## NAMESPACE

    user <- env[["load"]][["auth"]]

    dbg("[UserBoard] >>> initializing UserBoard...")

    observeEvent( user$logged(), {
        if(!user$logged())
            return()

        removeModal()
        
        session$sendCustomMessage(
            "get-subs",
            list(
                ns = ns(NULL)
            )
        )
    })

    output$description <- renderUI({
        user.name  <- user$name()
        user.level <- user$level()
        user.email <- user$email()
        dbg("[UserBoard::description] names(user) = ",names(user) )
        dbg("[UserBoard::description] user.name = ",user.name )
        dbg("[UserBoard::description] user.email = ",user.email )
        dbg("[UserBoard::description] user.level = ",user.level )        

        if(is.null(user.name))  user.name  <- ""
        if(is.null(user.email)) user.email <- ""
        user <- user.email
        if(user=="" || is.na(user)) user <- user.name
        
        description = "Signed in as<h2><b>NAME</b></h2><h4>EMAIL</h4><br><h4>LEVEL</h4>"
        description = "Signed in as<h2><b>NAME</b></h2><h4>EMAIL</h4>"
        description = "Signed in as<h4>USER</h4>"        
        ##description = "Signed in as<h4><b>EMAIL<b></h4>"
        description <- sub("EMAIL", as.character(user.email), description)
        description <- sub("NAME", as.character(user.name), description)
        description <- sub("LEVEL", as.character(user.level), description)
        description <- sub("USER", as.character(user), description)        
        shiny::HTML(description)        
    })
        
    output$plan <- renderUI({
        plan_class <- "info"
        if(user$level() == "premium")
            plan_class <- "success"
        cl <- sprintf("badge badge-%s", plan_class)
        p(
            span("Subscription level", style="color:grey;"),
            span(class = cl, tools::toTitleCase(user$level()))
        )
    })

    observeEvent(input$manage, {        
        dbg("[UserBoard] !!! input$manage called")
        dbg("[UserBoard] !!! OMICS_STRIPE_KEY = ", Sys.getenv("OMICS_STRIPE_KEY"))
        dbg("[UserBoard] !!! user$email() = ", user$email())
        dbg("[UserBoard] !!! user$stripe_id() = ", user$stripe_id())        
        dbg("[UserBoard] !!! user$href = ", user$href())
        
        response <- httr::POST(
            "https://api.stripe.com/v1/billing_portal/sessions",
            body = list(
                customer = user$stripe_id(),
                return_url = user$href()
            ),
            httr::authenticate(
                Sys.getenv("OMICS_STRIPE_KEY"),
                ""
            ),
            encode = "form"
        )

        httr::warn_for_status(response)        
        content <- httr::content(response)
        session$sendCustomMessage('manage-sub', content$url)
    })
    
    output$userdata <- renderTable({
        dbg("[UserBoard::userdata]  renderDataTable")
        cl <- "badge badge-info"
        values <- c(
            Name   = user$name(),
            Email  = user$email(),
            Plan   = user$level(),
            Start  = '',
            End    = '',
            Status = 'active'
        )
        values[which(values=="")] <- "(not set)"
        data.frame(' '=names(values), '  '=values, check.names=FALSE)
    }, width='400px', striped=TRUE)
    
    output$news <- renderUI({
        news <- markdown::markdownToHTML(file="../VERSION",fragment.only=TRUE)
        HTML(news)
    })
    

    ##-----------------------------------------------------------------------------
    ## User interface
    ##-----------------------------------------------------------------------------
    output$inputsUI <- shiny::renderUI({ })
    
    output$userinfo_UI <- shiny::renderUI({

        ## dbg("[UserBoard::userinfo_UI] !!! userinfo_UI reacted !!!")
        ## dbg("[UserBoard::userinfo_UI] !!! user$stripe_id() = ", user$stripe_id() )                
        ## manage.subcriptions.ui <- tagList()
        ## if( length(user$stripe_id()) && user$stripe_id()!="" ){
        ##     manage.subcriptions.ui <- tagList(
        ##         h4("Subscriptions"),
        ##         shiny::actionButton(ns("manage"),"Manage Subscription"),
        ##         shiny::actionButton(ns("upgrade"),"Upgrade", onClick='upgrade_plan()'),
        ##         br(),
        ##         br(),
        ##         shiny::div(id = "user-subs")
        ##     )
        ## }
        
        fillRow(
            flex=c(0.8,0.2,1,0.2,1),
            tagList(
                shiny::h4("News"),            
                shiny::htmlOutput(ns("news"))
                ##shinyWidgets::prettySwitch(ns("enable_alpha"),"enable alpha features")
            ),br(),
            tagList(
                shiny::h4("Personal"),
                uiOutput(ns("plan")),                    
                shiny::tableOutput(ns("userdata"))
            ),br(),
            tagList(
                shiny::h4("Settings"),            
                shinyWidgets::prettySwitch(ns("enable_beta"),"enable beta features")
            )
        )

    })
    shiny::outputOptions(output, "userinfo_UI", suspendWhenHidden=FALSE) ## important!


    ##---------------------------------------------------------------
    ##--------------------- modules for UsersMap --------------------
    ##---------------------------------------------------------------
    
    usersmap.RENDER %<a-% shiny::reactive({
        
        df <- ACCESS.LOG$visitors        
        ## sPDF <- rworldmap::getMap()  
        ## rworldmap::mapCountryData(sPDF, nameColumnToPlot='continent')
        sPDF <- rworldmap::joinCountryData2Map(
            df,
            joinCode = "ISO2",
            nameJoinColumn = "country_code")
        
        par(mai=c(0,0.4,0.2,1),xaxs="i",yaxs="i")
        mapParams <- rworldmap::mapCountryData(
            sPDF, nameColumnToPlot="count",
            ##mapTitle = "Number of unique IPs",
            mapTitle = "", addLegend='FALSE',
            colourPalette = RColorBrewer::brewer.pal(9,"Blues"),
            numCats=9, catMethod="logFixedWidth")   
                   
        ##add a modified legend using the same initial parameters as mapCountryData
        do.call( rworldmap::addMapLegend,
                c(mapParams, labelFontSize = 0.85, legendWidth = 1.2, legendShrink = 0.5,
                  legendMar = 4, horizontal = FALSE, legendArgs = NULL, tcl = -0.5,
                  sigFigs = 4, digits = 3)
                )
        
    })
    
    usersmap_info = "<strong>Visitors map.</strong> The world map shows the number of users visiting this site by unique IP."
    
    shiny::callModule(
        plotModule,
        id = "usersmap", ## label="a", 
        plotlib = "baseplot",
        func = usersmap.RENDER,
        func2 = usersmap.RENDER, 
        info.text = usersmap_info,
        ##options = usersmap_options,
        pdf.width=12, pdf.height=7, pdf.pointsize=13,
        height = c(450,600), width = c('auto',1000), res=72,
        ##datacsv = enrich_getWordFreq,
        title = "Number of visitors by country",
        add.watermark = WATERMARK
    )

    ##usersmap_caption = "<b>(a)</b> <b>Geo locate.</b>"
    output$usersmapInfo <- shiny::renderUI({

        u <- ACCESS.LOG
        df <- u$visitors
        rownames(df) <-  df$country_name
        tot.users <- sum(df$count)
        freq <- df$count
        names(freq) <- df$country_name
        top.countries <- head(sort(freq,dec=TRUE),10)
        top.countriesTT <- paste("<li>",names(top.countries),top.countries,collapse=" ")
        
        shiny::HTML(
            "<b>Total visitors:</b>",tot.users,"<br><br>",
            "<b>Top 10 countries:</b><br><ol>",top.countriesTT,"</ol><br>",
            "<b>Period:</b><br>",u$period,"<br><br>"
        )
    })
    
    output$usersmap_UI <- shiny::renderUI({
        shiny::fillCol(
            height = 600,
            shiny::fillRow(
                flex = c(1,4.5),
                shiny::wellPanel( shiny::uiOutput(ns("usersmapInfo"))),
                plotWidget(ns("usersmap"))
            )
        )
    })
    

    ##------------------------------------------------
    ## Board return object
    ##------------------------------------------------
    res <- list(
        enable_beta = reactive({ as.logical(input$enable_beta) })
    )
    return(res)
}
