-- =========================================================
-- Insurance Claims & Fraud Detection
-- Data Cleaning - Customers
-- AWS Athena / SQL
-- =========================================================

CREATE TABLE insurance_fraud_db.clean_customers AS

SELECT
    TRIM(customer_id) AS customer_id,

    TRIM(first_name) AS first_name,

    TRIM(last_name) AS last_name,

    REGEXP_REPLACE(customer_name, ' +', ' ') AS customer_name,

    TRY_CAST(age AS INT) AS age,

    CASE
        WHEN UPPER(TRIM(gender)) = 'FEMALE' THEN 'Female'
        WHEN UPPER(TRIM(gender)) = 'MALE' THEN 'Male'
        WHEN UPPER(TRIM(gender)) = 'OTHER' THEN 'Other'
        WHEN TRIM(gender) = '' OR gender IS NULL THEN 'Unknown'
        ELSE TRIM(gender)
    END AS gender,

    CASE
        WHEN occupation IS NULL OR TRIM(occupation) = ''
            THEN 'Unknown'
        ELSE TRIM(occupation)
    END AS occupation,

    TRY_CAST(annual_income_inr AS DOUBLE) AS annual_income_inr,

    CONCAT(
        UPPER(SUBSTR(TRIM(location), 1, 1)),
        SUBSTR(TRIM(location), 2)
    ) AS location,

    CONCAT(
        UPPER(SUBSTR(TRIM(state), 1, 1)),
        SUBSTR(TRIM(state), 2)
    ) AS state,

    TRY_CAST(customer_since AS DATE) AS customer_since

FROM insurance_fraud_db.customers;



-- =========================================================
-- Insurance Claims & Fraud Detection
-- Data Cleaning - Claims
-- AWS Athena / SQL
-- =========================================================

CREATE TABLE insurance_fraud_db.clean_claims AS

SELECT
    TRIM(claim_id) AS claim_id,

    TRIM(policy_term_id) AS policy_term_id,

    TRIM(policy_id) AS policy_id,

    TRIM(customer_id) AS customer_id,

    TRY_CAST(incident_date AS DATE) AS incident_date,

    TRY_CAST(claim_date AS DATE) AS claim_date,

    TRIM(claim_type) AS claim_type,

    TRY_CAST(claim_amount_inr AS DOUBLE) AS claim_amount_inr,

    TRY_CAST(approved_amount_inr AS DOUBLE) AS approved_amount_inr,

    CASE
        WHEN claim_status IS NULL OR TRIM(claim_status) = ''
            THEN 'Unknown'
        ELSE TRIM(claim_status)
    END AS claim_status,

    CONCAT(
        UPPER(SUBSTR(TRIM(claim_location), 1, 1)),
        SUBSTR(TRIM(claim_location), 2)
    ) AS claim_location,

    CASE
        WHEN reported_channel IS NULL OR TRIM(reported_channel) = ''
            THEN 'Unknown'
        ELSE TRIM(reported_channel)
    END AS reported_channel,

    TRY_CAST(decision_date AS DATE) AS decision_date,

    TRY_CAST(actual_fraud_label AS INT) AS actual_fraud_label

FROM insurance_fraud_db.claims;



