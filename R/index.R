# Planetary Pulse Index (v2)
#
# Compares the last 7 days of weighted activity against a full year of history,
# expressed as a z-score and mapped to a human-readable scale.
#
# Pulse = 100 + z * 20
#   100 = last 7 days match the year's average
#   120 = 1 standard deviation above (noticeably elevated)
#   140 = 2 SD above (genuinely unusual)
#   80  = 1 SD below (quiet week)
#   60  = 2 SD below (very calm)

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

compute_pulse_index <- function(events,
                                recent_window = 7,
                                baseline_days = 365) {
  
  empty_return <- list(
    pulse       = NA_real_,
    recent_mean = 0,
    mu          = NA_real_,
    sigma       = NA_real_,
    z           = NA_real_,
    daily       = tibble::tibble(day = as.Date(character(0)), score = numeric(0))
  )
  
  if (nrow(events) == 0) return(empty_return)
  
  today <- Sys.Date()
  
  # Weight events and bucket by day (UTC to avoid timezone drift)
  scored <- events |>
    dplyr::mutate(
      weight = weight_for(category),
      day    = as.Date(date, tz = "UTC")
    ) |>
    dplyr::filter(day >= today - baseline_days, day <= today)
  
  if (nrow(scored) == 0) return(empty_return)
  
  # Build a complete daily series including zero-activity days.
  # Missing days are real signal ("nothing happened"), not missing data.
  all_days <- tibble::tibble(day = seq(today - baseline_days, today, by = "day"))
  
  daily <- scored |>
    dplyr::group_by(day) |>
    dplyr::summarise(score = sum(weight), .groups = "drop") |>
    dplyr::right_join(all_days, by = "day") |>
    dplyr::mutate(score = tidyr::replace_na(score, 0)) |>
    dplyr::arrange(day)
  
  # Recent window: last N days including today
  recent <- daily |> dplyr::filter(day >= today - recent_window + 1)
  recent_mean <- mean(recent$score)
  
  # Full-year baseline
  mu    <- mean(daily$score)
  sigma <- stats::sd(daily$score)
  
  z     <- if (is.na(sigma) || sigma == 0) NA_real_ else (recent_mean - mu) / sigma
  pulse <- if (is.na(z)) NA_real_ else round(100 + z * 20)
  
  list(
    pulse       = pulse,
    recent_mean = recent_mean,
    mu          = mu,
    sigma       = sigma,
    z           = z,
    daily       = daily
  )
}

# Verdict bands calibrated to the new scale
pulse_verdict <- function(p) {
  if (is.na(p))   return("no baseline yet")
  if (p >= 140)   return("very restless")
  if (p >= 120)   return("restless")
  if (p >= 80)    return("normal")
  if (p >= 60)    return("quiet")
  "calm"
}