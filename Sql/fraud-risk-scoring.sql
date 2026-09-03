


WITH claim_avg AS (
    SELECT
        claim_type,
        AVG(claim_amount_inr) AS avg_claim_amount
    FROM insurance_fraud_db.clean_claims
    GROUP BY claim_type
),

customer_claims AS (
    SELECT
        customer_id,
        COUNT(*) AS claim_count
    FROM insurance_fraud_db.clean_claims
    GROUP BY customer_id
),

small_claims AS (
    SELECT
        c.customer_id,
        COUNT(*) AS small_claim_count
    FROM insurance_fraud_db.clean_claims c
    JOIN claim_avg a
        ON c.claim_type = a.claim_type
    WHERE c.claim_amount_inr < 0.25 * a.avg_claim_amount
    GROUP BY c.customer_id
),

duplicate_claims AS (
    SELECT
        customer_id,
        incident_date,
        claim_type,
        COUNT(*) AS duplicate_count
    FROM insurance_fraud_db.clean_claims
    GROUP BY
        customer_id,
        incident_date,
        claim_type
    HAVING COUNT(*) > 1
),

investigation_risk AS (
    SELECT
        claim_id,
        MAX(
            CASE
                WHEN TRIM(investigation_status) = 'Closed - Fraud'
                    THEN 3
                WHEN TRIM(investigation_status) = 'Escalated'
                    THEN 2
                ELSE 0
            END
        ) AS investigation_score
    FROM insurance_fraud_db.clean_investigations
    GROUP BY claim_id
),

fraud_scores AS (
    SELECT
        c.claim_id,
        c.customer_id,
        c.policy_id,
        c.claim_type,
        c.claim_amount_inr,
        c.approved_amount_inr,

        CASE
            WHEN c.claim_amount_inr > 3 * a.avg_claim_amount
                THEN 1
            ELSE 0
        END AS high_amount_score,

        CASE
            WHEN cc.claim_count > 1
                THEN 1
            ELSE 0
        END AS multiple_claim_score,

        CASE
            WHEN sc.small_claim_count >= 3
             AND c.claim_amount_inr < 0.25 * a.avg_claim_amount
                THEN 1
            ELSE 0
        END AS frequent_small_claim_score,

        CASE
            WHEN d.customer_id IS NOT NULL
                THEN 2
            ELSE 0
        END AS duplicate_claim_score,

        CASE
            WHEN date_diff(
                'day',
                p.original_policy_start_date,
                c.incident_date
            ) BETWEEN 0 AND 30
                THEN 1
            ELSE 0
        END AS early_claim_score,

        CASE
            WHEN c.approved_amount_inr <
                 c.claim_amount_inr * 0.25
                THEN 1
            ELSE 0
        END AS approval_discrepancy_score,

        COALESCE(ir.investigation_score, 0)
            AS investigation_score

    FROM insurance_fraud_db.clean_claims c

    LEFT JOIN claim_avg a
        ON c.claim_type = a.claim_type

    LEFT JOIN customer_claims cc
        ON c.customer_id = cc.customer_id

    LEFT JOIN small_claims sc
        ON c.customer_id = sc.customer_id

    LEFT JOIN duplicate_claims d
        ON c.customer_id = d.customer_id
       AND c.incident_date = d.incident_date
       AND c.claim_type = d.claim_type

    LEFT JOIN insurance_fraud_db.clean_policies p
        ON c.policy_id = p.policy_id

    LEFT JOIN investigation_risk ir
        ON c.claim_id = ir.claim_id
),

scored_claims AS (
    SELECT
        *,
        (
            high_amount_score
            + multiple_claim_score
            + frequent_small_claim_score
            + duplicate_claim_score
            + early_claim_score
            + approval_discrepancy_score
            + investigation_score
        ) AS fraud_risk_score
    FROM fraud_scores
),

risk_levels AS (
    SELECT
        *,
        CASE
            WHEN fraud_risk_score >= 6
                THEN 'High Risk'
            WHEN fraud_risk_score >= 3
                THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_level
    FROM scored_claims
)

SELECT
    risk_level,
    COUNT(*) AS claim_count
FROM risk_levels
GROUP BY risk_level
ORDER BY
    CASE
        WHEN risk_level = 'High Risk' THEN 1
        WHEN risk_level = 'Medium Risk' THEN 2
        ELSE 3
    END;
