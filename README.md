# Restless Earth

Live natural events from NASA's [EONET](https://eonet.gsfc.nasa.gov) rendered on an interactive world map, plus a **Planetary Pulse Index** telling you how active Earth is today versus its 30-day baseline.

## What you get

- **World map** with every open natural event (wildfires, storms, volcanoes, floods, ice, landslides, and more) pinned at its location, colour-coded by category, clustered when zoomed out. Click any marker for details and a link to the original source.
- **Planetary Pulse Index** in the sidebar: a single number from roughly 0 to 200+. 100 is a normal day. 150 means Earth is 50% more restless than average. The verdict underneath tells you what that actually feels like.
- **Filters** for category, time window (1 to 60 days), and event status (open / closed / all).
- **Timeline** stacked by category so you can see which hazards are driving the current activity.
- **Category breakdown** with a mini bar chart.

All client-side, no API key, no database, 10-minute response cache so you don't hammer the API.

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

Browser should open automatically at `http://127.0.0.1:XXXX`.

## Project layout

```
restless-earth/
├── app.R               # UI + server
├── R/
│   ├── api.R           # EONET fetcher + 10-min cache
│   ├── index.R         # Planetary Pulse calculation
│   └── ui_helpers.R    # Category colors
├── install.R           # One-shot dep install
└── README.md
```

Everything in `R/` auto-sources when Shiny starts, so you never need to manually `source()` anything.

## How the Planetary Pulse Index works

```
1. Weight each event by category     (storms = 1.2, wildfires = 1.0, dust = 0.5, etc.)
2. Sum weighted events per day        -> daily activity score
3. Baseline = mean daily score        over prior 30 days (excluding today)
4. Pulse = (today / baseline) * 100
```

Verdict bands:

| Pulse | Verdict |
|-------|---------|
| 150+  | very restless |
| 120–149 | restless |
| 90–119 | normal |
| 60–89 | quiet |
| <60  | calm |

Weights live in `R/index.R` under `CATEGORY_WEIGHTS`. Tweak them if you think volcanoes should hit harder or dust deserves less weight. The framework is the interesting bit; the weights are opinions.

## Things to try next

- Add a second index scoped to a country or region (drop a bounding box in, count weighted events, divide by population or area)
- Swap `CARTO.DarkMatter` for `Esri.WorldImagery` for satellite view
- Add an auto-refresh on a 10-minute timer using `invalidateLater`
- Hook in a second data source (USGS earthquakes, GDACS) and blend into the pulse
- Log daily pulse values to a local SQLite and plot its own trend
