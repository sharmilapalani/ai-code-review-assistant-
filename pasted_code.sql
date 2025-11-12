WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True'
      AND (
            (
                {{CDL_FA_TPC}} <> 'Custom'
                AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}}
            )
            OR (
                {{CDL_FA_TPC}} = 'Custom'
                AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}
            )
        )
      AND ({{CDL_FA_PROD}} = 'ALL' OR Product_Name = {{CDL_FA_PROD}})
      AND ({{CDL_FA_REG}} = 'ALL' OR REGION_NAME = {{CDL_FA_REG}})
      AND ({{CDL_FA_TERR}} = 'ALL' OR TERRITORY_NAME = {{CDL_FA_TERR}})
      AND ({{CDL_FA_TEAM}} = 'ALL' OR Team = {{CDL_FA_TEAM}})
      AND ({{CDL_FA_SEG}} = 'ALL' OR Segment = {{CDL_FA_SEG}})
    GROUP BY Segment
)
SELECT 
    Segment,
    '#Sample Calls' AS [#Sample Calls / Prescribers Sampled],
    sample_calls AS [Calls / Prescriber]
FROM base
UNION ALL
SELECT 
    Segment,
    'Prescribers Sampled' AS [#Sample Calls / Prescribers Sampled],
    prescribers_sampled AS [Calls / Prescriber]
FROM base;