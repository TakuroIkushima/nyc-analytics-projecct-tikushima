-- Clean and standardize 311 DOT service request data
-- One row per service request

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number,
           filing_date,
           approved_date,
           current_status_date,
           incident_zip,
           borough,
           incident_address,
           latitude,
           longitude,
           filing_representative_first_name,
           filing_representative_middle_initial,
           filing_representative_last_name,
           applicant_first_name,
           applicants_middle_initial,
           applicant_last_name,
           zip

       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_id,

       -- Date/Time
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(current_status_date AS STRING) AS current_status_date,

       -- Request details
       CAST(filing_representative_first_name AS STRING) AS filing_representative_first_name,
       CAST(filing_representative_middle_initial AS STRING) AS filing_representative_middle_initial,
       CAST(filing_representative_last_name AS STRING) AS filing_representative_last_name,
       CAST(applicant_first_name AS STRING) AS applicant_first_name,
       CAST(applicants_middle_initial AS STRING) AS applicants_middle_initial,
       CAST(applicant_last_name AS STRING) AS applicant_last_name,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(incident_zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(incident_zip AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 5 THEN CAST(incident_zip AS STRING)
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 9 THEN CAST(incident_zip AS STRING)
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(incident_zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(incident_zip AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(incident_address AS STRING) AS incident_address,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,


       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_dob_job_filings

