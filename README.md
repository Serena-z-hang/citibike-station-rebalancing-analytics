# Citi Bike Station Health & Rebalancing Analytics

## Dashboard Preview

![Citi Bike Station Health & Rebalancing Analytics Dashboard](citibike_dashboard_github_preview.png)

[View the interactive Tableau dashboard](YOUR_TABLEAU_PUBLIC_LINK)

## Project Overview

This project analyzes **5,246,236 Citi Bike trips from August 2026** to identify station-hour rebalancing priorities across New York City.

The goal is to help operations teams understand:

- Where bike- and dock-availability pressure is concentrated
- Which stations should be prioritized at a selected hour
- When rebalancing pressure is highest throughout the day

Rather than treating unusual patterns as immediate operational problems, the project uses a **data-quality-first workflow** to validate station identities, trip behavior, and KPI definitions before generating recommendations.

## Business Question

**How can Citi Bike trip data be transformed into a reliable station-hour prioritization framework for rebalancing decisions?**

## Tools

- DuckDB
- Python
- Tableau
- Google Drive

## Data

- Source: Citi Bike trip data
- Period: August 2026
- Raw files: **6 CSV files**
- Trips analyzed: **5,246,236**
- Analysis grain: **station × hour**

## Data Quality & Entity Resolution

A key part of the project was validating whether apparent operational problems were actually caused by the data.

During the quality audit, some stations appeared to have extreme one-way flow patterns that initially looked like strong rebalancing signals.

Further investigation revealed that some physical stations were represented by multiple station IDs.

For example:

- `5343.1`
- `5343.10`

Both identifiers represented the same station location, but trip activity was split across the two IDs.

Before normalization, one ID appeared strongly arrival-dominant while the other appeared strongly departure-dominant.

After resolving them into a canonical station key:

- Arrivals: **7,605**
- Departures: **7,497**

The apparent imbalance largely disappeared.

This demonstrated that a **data-quality issue could create a false operational signal**, potentially leading to incorrect rebalancing decisions.

Station-ID normalization was therefore performed before constructing downstream KPIs.

## Trip Duration Quality Audit

Trip-duration profiling was used to understand unusual records without automatically treating them as invalid.

Key results:

- Median trip duration: **9.78 minutes**
- 99th percentile: **65.83 minutes**
- Trips longer than 4 hours: **4,286**

Long-duration trips were flagged for review rather than automatically removed because **unusual observations are not necessarily erroneous**.

This distinction is important for maintaining data reliability and avoiding unnecessary data loss.

## Station-Hour Aggregation

Trip-level records were transformed into a **station × date × hour** structure.

For each station-hour, the analysis calculated:

- Average arrivals
- Average departures
- Average net flow
- Average total activity
- Bike-pressure persistence
- Dock-pressure persistence

This aggregation makes the data usable for operational decision-making at the time and location level.

## Rebalancing KPI Framework

The rebalancing framework evaluates three dimensions:

### 1. Imbalance Severity

Measures how directional station flow is relative to total activity.

A station with strongly one-sided arrivals or departures may indicate potential availability pressure.

### 2. Activity

Measures the total volume of trips at a station-hour.

This prevents very low-volume stations from being prioritized solely because of a high imbalance ratio.

### 3. Persistence

Measures how consistently a pressure pattern appears across active days.

A complete station-hour grid was used so that zero-activity hours were included in the denominator, preventing persistence from being overstated.

## Priority Score

The project combines severity, activity, and persistence into a composite **Priority Score** used to rank station-hour combinations for operational investigation.

The score is intended to answer:

**Which station-hours deserve operational attention first?**

It is a prioritization signal, **not a probability that a station is empty or full**.

Because real-time bike inventory and dock-capacity data were not available, the analysis refers to:

- **Bike Availability Pressure**
- **Dock Availability Pressure**

rather than confirmed stockouts or full-station events.

## Key Findings

- Bike-availability pressure is strongly concentrated around the morning commute.
- At **8 AM, 675 stations** were flagged for bike-availability pressure under the project methodology.
- Dock-availability pressure becomes more prominent later in the day, with another concentration during the evening period.
- Rebalancing pressure varies substantially by hour, reinforcing the importance of time-specific operational planning.
- Station-ID normalization materially changed some apparent rebalancing signals, demonstrating the importance of validating data quality before making operational recommendations.

## Interactive Dashboard

The Tableau dashboard includes three core views:

### Priority Map

Shows where bike- and dock-availability pressure is concentrated across the Citi Bike network.

### Top 10 Rebalancing Priorities

Ranks the highest-priority stations for the selected hour based on the composite Priority Score.

### Rebalancing Pressure by Hour

Shows how the number of prioritized stations changes throughout the day for bike- and dock-availability pressure.

The interactive **Hour** filter updates the Priority Map and Top 10 ranking while preserving the full 24-hour pressure profile.

## Why Data Reliability Matters

A central lesson from the project is that a strong operational signal is only useful if the underlying data is reliable.

The station-ID issue showed that:

**bad entity resolution → distorted station flows → misleading KPI → potentially incorrect business decision**

For this reason, data-quality validation was treated as part of the analytical workflow rather than as a separate preprocessing task.

## Limitations

This analysis uses trip flows rather than real-time station inventory or dock-capacity data.

Therefore:

- The dashboard identifies pressure signals rather than confirmed bike shortages or full docks
- Priority Score thresholds are analytical decision rules rather than physical system constraints
- The analysis does not directly model bike availability in real time
- Results are based on August 2026 trip behavior and may vary by season

Future improvements could incorporate:

- Real-time station inventory
- Station dock capacity
- Weather
- Special events
- Rebalancing truck constraints
- Travel time between stations

## Repository Structure

```text
citibike-station-rebalancing-analytics/
│
├── README.md
├── citibike_dashboard_github_preview.png
│
├── notebooks/
│   └── citibike_rebalancing_analysis.ipynb
│
├── sql/
│   └── station_rebalancing_analysis.sql
│
└── output/
    └── station_hour_priorities.csv
