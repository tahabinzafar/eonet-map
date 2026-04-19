# UI helpers — category colors and icons

# Picked for contrast on a dark basemap
CATEGORY_COLORS <- c(
  "Wildfires"            = "#E24B4A",
  "Severe Storms"        = "#378ADD",
  "Volcanoes"            = "#D85A30",
  "Sea and Lake Ice"     = "#85B7EB",
  "Snow"                 = "#EAEAEA",
  "Floods"               = "#185FA5",
  "Landslides"           = "#854F0B",
  "Earthquakes"          = "#7F77DD",
  "Drought"              = "#EF9F27",
  "Dust and Haze"        = "#B4B2A9",
  "Manmade"              = "#5F5E5A",
  "Water Color"          = "#1D9E75",
  "Temperature Extremes" = "#D4537E"
)

category_color <- function(cat) {
  out <- CATEGORY_COLORS[cat]
  out[is.na(out)] <- "#888780"
  unname(out)
}

