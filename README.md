# EONET Map

Live natural events from NASA's [EONET](https://eonet.gsfc.nasa.gov) on an interactive world map, with a **Planetary Pulse Index** that tells you how restless Earth is this week compared to the last year.

![App showing the world map with active natural events, the Planetary Pulse index, and a timeline of events by category](docs/dashboard-view.png)

## What you get

- **World map** with every natural event (wildfires, storms, volcanoes, floods, ice, landslides, more) pinned at its location, colour-coded by category, clustered when zoomed out. Click any marker for details and a source link.
- **Planetary Pulse Index** in the sidebar: a single number where 100 is a normal week, 120 is noticeably busy, 140+ is genuinely unusual. A short verdict underneath tells you what that feels like.
- **Filters** for category, time window (1 to 365 days), and event status (open / closed / all).
- **Timeline** stacked by category so you can see which hazards are driving the activity.
- **Category breakdown** with a mini bar chart.

## Requirements

- R 4.1 or newer (needs the native `|>` pipe)
- An internet connection (to hit EONET and load Google Fonts)

## Run it

From the project root:

```r
# 1. Install deps (one time)
source("install.R")

# 2. Launch
shiny::runApp()
```

Or from your shell:

```bash
Rscript -e 'source("install.R"); shiny::runApp()'
```

Browser opens automatically at `http://127.0.0.1:XXXX`.

## Project layout