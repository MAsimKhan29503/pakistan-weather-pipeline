# Pakistan Weather Data Pipeline

An end-to-end, unattended data pipeline that pulls live weather data for ten Pakistani cities, lands it in cloud storage, transforms it through a medallion architecture, models it as a star schema, and surfaces it in a Power BI dashboard.

Built as a hands-on data engineering internship project on **Azure** and **Databricks**.

---

## Architecture

```
Open-Meteo API (10 cities)
        │
        ▼
Azure Data Factory  ──  orchestration & ingestion
        │  (HTTP connector, ForEach loop, shared run timestamp)
        ▼
Raw layer (ADLS Gen2)  ──  JSON per city, archived to raw/Done/ after processing
        │
        ▼
Databricks Notebook 1  ──  raw → processed
        │  (flatten nested JSON, PKT timestamps, loading_time, dedupe)
        ▼
Processed / Curated layer (Delta)  ──  weather_curated
        │
        ▼
Databricks Notebook 2  ──  processed → gold (star schema)
        │  (stable dimension keys, incremental fact loading)
        ▼
Gold layer (Delta, Unity Catalog)
    ├── weather_dims_city   (city, city_id — stable keys)
    ├── weather_fact_weather (measurements, referencing city_id)
    └── derived reporting tables (summary, rainy cities, temp range)
        │
        ▼
Power BI Dashboard
```

The pipeline runs **unattended every 4 hours** via an ADF schedule trigger.

## Tech stack

- **Azure Data Factory** — orchestration, scheduled ingestion
- **Azure Data Lake Storage Gen2** — raw / processed / gold containers
- **Azure Databricks** — PySpark transformation, Delta Lake, Unity Catalog
- **Delta Lake** — ACID transactions, schema enforcement, SQL-queryable tables
- **Power BI** — dashboard and visualization
- **Open-Meteo API** — free, public weather data source

## Design decisions

**Medallion architecture (raw → processed → gold)**
Each layer lives in its own storage container and its own notebook, so responsibilities stay separated: raw is untouched JSON, processed is clean and typed, gold is business-ready and modeled for analysis.

**Star schema in the gold layer**
`weather_dims_city` and `weather_fact_weather` follow a standard dimensional model. City attributes are stored once with a stable `city_id`; every reading in the fact table references that key instead of repeating city name and coordinates on every row. Dimension keys never change once assigned — a new city gets the next free ID, existing cities are untouched.

**Incremental (not full-reload) fact table loading**
Every run computes the full current state of `weather_curated` and left-anti-joins it against what's already in `weather_fact_weather` (matched on `city_id` + `weather_time_pkt`), appending only genuinely new readings. This keeps the fact table growing correctly without reprocessing or duplicating history on every run.

**Archiving processed raw files**
Once Databricks successfully reads a batch of raw JSON files, they're moved into `raw/Done/`. This means a rescan of `raw/` only ever sees new, unprocessed data — critical for a notebook that reads a whole folder rather than tracking individual file state.

**HTTP connector instead of REST**
ADF's REST connector failed on Open-Meteo's chunked responses with a decoding error. Switching the source and sink to the HTTP connector resolved it, since HTTP treats the response as a file rather than parsing it structurally.

## Challenges & what they taught

| Challenge | Fix |
|---|---|
| Azure Free Trial capped most VM families at 0 vCPUs | Switched cluster policy to Unrestricted |
| ADF REST connector failed on chunked API responses | Switched to the HTTP connector for both source and sink |
| Unity Catalog blocked `input_file_name()` and external table registration | Used `_metadata.file_path`; set up a managed identity, storage credential, and external location |
| Re-reading old raw files caused duplicate history | Archived processed files to `raw/Done/` after each run |
| A silent join-key bug in the fact table's anti-join stopped new data from loading for four days despite the notebook reporting "success" | The anti-join matched on `city_id` alone instead of `city_id` + `weather_time_pkt`, so it excluded *any* row for a city already present — fixed by matching on both columns; a good reminder that "no error" isn't the same as "working correctly" |
| Unsaved ADF work was lost after closing a browser tab | Publish immediately after every working change, not at the end of a session |
| Adding new columns broke strict Delta schema enforcement | Used `mergeSchema`/`overwriteSchema` for the one-time change, then removed the option to restore strict enforcement |

## Repository structure

```
notebooks/
  00_setup_config.py        shared paths, catalog/schema context
  01_raw_to_processed.py    flatten, tag, dedupe, archive
  02_processed_to_gold.py   star schema + reporting tables
docs/
  architecture_diagram.png
  presentation_deck.pptx
```

## Status

Actively running on a 8-hour schedule, accumulating a genuine historical time-series across ten cities. Dashboard connects live to the gold layer via Databricks SQL.
