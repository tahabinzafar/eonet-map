# EONET API fetcher
#
# Single source of truth for hitting NASA's EONET v3 endpoint and
# flattening its nested JSON into a clean tibble. Cached for 10 minutes
# to avoid hammering the API on every reactive tick.

EONET_BASE <- "https://eonet.gsfc.nasa.gov/api/v3"

# Null-coalesce helper
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# In-memory cache keyed by "status_days"
.eonet_cache <- new.env(parent = emptyenv())

empty_events_tbl <- function() {
  tibble::tibble(
    id           = character(0),
    title        = character(0),
    category     = character(0),
    date         = as.POSIXct(character(0), tz = "UTC"),
    closed       = logical(0),
    closed_date  = as.POSIXct(character(0), tz = "UTC"),
    lon          = numeric(0),
    lat          = numeric(0),
    source_url   = character(0),
    link         = character(0)
  )
}

# Parse a single EONET event's last geometry point into lon/lat.
# Handles both Point and Polygon types. Returns NULL if unusable.
extract_last_point <- function(geoms) {
  if (length(geoms) == 0) return(NULL)

  last_geom <- geoms[[length(geoms)]]
  coords <- last_geom$coordinates

  if (identical(last_geom$type, "Point")) {
    return(list(
      lon  = as.numeric(coords[[1]]),
      lat  = as.numeric(coords[[2]]),
      date = last_geom$date
    ))
  }

  if (identical(last_geom$type, "Polygon")) {
    # Polygon coords: list of rings, each a list of [lon, lat] pairs
    first_ring <- coords[[1]]
    lons <- vapply(first_ring, function(p) as.numeric(p[[1]]), numeric(1))
    lats <- vapply(first_ring, function(p) as.numeric(p[[2]]), numeric(1))
    return(list(
      lon  = mean(lons),
      lat  = mean(lats),
      date = last_geom$date
    ))
  }

  NULL
}

parse_eonet_datetime <- function(x) {
  if (is.null(x) || length(x) == 0) return(as.POSIXct(NA, tz = "UTC"))
  if (is.na(x) || !nzchar(x))       return(as.POSIXct(NA, tz = "UTC"))
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Main fetcher. Returns a tibble (possibly empty on failure).
fetch_eonet_events <- function(status = "all", days = 60, use_cache = TRUE) {
  cache_key <- paste0(status, "_", days)
  now <- Sys.time()

  if (use_cache && !is.null(.eonet_cache[[cache_key]])) {
    cached <- .eonet_cache[[cache_key]]
    fresh  <- as.numeric(difftime(now, cached$fetched_at, units = "mins")) < 10
    if (fresh) return(cached$data)
  }

  url <- sprintf("%s/events?status=%s&days=%d", EONET_BASE, status, days)

  raw <- tryCatch(
    jsonlite::fromJSON(url, simplifyVector = FALSE),
    error = function(e) {
      message("EONET fetch failed: ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(raw) || length(raw$events) == 0) {
    out <- empty_events_tbl()
    .eonet_cache[[cache_key]] <- list(data = out, fetched_at = now)
    return(out)
  }

  rows <- purrr::map(raw$events, function(ev) {
    cat_title <- if (length(ev$categories) > 0) ev$categories[[1]]$title else NA_character_
    src_url   <- if (length(ev$sources)    > 0) ev$sources[[1]]$url     else NA_character_

    point <- extract_last_point(ev$geometry)
    if (is.null(point)) return(NULL)

    tibble::tibble(
      id           = ev$id %||% NA_character_,
      title        = ev$title %||% "Untitled event",
      category     = cat_title,
      date         = parse_eonet_datetime(point$date),
      closed       = !is.null(ev$closed),
      closed_date  = parse_eonet_datetime(ev$closed),
      lon          = point$lon,
      lat          = point$lat,
      source_url   = src_url,
      link         = ev$link %||% NA_character_
    )
  })

  out <- dplyr::bind_rows(rows)
  if (nrow(out) == 0) out <- empty_events_tbl()

  .eonet_cache[[cache_key]] <- list(data = out, fetched_at = now)
  out
}

# Null-coalesce helper defined at top

clear_eonet_cache <- function() {
  rm(list = ls(.eonet_cache), envir = .eonet_cache)
  invisible(NULL)
}
