# Restless Earth
# Live natural events from NASA EONET, with a Planetary Pulse Index.
#
# Files in R/ are auto-sourced by Shiny at startup.

library(shiny)
library(bslib)
library(leaflet)
library(dplyr)
library(tidyr)
library(purrr)
library(tibble)
library(lubridate)
library(ggplot2)
library(scales)
library(jsonlite)
library(htmltools)


# ---- Theme ------------------------------------------------------------------

theme_restless <- bs_theme(
  version    = 5,
  bg         = "#0F1419",
  fg         = "#E8EAED",
  primary    = "#D85A30",
  secondary  = "#378ADD",
  base_font  = font_google("Inter"),
  heading_font = font_google("Inter"),
  "card-bg"          = "#161B22",
  "card-border-color" = "#262D35",
  "border-color"     = "#262D35"
)


# ---- UI ---------------------------------------------------------------------

ui <- page_sidebar(
  theme = theme_restless,
  window_title = "Restless Earth",

  title = tags$div(
    style = "display: flex; align-items: baseline; gap: 14px; padding: 4px 0;",
    tags$span("RESTLESS EARTH",
              style = "letter-spacing: 3px; font-weight: 600; font-size: 18px;"),
    tags$span("live natural events from NASA EONET",
              style = "font-size: 12px; opacity: 0.55; letter-spacing: 0.5px;")
  ),

  sidebar = sidebar(
    width = 310,
    bg = "#0F1419",

    # Pulse card
    div(
      style = "background: #161B22; border: 1px solid #262D35; border-radius: 10px; padding: 18px 16px; margin-bottom: 18px;",
      div(style = "font-size: 10px; letter-spacing: 2px; opacity: 0.55; text-transform: uppercase;",
          "Planetary Pulse"),
      div(
        style = "text-align: center; padding: 8px 0 4px;",
        textOutput("pulse_value", inline = TRUE) |>
          tagAppendAttributes(style = "font-size: 56px; font-weight: 700; line-height: 1; display: block; color: #E8EAED;"),
        textOutput("pulse_verdict", inline = TRUE) |>
          tagAppendAttributes(style = "font-size: 12px; opacity: 0.7; text-transform: uppercase; letter-spacing: 1.5px; margin-top: 6px; display: block;")
      ),
      div(style = "font-size: 10px; opacity: 0.4; text-align: center; margin-top: 4px;",
          "vs. 30-day baseline (100 = average)")
    ),

    sliderInput("days", "Days to show",
                min = 1, max = 60, value = 30, step = 1),

    selectInput("status", "Event status",
                choices = c("Open"   = "open",
                            "Closed" = "closed",
                            "All"    = "all"),
                selected = "open"),

    uiOutput("category_filter_ui"),

    actionButton("refresh", "↻  Refresh from NASA",
                 class = "btn-sm",
                 style = "margin-top: 10px; background: transparent; border: 1px solid #262D35; color: #E8EAED; width: 100%;"),

    div(style = "font-size: 10px; opacity: 0.45; margin-top: 10px; text-align: center;",
        textOutput("last_fetched")),

    div(style = "font-size: 10px; opacity: 0.4; margin-top: auto; padding-top: 16px; border-top: 1px solid #262D35; text-align: center;",
        HTML("Data: <a href='https://eonet.gsfc.nasa.gov' target='_blank' style='color: #D85A30;'>NASA EONET v3</a>"))
  ),

  # Main body
  div(
    style = "display: grid; grid-template-rows: auto auto; gap: 14px;",

    # Map card
    div(
      style = "background: #161B22; border: 1px solid #262D35; border-radius: 10px; overflow: hidden;",
      div(style = "padding: 10px 14px; font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; opacity: 0.55; border-bottom: 1px solid #262D35;",
          "World map"),
      leafletOutput("map", height = 520)
    ),

    # Timeline + summary row
    div(
      style = "display: grid; grid-template-columns: 2fr 1fr; gap: 14px;",

      # Timeline card
      div(
        style = "background: #161B22; border: 1px solid #262D35; border-radius: 10px; padding: 10px 14px 14px;",
        div(style = "font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; opacity: 0.55; margin-bottom: 6px;",
            "Events over time"),
        plotOutput("timeline", height = 240)
      ),

      # Summary card
      div(
        style = "background: #161B22; border: 1px solid #262D35; border-radius: 10px; padding: 10px 14px 14px;",
        div(style = "font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; opacity: 0.55; margin-bottom: 6px;",
            "By category"),
        uiOutput("cat_summary")
      )
    )
  )
)


# ---- Server -----------------------------------------------------------------

server <- function(input, output, session) {

  events_raw      <- reactiveVal(empty_events_tbl())
  last_fetch_time <- reactiveVal(NULL)

  do_fetch <- function() {
    withProgress(message = "Fetching from NASA EONET...", value = 0.3, {
      data <- fetch_eonet_events(status = "all", days = 60)
      events_raw(data)
      last_fetch_time(Sys.time())
      incProgress(1)
    })
  }

  # Initial fetch at session start
  do_fetch()

  # Manual refresh — clears cache first
  observeEvent(input$refresh, {
    clear_eonet_cache()
    do_fetch()
  })

  # Category filter built from data
  output$category_filter_ui <- renderUI({
    df <- events_raw()
    cats <- if (nrow(df) == 0) character(0) else sort(unique(df$category))
    checkboxGroupInput("categories", "Categories",
                       choices = cats,
                       selected = cats)
  })

  events_filtered <- reactive({
    df <- events_raw()
    if (nrow(df) == 0) return(df)

    cutoff <- Sys.Date() - input$days
    df <- df |> filter(as.Date(date) >= cutoff)

    df <- switch(input$status,
                 "open"   = df |> filter(!closed),
                 "closed" = df |> filter(closed),
                 df)

    # Categories: NULL during the brief initial render, then populated.
    # NULL means pre-init (show everything); empty vector means user unchecked all.
    if (!is.null(input$categories)) {
      df <- df |> filter(category %in% input$categories)
    }

    df
  })

  pulse <- reactive({
    compute_pulse_index(events_filtered(), baseline_days = 30)
  })

  output$pulse_value <- renderText({
    p <- pulse()$pulse
    if (is.na(p)) "—" else as.character(p)
  })

  output$pulse_verdict <- renderText({
    pulse_verdict(pulse()$pulse)
  })

  output$last_fetched <- renderText({
    t <- last_fetch_time()
    if (is.null(t)) "" else paste("Updated:", format(t, "%H:%M:%S %Z"))
  })

  # ---- Map ----
  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(worldCopyJump = TRUE, minZoom = 2)) |>
      addProviderTiles("CartoDB.DarkMatter") |>
      setView(lng = 10, lat = 25, zoom = 2)
  })

  observe({
    df <- events_filtered()
    proxy <- leafletProxy("map") |>
      clearMarkers() |>
      clearMarkerClusters() |>
      clearControls()

    if (nrow(df) == 0) return()

    df <- df |>
      mutate(
        color = category_color(category),
        popup = sprintf(
          "<div style='font-family: Inter, sans-serif; min-width: 220px; color: #1a1a1a;'>
             <div style='color: %s; font-weight: 600; font-size: 10px; text-transform: uppercase; letter-spacing: 1.5px;'>%s</div>
             <div style='font-size: 14px; font-weight: 600; margin: 4px 0 6px;'>%s</div>
             <div style='font-size: 11px; opacity: 0.7;'>%s</div>
             <div style='font-size: 11px; opacity: 0.7;'>%s</div>
             <div style='margin-top: 8px;'>%s</div>
           </div>",
          color,
          htmlEscape(category),
          htmlEscape(title),
          format(date, "%d %b %Y %H:%M UTC"),
          ifelse(closed, paste("Closed:", format(closed_date, "%d %b %Y")), "Still active"),
          ifelse(!is.na(source_url),
                 sprintf("<a href='%s' target='_blank' style='font-size: 11px; color: #D85A30;'>Source →</a>", source_url),
                 "")
        )
      )

    proxy |>
      addCircleMarkers(
        data         = df,
        lng          = ~lon, lat = ~lat,
        radius       = 6,
        color        = ~color,
        fillColor    = ~color,
        fillOpacity  = 0.8,
        stroke       = TRUE, weight = 1, opacity = 0.95,
        popup        = ~popup,
        label        = ~title,
        clusterOptions = markerClusterOptions(maxClusterRadius = 35)
      ) |>
      addLegend(
        position = "bottomright",
        colors   = unname(CATEGORY_COLORS[sort(unique(df$category))]),
        labels   = sort(unique(df$category)),
        opacity  = 0.9,
        title    = NULL
      )
  })

  # ---- Timeline ----
  output$timeline <- renderPlot({
    df <- events_filtered()
    bg <- "#161B22"

    blank_plot <- ggplot() +
      annotate("text", x = 0, y = 0, label = "No events in this window",
               color = "#666", size = 4, family = "sans") +
      theme_void() +
      theme(plot.background = element_rect(fill = bg, color = NA),
            panel.background = element_rect(fill = bg, color = NA))

    if (nrow(df) == 0) return(blank_plot)

    daily <- df |>
      mutate(day = as.Date(date)) |>
      count(day, category)

    present_cats <- intersect(names(CATEGORY_COLORS), unique(daily$category))
    cols <- CATEGORY_COLORS[present_cats]

    ggplot(daily, aes(x = day, y = n, fill = category)) +
      geom_col(position = "stack", width = 0.9) +
      scale_fill_manual(values = cols, breaks = present_cats) +
      scale_x_date(date_labels = "%d %b",
                   expand = expansion(mult = c(0.01, 0.01))) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
      labs(x = NULL, y = "Events", fill = NULL) +
      theme_minimal(base_family = "sans") +
      theme(
        plot.background  = element_rect(fill = bg, color = NA),
        panel.background = element_rect(fill = bg, color = NA),
        panel.grid.major = element_line(color = "#262D35", size = 0.3),
        panel.grid.minor = element_blank(),
        axis.text        = element_text(color = "#9CA3AF", size = 10),
        axis.title       = element_text(color = "#9CA3AF", size = 10),
        legend.text      = element_text(color = "#E8EAED", size = 9),
        legend.position  = "bottom",
        legend.key.size  = unit(8, "pt"),
        legend.margin    = margin(t = 4)
      ) +
      guides(fill = guide_legend(nrow = 2, byrow = TRUE))
  })

  # ---- Category summary ----
  output$cat_summary <- renderUI({
    df <- events_filtered()
    if (nrow(df) == 0) {
      return(div(style = "opacity: 0.5; font-size: 13px; padding: 20px 0;",
                 "No events in this window"))
    }

    counts <- df |>
      count(category, sort = TRUE, name = "n") |>
      mutate(pct = n / sum(n))

    max_n <- max(counts$n)

    rows <- lapply(seq_len(nrow(counts)), function(i) {
      cat <- counts$category[i]
      n   <- counts$n[i]
      col <- category_color(cat)
      bar_w <- round(100 * n / max_n)

      div(
        style = "margin-bottom: 10px;",
        div(style = "display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 3px;",
            tags$span(cat, style = sprintf("color: %s; font-weight: 500;", col)),
            tags$span(as.character(n), style = "opacity: 0.7;")),
        div(style = "height: 4px; background: #262D35; border-radius: 2px; overflow: hidden;",
            div(style = sprintf("height: 100%%; width: %d%%; background: %s;", bar_w, col)))
      )
    })

    div(style = "padding-top: 4px;", rows)
  })
}


# ---- Run --------------------------------------------------------------------

shinyApp(ui, server)
