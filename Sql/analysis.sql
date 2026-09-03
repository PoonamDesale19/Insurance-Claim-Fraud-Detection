-- =========================================================
-- Insurance Claims & Fraud Detection
-- Business Analysis Queries
-- AWS Athena / SQL
-- =========================================================


-- =========================================================
-- 1. RISK LEVEL DISTRIBUTION
-- =========================================================

SELECT
    risk_level,
    COUNT(DISTINCT claim_id) AS claim_count,
    ROUND(
        100.0 * COUNT(DISTINCT claim_id)
        / SUM(COUNT(DISTINCT claim_id)) OVER (),
        2
    ) AS percentage
FROM insurance_fraud_db.fraud_risk_score
GROUP BY risk_level
ORDER BY
    CASE
        WHEN risk_level = 'High Risk' THEN 1
        WHEN risk_level = 'Medium Risk' THEN 2
        WHEN risk_level = 'Low Risk' THEN 3
    END;


-- =========================================================
-- 2. HIGH-RISK CLAIMS
-- =========================================================

SELECT
    claim_id,
    customer_id,
    customer_name,
    age,
    occupation,
    location,
    claim_type,
    claim_amount_inr,
    fraud_risk_score,
    risk_level
FROM insurance_fraud_db.high_risk_claims
ORDER BY fraud_risk_score DESC,
         claim_amount_inr DESC;


-- =========================================================
-- 3. HIGH-RISK CLAIM COUNT
-- =========================================================

SELECT
    COUNT(DISTINCT claim_id) AS high_risk_claims
FROM insurance_fraud_db.fraud_risk_score
WHERE risk_level = 'High Risk';


-- =========================================================
-- 4. HIGH-RISK CLAIM AMOUNT
-- =========================================================

SELECT
    COUNT(DISTINCT c.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS total_high_risk_claim_amount,
    AVG(c.claim_amount_inr) AS average_high_risk_claim_amount,
    MIN(c.claim_amount_inr) AS minimum_high_risk_claim_amount,
    MAX(c.claim_amount_inr) AS maximum_high_risk_claim_amount
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk';


-- =========================================================
-- 5. HIGH-RISK CLAIMS BY CLAIM TYPE
-- =========================================================

SELECT
    c.claim_type,
    COUNT(DISTINCT c.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS total_claim_amount
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk'
GROUP BY c.claim_type
ORDER BY high_risk_claim_count DESC;


-- =========================================================
-- 6. HIGH-RISK CLAIMS BY LOCATION
-- =========================================================

SELECT
    c.claim_location AS location,
    COUNT(DISTINCT c.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS total_claim_amount
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk'
GROUP BY c.claim_location
ORDER BY high_risk_claim_count DESC;


-- =========================================================
-- 7. HIGH-RISK CLAIMS BY OCCUPATION
-- =========================================================

SELECT
    cu.occupation,
    COUNT(DISTINCT r.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS total_claim_amount
FROM insurance_fraud_db.fraud_risk_score r
JOIN insurance_fraud_db.clean_claims c
    ON r.claim_id = c.claim_id
JOIN insurance_fraud_db.clean_customers cu
    ON r.customer_id = cu.customer_id
WHERE r.risk_level = 'High Risk'
GROUP BY cu.occupation
ORDER BY high_risk_claim_count DESC;


-- =========================================================
-- 8. TOP 10 HIGH-RISK CUSTOMERS
-- =========================================================

SELECT
    cu.customer_id,
    cu.customer_name,
    cu.age,
    cu.occupation,
    cu.location,
    COUNT(DISTINCT r.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS total_high_risk_claim_amount
FROM insurance_fraud_db.fraud_risk_score r
JOIN insurance_fraud_db.clean_claims c
    ON r.claim_id = c.claim_id
JOIN insurance_fraud_db.clean_customers cu
    ON r.customer_id = cu.customer_id
WHERE r.risk_level = 'High Risk'
GROUP BY
    cu.customer_id,
    cu.customer_name,
    cu.age,
    cu.occupation,
    cu.location
ORDER BY high_risk_claim_count DESC,
         total_high_risk_claim_amount DESC
LIMIT 10;


-- =========================================================
-- 9. CUSTOMER CLAIM FREQUENCY
-- =========================================================

SELECT
    customer_id,
    COUNT(DISTINCT claim_id) AS claim_count
FROM insurance_fraud_db.clean_claims
GROUP BY customer_id
HAVING COUNT(DISTINCT claim_id) > 1
ORDER BY claim_count DESC;


-- =========================================================
-- 10. TIMING RISK SUMMARY
--
-- Claim within 30 days after policy term starts
-- OR within 30 days before policy term ends
-- =========================================================

WITH timing_classification AS (
    SELECT DISTINCT
        c.claim_id,
        CASE
            WHEN date_diff(
                'day',
                pt.term_start_date,
                c.claim_date
            ) BETWEEN 0 AND 30
                THEN 'Within 30 days after policy start'

            WHEN date_diff(
                'day',
                c.claim_date,
                pt.term_end_date
            ) BETWEEN 0 AND 30
                THEN 'Within 30 days before policy end'

            ELSE 'Normal Timing'
        END AS timing_category
    FROM insurance_fraud_db.clean_claims c
    JOIN insurance_fraud_db.clean_policy_terms pt
        ON c.policy_term_id = pt.policy_term_id
)

SELECT
    timing_category,
    COUNT(DISTINCT claim_id) AS claim_count
FROM timing_classification
GROUP BY timing_category
ORDER BY
    CASE
        WHEN timing_category = 'Within 30 days after policy start'
            THEN 1
        WHEN timing_category = 'Within 30 days before policy end'
            THEN 2
        ELSE 3
    END;


-- =========================================================
-- 11. TIMING RISK TOTAL
-- =========================================================

WITH timing_classification AS (
    SELECT DISTINCT
        c.claim_id,
        CASE
            WHEN date_diff(
                'day',
                pt.term_start_date,
                c.claim_date
            ) BETWEEN 0 AND 30
                THEN 1

            WHEN date_diff(
                'day',
                c.claim_date,
                pt.term_end_date
            ) BETWEEN 0 AND 30
                THEN 1

            ELSE 0
        END AS timing_risk
    FROM insurance_fraud_db.clean_claims c
    JOIN insurance_fraud_db.clean_policy_terms pt
        ON c.policy_term_id = pt.policy_term_id
)

SELECT
    SUM(timing_risk) AS timing_risk_claims,
    COUNT(DISTINCT claim_id) AS total_claims,
    ROUND(
        100.0 * SUM(timing_risk)
        / COUNT(DISTINCT claim_id),
        2
    ) AS timing_risk_percentage
FROM timing_classification;


-- =========================================================
-- 12. HIGH-RISK CLAIMS BY RISK INDICATOR
-- =========================================================

SELECT
    SUM(
        CASE
            WHEN frequent_small_claim_score > 0 THEN 1
            ELSE 0
        END
    ) AS frequent_small_claims,

    SUM(
        CASE
            WHEN high_claim_amount_score > 0 THEN 1
            ELSE 0
        END
    ) AS high_claim_amount_claims,

    SUM(
        CASE
            WHEN investigation_score > 0 THEN 1
            ELSE 0
        END
    ) AS investigation_related_claims,

    SUM(
        CASE
            WHEN approval_discrepancy_score > 0 THEN 1
            ELSE 0
        END
    ) AS approval_discrepancy_claims,

    SUM(
        CASE
            WHEN inconsistency_score > 0 THEN 1
            ELSE 0
        END
    ) AS information_inconsistency_claims,

    SUM(
        CASE
            WHEN timing_score > 0 THEN 1
            ELSE 0
        END
    ) AS timing_risk_claims
FROM insurance_fraud_db.fraud_risk_score
WHERE risk_level = 'High Risk';


-- =========================================================
-- 13. HIGH-RISK CLAIM AMOUNT BY CLAIM TYPE
-- =========================================================

SELECT
    c.claim_type,
    COUNT(DISTINCT c.claim_id) AS high_risk_claim_count,
    SUM(c.claim_amount_inr) AS high_risk_claim_amount,
    AVG(c.claim_amount_inr) AS average_claim_amount
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk'
GROUP BY c.claim_type
ORDER BY high_risk_claim_amount DESC;


-- =========================================================
-- 14. HIGH-RISK CLAIMS BY CITY
-- =========================================================

SELECT
    c.claim_location AS city,
    COUNT(DISTINCT c.claim_id) AS high_risk_claim_count
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk'
GROUP BY c.claim_location
ORDER BY high_risk_claim_count DESC;


-- =========================================================
-- 15. HIGH-RISK CLAIM DETAILS
-- =========================================================

SELECT
    c.claim_id,
    cu.customer_name,
    cu.age,
    cu.occupation,
    c.claim_location AS city,
    c.claim_type,
    c.claim_amount_inr,
    r.fraud_risk_score,
    r.risk_level
FROM insurance_fraud_db.clean_claims c
JOIN insurance_fraud_db.fraud_risk_score r
    ON c.claim_id = r.claim_id
JOIN insurance_fraud_db.clean_customers cu
    ON c.customer_id = cu.customer_id
WHERE r.risk_level = 'High Risk'
ORDER BY c.claim_amount_inr DESC;


-- =========================================================
-- 16. HIGH-RISK CLAIMS BY RISK SCORE
-- =========================================================

SELECT
    fraud_risk_score,
    COUNT(DISTINCT claim_id) AS claim_count
FROM insurance_fraud_db.fraud_risk_score
WHERE risk_level = 'High Risk'
GROUP BY fraud_risk_score
ORDER BY fraud_risk_score DESC;


-- =========================================================
-- 17. FRAUD INVESTIGATION SUMMARY
-- =========================================================

SELECT
    investigation_status,
    COUNT(DISTINCT claim_id) AS claim_count
FROM insurance_fraud_db.clean_investigations
GROUP BY investigation_status
ORDER BY claim_count DESC;


-- =========================================================
-- 18. HIGH-RISK INVESTIGATION SUMMARY
-- =========================================================

SELECT
    fi.investigation_status,
    COUNT(DISTINCT fi.claim_id) AS high_risk_claim_count
FROM insurance_fraud_db.clean_investigations fi
JOIN insurance_fraud_db.fraud_risk_score r
    ON fi.claim_id = r.claim_id
WHERE r.risk_level = 'High Risk'
GROUP BY fi.investigation_status
ORDER BY high_risk_claim_count DESC;


