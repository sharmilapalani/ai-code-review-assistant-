// -- {{CDL_FA_TPC}}
// -- {{CDL_FA_TPC_OVERTIME_HIDDEN}}
// -- {{CDL_FA_STARTDATE_HIDDEN}}
// -- {{CDL_FA_ENDDATE_HIDDEN}}
// -- {{CDL_FA_STARTDATE}}
// -- {{CDL_FA_ENDDATE}}
// -- {{CDL_FA_TEAM}}
// -- {{CDL_FA_REG}}
// -- {{CDL_FA_TERR}}
// -- {{CDL_FA_ROLE_PAR_GEO}}
// -- {{CDL_FA_ROLE_GEO}}
// -- {{FI_CDL_SCHEMA_NAME}}

WITH 

SALES AS (SELECT 
{{CDL_FA_ROLE_PAR_GEO}} AS Parent,
{{CDL_FA_ROLE_GEO}} as Child,
 SUM(Sales) AS Sales,
        CASE 
            WHEN LEN('{{CDL_FA_REG}}') > 0 THEN REG
            WHEN LEN('{{CDL_FA_TERR}}') > 0 THEN 1
            ELSE NAT
        END AS ROLE_PARENT,
        CASE 
            WHEN LEN('{{CDL_FA_REG}}') > 0 OR LEN('{{CDL_FA_TERR}}') > 0 THEN 1
            ELSE REG
        END AS ROLE_CHILD
FROM EUROPE_FIELD_INTELLIGENCE.AIP_G_SALES_BASE
WHERE (
{{G_FI_CDL_TIMEPERIOD}}
{{G_FI_CDL_ALL_FILTERS}}
           ) 
    GROUP BY {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}}, nat,reg
),

FINAL AS (
    SELECT
        S.Parent AS Geography,
        SUM(S.Sales) AS Units
    FROM SALES S
    WHERE S.ROLE_PARENT = 1
    GROUP BY S.Parent

    UNION

    SELECT
        S.Child AS Geography,
        SUM(S.Sales) AS Units
    FROM SALES S
    WHERE S.ROLE_CHILD = 1
    GROUP BY S.Child
)

SELECT Geography AS {{CDL_FA_REGION_TITLE_CHG}},Units FROM FINAL;