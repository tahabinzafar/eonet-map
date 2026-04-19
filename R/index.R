# Planetary Pulse Index
#
# Composite score answering: "how restless is Earth right now vs normal?"
#
# Method:
#   1. Weight each event by its category (storms hit harder than dust)
#   2. Sum weighted events per day -> daily activity score
#   3. Baseline = mean daily score over prior `baseline_days` (excluding today)
#   4. Pulse = (today's score / baseline) * 100
#
# Pulse of 100 means today matches its recent average. 150 means 50% more
# active than usual. 60 means well below baseline.

# Category weights — rough severity / human-impact proxy.
# Tweak these if you disagree (you probably will, that's the fun).
CATEGORY_WEIGHTS <- c(
  "Wildfires"            = 1.0,
  "Severe Storms"        = 1.2,
  "Volcanoes"            = 1.5,
  "Sea and Lake Ice"     = 0.3,
  "Snow"                 = 0.4,
  "Floods"               = 1.3,
  "Landslides"           = 1.2,
  "Earthquakes"          = 1.5,
  "Drought"              = 0.7,
  "Dust and Haze"        = 0.5,
  "Manmade"              = 0.4,
  "Water Color"          = 0.4,
  "Temperature Extremes" = 0.8
)

weight_for <- function(cat) {
  w <- CATEGORY_WEIGHTS[cat]
  w[is.na(w)] <- 1.0
  unname(w)
}

compute_pulse_index <- function(events, baseline_days = 30) {
  if (nrow(events) == 0) {
    return(list(
      pulse        = NA_real_,
      today_score  = 0,
      baseline     = NA_real_,
      daily        = tibble::tibble(day = as.Date(character(0)), score = numeric(0))
    ))
  }

  scored <- events |>
    dplyr::mutate(
      weight = weight_for(category),
      day    = as.Date(date)
    )

  daily <- scored |>
    dplyr::group_by(day) |>
    dplyr::summarise(score = sum(weight), .groups = "drop") |>
    dplyr::arrange(day)

  today <- Sys.Date()

  today_score <- daily$score[daily$day == today]
  if (length(today_score) == 0) today_score <- 0

  baseline_window <- daily |>
    dplyr::filter(day >= today - baseline_days, day < today)

  baseline <- if (nrow(baseline_window) == 0) NA_real_ else mean(baseline_window$score)

  pulse <- if (is.na(baseline) || baseline <= 0) NA_real_ else round((today_score / baseline) * 100)

  list(
    pulse        = pulse,
    today_score  = today_score,
    baseline     = baseline,
    daily        = daily
  )
}

# Human-readable verdict for the pulse value
pulse_verdict <- function(p) {
  if (is.na(p))       return("no baseline yet")
  if (p >= 150)       return("very restless")
  if (p >= 120)       return("restless")
  if (p >= 90)        return("normal")
  if (p >= 60)        return("quiet")
  "calm"
}
