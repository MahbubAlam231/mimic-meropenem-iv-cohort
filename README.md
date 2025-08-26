# SQL : Meropenem IV Cohort (MIMIC-IV)

SQL scripts to establish an ICU patient cohort receiving **intravenous meropenem** in the MIMIC-IV database and extract covariates for machine-learning-based risk-factor analysis.

## Overview

This repository provides:

* A cohort definition based on **meropenem administered via IV**.
* Reusable SQL for covariate extraction suitable for downstream ML and statistical modeling.
* Notes for running on either **PostgreSQL (local)** or **Google BigQuery**.

> MIMIC-IV is a large, de-identified critical care database hosted on PhysioNet. Access requires credentialing and a data use agreement. ([PubMed][1], [PhysioNet][2])

---

## Data Access (MIMIC-IV)

1. **Complete human-subjects/privacy training** (CITI Program “Data or Specimens Only Research”). ([PhysioNet][3])
2. **Request PhysioNet credentialed access** and sign the **Data Use Agreement (DUA)** for MIMIC-IV. ([PhysioNet][4])
3. **Choose your compute environment**:

   * **BigQuery** (recommended for ease & scale): MIMIC-IV v3.1 is available as `mimiciv_v3_1_hosp` / `mimiciv_v3_1_icu`. ([PhysioNet][2])
   * **Local PostgreSQL**: load MIMIC-IV using community scripts (see links below). ([GitHub][5], [PhysioNet][6])

**Cite MIMIC-IV:**
Johnson AEW, et al. *MIMIC-IV, a freely accessible electronic health record dataset.* Sci Data. 2023;10(1):1. doi:10.1038/s41597-022-01899-x. ([PubMed][1], [Nature][7])

---

## Repository Structure

```
.
├── sql/
│   ├── sql_for_meropenem_iv_cohort.sql   # cohort + covariates
│   └── utils/                            # optional helpers (e.g., views)
├── README.md
└── LICENSE
```
---

## Cohort Definition (Summary)

* **Inclusion**

  * ICU stays in MIMIC-IV with documented **meropenem** administration **via IV**.
  * Index time = **first IV meropenem start** during the ICU stay.
* **Exclusions (example; adjust as needed)**

  * Age < 18 years at admission.
  * Missing key timestamps or implausible intervals.

> Adapt filters to your study protocol and local IRB requirements.

---

## Covariates (Examples)

The script demonstrates how to join cohort rows to commonly used MIMIC tables to derive:

* Demographics & admission details
* Comorbidity summaries (e.g., Charlson)
* Severity scores (e.g., SOFA/OASIS at or prior to index)
* Vitals/labs around index window
* Organ support (e.g., ventilation) and early interventions

> Exact fields and windows are configurable near the top of the SQL.

---

## Quick Start

### Option A — BigQuery

1. Upload `sql_for_meropenem_iv_cohort.sql` to BigQuery Console or run via `bq` CLI.
2. Set project + dataset and execute the script against **MIMIC-IV v3.1** (`mimiciv_v3_1_hosp`, `mimiciv_v3_1_icu`). ([PhysioNet][2])

### Option B — Local PostgreSQL

1. Load MIMIC-IV into Postgres (see community loaders). ([GitHub][5], [PhysioNet][6])
2. Set your `search_path` to the MIMIC schemas, then run:

```bash
psql 'dbname=mimic4 user=<you> options=--search_path=mimiciv' -f sql/sql_for_meropenem_iv_cohort.sql
```

---

## Reproducibility

* **Versioning:** Note the MIMIC-IV version and date (e.g., v3.1). Schema names/tables can change between versions. ([PhysioNet][2])
* **Determinism:** Seed any stochastic steps downstream (e.g., train/val/test splits).
* **Provenance:** Record your SQL commit hash and BigQuery job IDs or Postgres dump checksum.

---

## Ethics & Compliance

* Use only for approved research purposes consistent with the MIMIC-IV DUA.
* Do not attempt re-identification.
* Follow institutional IRB/ethics guidance.

---

## Helpful Links

* **MIMIC-IV dataset page (v3.1 / v2.2)** — versions, schema notes, and updates. ([PhysioNet][2])
* **PhysioNet credentialing & DUA** — steps to request access. ([PhysioNet][4])
* **CITI course instructions for PhysioNet** — recommended training track. ([PhysioNet][3])
* **Postgres loading examples** — community loaders and scripts. ([GitHub][5], [PhysioNet][6])
* **MIMIC-IV paper (Sci Data, 2023)** — canonical reference. ([PubMed][1], [Nature][7])

---

## Citation

* **MIMIC-IV:** Johnson AEW, et al. *MIMIC-IV, a freely accessible electronic health record dataset.* Sci Data. 2023;10(1):1. doi:10.1038/s41597-022-01899-x. ([PubMed][1])

---

## License

This code is released under the MIT License. Note that **MIMIC-IV data** remain governed by the PhysioNet DUA and are **not** redistributed here.

---

[1]: https://pubmed.ncbi.nlm.nih.gov/36596836/
[2]: https://physionet.org/content/mimiciv/
[3]: https://physionet.org/about/citi-course/
[4]: https://physionet.org/news/post/395
[5]: https://github.com/yikuan8/MIMIC-IV-Postgres
[6]: https://physionet.org/content/mimic-iv-ed/
[7]: https://www.nature.com/articles/s41597-022-01899-x
