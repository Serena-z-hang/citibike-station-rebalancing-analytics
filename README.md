# Citi Bike Station Health & Rebalancing Analytics

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
- Trips analyzed: **5,246,236**
- Analysis grain: **station × hour**
- Raw files: 6 CSV files

## Data Quality & Entity Resolution

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

## Trip Duration Quality Audit

Trip-duration profiling was used to identify unusual records without automatically treating them as invalid.

- Median trip duration: **9.78 minutes**
- 99th percentile: **65.83 minutes**
- Trips longer than 4 hours: **4,286**

Long-duration trips were flagged for review rather than automatically removed because unusual observations are not necessarily erroneous.

## Rebalancing KPI Framework

Trips were aggregated to the station-hour level.

Three dimensions were used to evaluate operational pressure:

- **Imbalance Severity** — how directional station flow is
- **Activity** — how much trip volume occurs at the station-hour
- **Persistence** — how consistently the pressure pattern occurs across active days

These measures were combined into a **Priority Score** to rank station-hour combinations for operational investigation.

The score is a prioritization signal, **not a probability that a station is empty or full**.

## Key Findings

- Bike-availability pressure is concentrated around the morning commute.
- At **8 AM, 675 stations** were flagged for bike-availability pressure under the project methodology.
- Dock-availability pressure becomes more prominent later in the day, with another concentration during the evening period.
- Station-ID normalization materially changed some apparent rebalancing signals, demonstrating the importance of data reliability before operational decision-making.

## Interactive Dashboard

The Tableau dashboard includes:

- **Priority Map** — where pressure is concentrated
- **Top 10 Rebalancing Priorities** — which stations deserve attention first
- **Rebalancing Pressure by Hour** — when system-wide pressure is highest
- **Interactive Hour Filter** — updates the map and station ranking while preserving the full-day pressure profile

## Limitations

This analysis uses trip flows rather than real-time station inventory or dock-capacity data.

Therefore, the dashboard identifies **bike- and dock-availability pressure signals**, not confirmed stockouts or full-station events.

## Dashboard

Interactive Tableau Public dashboard:  
*Link to be added*

---

### Author

**Serena Zhang**  
MS Business Analytics | University of Rochester, Simon Business School
