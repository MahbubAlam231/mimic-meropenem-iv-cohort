
CREATE TEMP TABLE iv_neb_pneumonia_cohort AS
WITH mero_iv_start AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    MIN(starttime) AS first_iv_start,
    MIN(LOWER(antibiotic)) AS first_iv_drug
  FROM mimiciv_derived.medication_antibiotic
  WHERE LOWER(antibiotic) = 'meropenem'
    AND LOWER(route) IN ('iv', 'intravenous')
  GROUP BY subject_id, hadm_id, stay_id
),

pneumonia_diagnosis AS (
  SELECT DISTINCT d.subject_id, d.hadm_id, dd.long_title AS pneumonia_dx
  FROM mimiciv_hosp.diagnoses_icd d
  LEFT JOIN mimiciv_hosp.d_icd_diagnoses dd
    ON d.icd_code = dd.icd_code AND d.icd_version = dd.icd_version
  WHERE (
    (d.icd_version = 9 AND d.icd_code BETWEEN '480' AND '486')
    OR (d.icd_version = 10 AND d.icd_code BETWEEN 'J12' AND 'J18')
    OR LOWER(dd.long_title) LIKE '%pneumonia%'
  )
),

cystic_fibrosis AS (
  SELECT DISTINCT subject_id, hadm_id
  FROM mimiciv_hosp.diagnoses_icd
  WHERE (
    (icd_version = 9 AND icd_code LIKE '277%')
    OR (icd_version = 10 AND icd_code LIKE 'E84%')
  )
),

admit_info AS (
  SELECT subject_id, hadm_id, admittime
  FROM mimiciv_hosp.admissions
),

infection_info AS (
  SELECT
    subject_id,
    hadm_id,
    MIN(suspected_infection_time) AS suspected_infection_time,
    MIN(antibiotic_time) AS first_abx_time,
    MIN(culture_time) AS first_culture_time
  FROM mimiciv_derived.sepsis_suspicion_of_infection
  GROUP BY subject_id, hadm_id
)

SELECT
  n.subject_id,
  n.hadm_id,
  n.stay_id,
  a.admittime,
  i.suspected_infection_time,
  i.first_abx_time,
  i.first_culture_time,
  p.pneumonia_dx,
  n.first_neb_start,
  n.first_neb_drug,
  ROUND((EXTRACT(EPOCH FROM (n.first_neb_start - i.suspected_infection_time)) / 3600)::numeric, 1) AS neb_delay_from_suspected_hours,
  ROUND((EXTRACT(EPOCH FROM (i.suspected_infection_time - a.admittime)) / 3600)::numeric, 1) AS infection_delay_from_admit_hours
FROM neb_start n
JOIN pneumonia_diagnosis p
  ON n.subject_id = p.subject_id AND n.hadm_id = p.hadm_id
JOIN admit_info a
  ON n.subject_id = a.subject_id AND n.hadm_id = a.hadm_id
LEFT JOIN infection_info i
  ON n.subject_id = i.subject_id AND n.hadm_id = i.hadm_id
WHERE (n.subject_id, n.hadm_id) NOT IN (
  SELECT subject_id, hadm_id FROM cystic_fibrosis
);





SELECT
  c.*,

  -- 1. Charlson Comorbidity
  ch.*,

  -- 2. Demographics (removed dod)
  d.admission_age,
  d.gender,
  d.race,
  d.icustay_seq,

  -- 3. First day blood gases
  bg.lactate_min,
  bg.lactate_max,
  bg.pao2fio2ratio_min,
  bg.pao2fio2ratio_max,

  -- 4. First day labs
  lab.wbc_min,
  lab.wbc_max,
  lab.albumin_min,
  lab.albumin_max,
  lab.creatinine_min,
  lab.creatinine_max,

  -- 5. First day RRT
  rtt.dialysis_present,
  rtt.dialysis_active,
  rtt.dialysis_type,

  -- 6. First day SOFA
  sofa.*,

  -- 7. Baseline creatinine
  base_cr.*,

  -- 8. OASIS
  oasis.*,

  -- 9. Ventilation
  vent.*,

  -- 10. Hospital outcome
  a.deathtime,
  a.hospital_expire_flag,

  -- 11. ICU stay info
  i.intime AS icu_intime,
  i.outtime AS icu_outtime,

  -- 12. Extubation time
  ext.extubation_time

FROM iv_neb_pneumonia_cohort c

-- 1. Comorbidities
LEFT JOIN mimiciv_derived.comorbidity_charlson ch
  ON c.subject_id = ch.subject_id AND c.hadm_id = ch.hadm_id

-- 2. Demographics
LEFT JOIN mimiciv_derived.demographics_icustay_detail d
  ON c.subject_id = d.subject_id AND c.stay_id = d.stay_id

-- 3. Blood gases
LEFT JOIN mimiciv_derived.firstday_first_day_bg bg
  ON c.subject_id = bg.subject_id AND c.stay_id = bg.stay_id

-- 4. Labs
LEFT JOIN mimiciv_derived.firstday_first_day_lab lab
  ON c.subject_id = lab.subject_id AND c.stay_id = lab.stay_id

-- 5. RRT
LEFT JOIN mimiciv_derived.firstday_first_day_rtt rtt
  ON c.subject_id = rtt.subject_id AND c.stay_id = rtt.stay_id

-- 6. SOFA
LEFT JOIN mimiciv_derived.firstday_first_day_sofa sofa
  ON c.subject_id = sofa.subject_id AND c.stay_id = sofa.stay_id

-- 7. Baseline Creatinine
LEFT JOIN mimiciv_derived.measurement_creatinine_baseline base_cr
  ON c.hadm_id = base_cr.hadm_id

-- 8. OASIS
LEFT JOIN mimiciv_derived.score_oasis oasis
  ON c.subject_id = oasis.subject_id AND c.stay_id = oasis.stay_id

-- 9. Ventilation
LEFT JOIN mimiciv_derived.treatment_ventilation vent
  ON c.stay_id = vent.stay_id

-- 10. Admissions outcome
LEFT JOIN mimiciv_hosp.admissions a
  ON c.subject_id = a.subject_id AND c.hadm_id = a.hadm_id

-- 11. ICU stay timing
LEFT JOIN mimiciv_icu.icustays i
  ON c.subject_id = i.subject_id AND c.hadm_id = i.hadm_id AND c.stay_id = i.stay_id

-- 12. Extubation event from chartevents
LEFT JOIN (
  SELECT subject_id, stay_id, MIN(storetime) AS extubation_time
  FROM mimiciv_icu.chartevents ce
  JOIN mimiciv_icu.d_items di ON ce.itemid = di.itemid
  WHERE LOWER(di.label) LIKE '%extubat%' OR LOWER(di.label) LIKE '%et tube remov%'
  GROUP BY subject_id, stay_id
) ext
  ON c.subject_id = ext.subject_id AND c.stay_id = ext.stay_id
