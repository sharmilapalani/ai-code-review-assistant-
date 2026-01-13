# Code Review Feedback for `pasted_code.sql`

## Description
Please Validate my code based on Below JIRA, I have used stored procedure as well chk for that code EUROPE_FIELD_INTELLIGENCE.SPLoad_AIP_G_SALES_BASE, global parameters {{G_FI_CDL_TIMEPERIOD}}
{{G_FI_CDL_ALL_FILTERS}} will check for all the Product, Country and Time Period selected in the dashboard
Total Sales Volume (Units):

SELECT
    SUM(a.NRTL_UNITS) AS TOTAL_UNITS,
    b.Country,
FROM AIP_NON_RETAIL_SALES a
INNER JOIN AIP_ACCOUNT_DETAILS b
    ON a.CID = b.ID
INNER JOIN AIP_HCO_UNIVERSE c
    ON b.ID = c.CID
WHERE a.COUNTRY = 'Germany'
  AND a.PROD = 'KIMMTRAK'
GROUP BY
    b.COUNTRY;

## Uploaded Code
```sql
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
```

## CDL Execution Summary
⚠️ Execution error: ('42000', '[42000] [Microsoft][ODBC Driver 17 for SQL Server]Syntax error, permission violation, or other nonspecific error (0) (SQLExecDirectW)')

## AI Feedback
1) Corrections  
Change all references from SUM(Sales) to SUM(NRTL_UNITS). Update the FROM clause to join EUROPE_FIELD_INTELLIGENCE.AIP_G_SALES_BASE with AIP_ACCOUNT_DETAILS and AIP_HCO_UNIVERSE on CID and ID, as per the logic in the description. Apply filters for Country = 'Germany' and PROD = 'KIMMTRAK'. Example:

```sql
SELECT
    SUM(a.NRTL_UNITS) AS TOTAL_UNITS,
    b.COUNTRY
FROM EUROPE_FIELD_INTELLIGENCE.AIP_G_SALES_BASE a
JOIN AIP_ACCOUNT_DETAILS b ON a.CID = b.ID
JOIN AIP_HCO_UNIVERSE c ON b.ID = c.CID
WHERE a.COUNTRY = 'Germany'
  AND a.PROD = 'KIMMTRAK'
GROUP BY b.COUNTRY
```

2) Errors  
Major logic mismatch: You are summing "Sales" instead of "NRTL_UNITS" and missing required joins and filters for COUNTRY and PROD.

3) Quick Suggestions  
- Use explicit JOINs for clarity and accuracy.
- Match the filter fields and aggregation exactly as described.
- Remove redundant or unclear CASE statements from the CTE for better readability.

## Git Blame
```
3dd3c9acea7078bb9723fd1754c9e45743969b27 1 1 52
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TPC}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 2 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TPC_OVERTIME_HIDDEN}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 3 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_STARTDATE_HIDDEN}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 4 4
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ENDDATE_HIDDEN}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 5 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_STARTDATE}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 6 6
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ENDDATE}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 7 7
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TEAM}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 8 8
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_REG}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 9 9
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TERR}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 10 10
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ROLE_PAR_GEO}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 11 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ROLE_GEO}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 12 12
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{FI_CDL_SCHEMA_NAME}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 13 13
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 14 14
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	WITH 
3dd3c9acea7078bb9723fd1754c9e45743969b27 15 15
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 16 16
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	SALES AS (SELECT 
3dd3c9acea7078bb9723fd1754c9e45743969b27 17 17
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{CDL_FA_ROLE_PAR_GEO}} AS Parent,
3dd3c9acea7078bb9723fd1754c9e45743969b27 18 18
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{CDL_FA_ROLE_GEO}} as Child,
3dd3c9acea7078bb9723fd1754c9e45743969b27 19 19
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	 SUM(Sales) AS Sales,
3dd3c9acea7078bb9723fd1754c9e45743969b27 20 20
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        CASE 
3dd3c9acea7078bb9723fd1754c9e45743969b27 21 21
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_REG}}') > 0 THEN REG
3dd3c9acea7078bb9723fd1754c9e45743969b27 22 22
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_TERR}}') > 0 THEN 1
3dd3c9acea7078bb9723fd1754c9e45743969b27 23 23
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            ELSE NAT
3dd3c9acea7078bb9723fd1754c9e45743969b27 24 24
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        END AS ROLE_PARENT,
3dd3c9acea7078bb9723fd1754c9e45743969b27 25 25
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        CASE 
3dd3c9acea7078bb9723fd1754c9e45743969b27 26 26
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_REG}}') > 0 OR LEN('{{CDL_FA_TERR}}') > 0 THEN 1
3dd3c9acea7078bb9723fd1754c9e45743969b27 27 27
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            ELSE REG
3dd3c9acea7078bb9723fd1754c9e45743969b27 28 28
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        END AS ROLE_CHILD
3dd3c9acea7078bb9723fd1754c9e45743969b27 29 29
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	FROM EUROPE_FIELD_INTELLIGENCE.AIP_G_SALES_BASE
3dd3c9acea7078bb9723fd1754c9e45743969b27 30 30
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	WHERE (
3dd3c9acea7078bb9723fd1754c9e45743969b27 31 31
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{G_FI_CDL_TIMEPERIOD}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 32 32
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{G_FI_CDL_ALL_FILTERS}}
3dd3c9acea7078bb9723fd1754c9e45743969b27 33 33
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	           ) 
3dd3c9acea7078bb9723fd1754c9e45743969b27 34 34
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    GROUP BY {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}}, nat,reg
3dd3c9acea7078bb9723fd1754c9e45743969b27 35 35
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	),
3dd3c9acea7078bb9723fd1754c9e45743969b27 36 36
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 37 37
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	FINAL AS (
3dd3c9acea7078bb9723fd1754c9e45743969b27 38 38
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    SELECT
3dd3c9acea7078bb9723fd1754c9e45743969b27 39 39
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        S.Parent AS Geography,
3dd3c9acea7078bb9723fd1754c9e45743969b27 40 40
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        SUM(S.Sales) AS Units
3dd3c9acea7078bb9723fd1754c9e45743969b27 41 41
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    FROM SALES S
3dd3c9acea7078bb9723fd1754c9e45743969b27 42 42
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    WHERE S.ROLE_PARENT = 1
3dd3c9acea7078bb9723fd1754c9e45743969b27 43 43
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    GROUP BY S.Parent
3dd3c9acea7078bb9723fd1754c9e45743969b27 44 44
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 45 45
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    UNION
3dd3c9acea7078bb9723fd1754c9e45743969b27 46 46
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 47 47
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    SELECT
3dd3c9acea7078bb9723fd1754c9e45743969b27 48 48
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        S.Child AS Geography,
3dd3c9acea7078bb9723fd1754c9e45743969b27 49 49
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        SUM(S.Sales) AS Units
3dd3c9acea7078bb9723fd1754c9e45743969b27 50 50
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    FROM SALES S
3dd3c9acea7078bb9723fd1754c9e45743969b27 51 51
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    WHERE S.ROLE_CHILD = 1
3dd3c9acea7078bb9723fd1754c9e45743969b27 52 52
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    GROUP BY S.Child
7ae1788762b98e1f9f095fd37718b6ba6deb90da 246 53 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	)
3dd3c9acea7078bb9723fd1754c9e45743969b27 54 54 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
3dd3c9acea7078bb9723fd1754c9e45743969b27 55 55
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1768317452
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1768317452
committer-tz +0530
summary Code review for pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	SELECT Geography AS {{CDL_FA_REGION_TITLE_CHG}},Units FROM FINAL;
```
