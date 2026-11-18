
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_source_service_requests_project') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date_details') }}
),

dim_location AS (
    SELECT * FROM {{ ref('dim_location_details') }}
    WHERE location_id != '-1'
),

dim_request AS (
    SELECT * FROM {{ ref('dim_request_details') }}
    WHERE request_type_details != '-1'
),

dim_geo AS (
    SELECT * FROM {{ ref('dim_sr_geolocation') }}
    WHERE sr_geo_id != '-1'
),

fact_311_data AS (

    SELECT
        s.request_id AS unique_key,

        CASE WHEN s.created_date IS NULL THEN '-1' ELSE cd.date_id END AS created_date,
        CASE WHEN s.closed_date  IS NULL THEN '-1' ELSE xd.date_id END AS closed_date,

        COALESCE(l.location_id, '-1')          AS request_location_id,
        COALESCE(r.request_type_details, '-1') AS request_type,
        COALESCE(g.sr_geo_id, '-1')            AS geo_id,

        s.agency,
        s.agency_name,
        s.method_of_submission AS open_data_channel_type,
        s.latitude,
        s.longitude

    FROM stg_311 s

    LEFT JOIN dim_date cd
        ON CAST(s.created_date AS DATE) = cd.full_date

    LEFT JOIN dim_date xd
        ON CAST(s.closed_date AS DATE) = xd.full_date

    LEFT JOIN dim_location l
        ON  s.borough IS NOT DISTINCT FROM l.borough
        AND REGEXP_EXTRACT(s.zip, r'^[0-9]{5}') IS NOT DISTINCT FROM l.postcode

    LEFT JOIN dim_request r
        ON  s.complaint_type IS NOT DISTINCT FROM r.problem
        AND s.descriptor IS NOT DISTINCT FROM r.problem_detail
        AND s.resolution_description IS NOT DISTINCT FROM r.resolution_description
        AND s.status IS NOT DISTINCT FROM r.status

    LEFT JOIN dim_geo g
        ON  SAFE_CAST(REPLACE(CAST(s.x_coordinate_state_plane AS STRING), ',', '') AS FLOAT64)
                IS NOT DISTINCT FROM g.x_coordinate
        AND SAFE_CAST(REPLACE(CAST(s.y_coordinate_state_plane AS STRING), ',', '') AS FLOAT64)
                IS NOT DISTINCT FROM g.y_coordinate
        AND UPPER(NULLIF(TRIM(s.cross_street_1), ''))
                IS NOT DISTINCT FROM UPPER(g.cross_street_1)
        AND UPPER(NULLIF(TRIM(s.intersection_street_1), ''))
                IS NOT DISTINCT FROM UPPER(g.intersection_street_1)
)

SELECT * FROM fact_311_data