# Citi Bike Station Health & Rebalancing Analytics

## Dashboard Preview

![Citi Bike Station Health & Rebalancing Analytics Dashboard](citibike_dashboard_github_preview.png)

### [View the Interactive Tableau Dashboard](https://public.tableau.com/views/CitiBike_Rebalancing_Analytics_Final/1?:language=zh-CN&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## Project Overview

This project analyzes **5,246,236 Citi Bike trips from August 2026** to identify station-hour rebalancing priorities across New York City.

The analysis is designed around three operational questions:

- **Where** is bike- or dock-availability pressure concentrated?
- **Which stations** should receive attention first at a selected hour?
- **When** is rebalancing pressure highest throughout the day?

Rather than treating unusual patterns as immediate operational problems, the project follows a **data-quality-first workflow**. Station identities, trip behavior, and KPI definitions are validated before generating operational recommendations.

## Business Question

**How can Citi Bike trip data be transformed into a reliable station-hour prioritization framework for rebalancing decisions?**

The objective is not to predict exact bike inventory. Instead, the project uses trip-flow patterns to identify station-hours that may deserve greater operational attention.

## Tools

- **DuckDB** — querying and aggregating 5M+ trip records
- **Python** — analysis workflow and validation
- **Tableau** — interactive operational dashboard
- **Google Drive / Colab** — data storage and analysis environment

## Data

- **Source:** Citi Bike trip data
- **Period:** August 2026
- **Raw files:** 6 CSV files
- **Trips analyzed:** **5,246,236**
- **Raw-data grain:** one row per bike trip
- **Operational analysis grain:** station × date × hour

The raw trip files are not included in this repository because of their size.

## Data Quality First

A major focus of this project was determining whether apparent operational problems were real mobility patterns or artifacts of the underlying data.

Two important QA areas were investigated:

1. Trip-duration behavior
2. Station-identifier consistency

This mattered because inaccurate data could directly distort downstream rebalancing KPIs and lead to incorrect operational conclusions.

## Trip Duration Quality Audit

Trip durations were profiled before making any filtering decision.

Key results:

- **Median trip duration:** 9.78 minutes
- **99th percentile:** 65.83 minutes
- **Trips longer than 4 hours:** 4,286

Long-duration trips were flagged for review rather than automatically removed.

The guiding principle was:

> **Unusual does not automatically mean invalid.**

Automatically deleting every long-duration trip could remove legitimate rides and introduce unnecessary bias into the analysis.

## Station Entity Resolution

One of the most important findings came from station-ID validation.

Some stations initially appeared to have extreme one-way flow patterns, suggesting severe bike- or dock-availability pressure.

Further investigation showed that some physical stations were represented by multiple station-ID formats.

For example:

- `5343.1`
- `5343.10`

These identifiers referred to the same physical station location, but the trip records were split across two IDs.

Before normalization:

- one ID appeared strongly arrival-dominant
- the other appeared strongly departure-dominant

After resolving the two IDs into one canonical station key:

- **Arrivals:** 7,605
- **Departures:** 7,497

The apparent extreme imbalance largely disappeared.

This demonstrated an important analytical lesson:

> **A data-quality problem can create a false business signal.**

Without entity resolution, an operations team could incorrectly prioritize a station for rebalancing.

## Canonical Station Key

Station IDs were normalized before downstream KPI construction.

The normalization logic was designed to handle cases such as:

- `5343.1` → `5343.10`
- `5343.10` → `5343.10`
- `5303.06_` → `5303.06`

At the same time, legitimate alphanumeric station IDs such as:

- `SYS016`
- `HB103`
- `JC002`

were preserved.

This avoided the mistake of simply converting every station ID to a numeric value.

## Station-Hour Aggregation

Trip-level data was transformed into a **station × date × hour** analytical structure.

For each station-hour, the workflow calculated:

- Arrivals
- Departures
- Net flow
- Total activity
- Imbalance rate
- Bike-pressure flag
- Dock-pressure flag

Definitions:

```text
Net Flow = Arrivals - Departures

Total Activity = Arrivals + Departures

Imbalance Rate = Net Flow / Total Activity
```

Interpretation:

- **Negative net flow** → bikes are leaving faster than they arrive
- **Positive net flow** → bikes are accumulating faster than they leave

Importantly:

> **Net flow is not the same as real-time station inventory.**

The project therefore describes results as availability-pressure signals rather than confirmed empty or full stations.

## Complete Station-Hour Grid

A second important data-quality issue involved the denominator used for persistence.

If a station had no rides during a particular hour, that station-hour could disappear from the observed dataset.

This could create misleading results such as:

> 22 pressure days / 22 observed days = 100% persistence

even though the station may have had zero activity on several additional days.

To solve this, the workflow created a complete:

**station × active date × 24-hour grid**

Zero-activity station-hours were explicitly retained.

This ensured that persistence reflected the correct denominator.

## Rebalancing KPI Framework

The project evaluates three dimensions of operational pressure.

### 1. Imbalance Severity

Measures how directional station flow is relative to total activity.

A strongly one-sided flow pattern may indicate elevated bike- or dock-availability pressure.

### 2. Activity

Measures the total volume of trips occurring at a station-hour.

Activity is important because a station with very high imbalance but extremely low trip volume may have less operational impact than a high-volume station with a slightly lower imbalance rate.

### 3. Persistence

Measures how consistently the pressure pattern appears across active days.

A recurring imbalance is more operationally meaningful than an isolated one-day event.

## Pressure Classification

The project uses station-day imbalance signals to classify pressure.

Analytical thresholds:

```text
Imbalance Rate <= -0.20
→ Bike Availability Pressure

Imbalance Rate >= +0.20
→ Dock Availability Pressure
```

These thresholds are analytical decision rules used for prioritization.

They are **not** physical inventory limits.

## Priority Score

To rank station-hours, the three KPI components are normalized and combined into a composite Priority Score.

Project weighting:

```text
40% Imbalance Severity
30% Activity
30% Persistence
```

The resulting score is scaled to approximately **0–100**.

The Priority Score is designed to answer:

> **Which station-hours deserve operational attention first?**

It is **not** a probability that a station is empty or full.

## Key Findings

### Morning Bike-Availability Pressure

Bike-availability pressure is strongly concentrated around the morning commute.

At **8 AM**, the dashboard identifies **675 prioritized stations with Bike Availability Pressure** under the project methodology.

### Evening Dock-Availability Pressure

Dock-availability pressure becomes more prominent later in the day.

The hourly profile shows another concentration during the evening period, indicating that rebalancing needs vary substantially by time of day.

### Pressure Is Highly Time-Dependent

A station that is high priority at 8 AM may not remain high priority at 5 PM.

This is why the dashboard allows the user to change the selected hour and dynamically update:

- the station map
- the Top 10 priority ranking

while preserving the full-day hourly trend.

### Data Reliability Changes Business Conclusions

The station-ID example showed that data cleaning was not just a preprocessing task.

The potential failure chain was:

```text
Poor entity resolution
        ↓
Distorted station flows
        ↓
Misleading KPI
        ↓
Incorrect operational priority
```

For this reason, data-quality validation was treated as part of the decision-making workflow.

## Interactive Tableau Dashboard

The Tableau dashboard contains three core views.

### Priority Map

Shows where bike- and dock-availability pressure is geographically concentrated for the selected hour.

### Top 10 Rebalancing Priorities

Ranks the highest-priority stations for the selected hour using the composite Priority Score.

### Rebalancing Pressure by Hour

Shows how the number of prioritized stations changes across the full 24-hour day.

The interactive **Hour** filter updates the Priority Map and Top 10 ranking while leaving the full-day pressure profile unchanged.

### [Open the Interactive Dashboard on Tableau Public](https://public.tableau.com/views/CitiBike_Rebalancing_Analytics_Final/1?:language=zh-CN&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## Repository Files

```text
citibike-station-rebalancing-analytics/
│
├── README.md
├── citibike_dashboard_github_preview.png
├── citibike_rebalancing_analysis.ipynb
└── station_rebalancing_analysis.sql
```

### `citibike_rebalancing_analysis.ipynb`

Analysis notebook covering:

- data loading
- trip-count validation
- schema review
- trip-duration QA
- station-ID normalization
- entity resolution
- station-hour aggregation
- complete hour-grid construction
- KPI development
- Priority Score construction
- Tableau-ready output

### `station_rebalancing_analysis.sql`

DuckDB SQL workflow covering the main transformation and KPI logic.

The input file path is intentionally left as a placeholder:

```sql
'/path/to/202608-citibike-tripdata/*.csv'
```

Users should replace this with the local path containing the August 2026 Citi Bike CSV files.

## Limitations

This project uses historical trip flows rather than real-time station inventory.

Therefore:

- Bike Availability Pressure does not prove that a station was empty
- Dock Availability Pressure does not prove that all docks were full
- Station capacity is not directly modeled
- Rebalancing truck routes and vehicle capacity are not included
- Weather effects are not included
- Special events are not explicitly modeled
- Results reflect August 2026 behavior and may differ across seasons

## Potential Extensions

A production-oriented version of the analysis could incorporate:

- Real-time bike inventory
- Real-time dock availability
- Station capacity
- Weather data
- Special-event calendars
- Rebalancing truck capacity
- Travel time between stations
- Dynamic routing optimization
- Demand forecasting
- Cost-sensitive rebalancing decisions

## Analytical Takeaways

1. **Validate the data before trusting the KPI.**
2. **Outlier detection is not the same as outlier deletion.**
3. **Entity resolution can materially change business conclusions.**
4. **KPI denominators matter as much as KPI formulas.**
5. **Operational decisions require both severity and scale.**
6. **A prioritization score should not be interpreted as a probability.**
7. **Analytics is most useful when it connects data reliability to a concrete decision.**

## Author

**Serena Zhang**  
MS Business Analytics  
Simon Business School, University of Rochester
