# Code Review Feedback for `pasted_code.sql`

## Description
Please Validate my code based on Below JIRA, I have used stored procedure as well 
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
Missing filter logic for COUNTRY = 'Germany' and PROD = 'KIMMTRAK'. Add appropriate WHERE clauses to replicate the described logic.

```sql
WHERE COUNTRY = 'Germany' AND PROD = 'KIMMTRAK'
```

2) Errors  
Major error: Logic does NOT restrict data to Germany or to KIMMTRAK product; output will overstate sales units.

3) Quick Suggestions  
- Simplify CASE statements where possible for readability.
- Remove unnecessary UNION for distinct Geography; use GROUP BY for clarity.  
- Add explicit JOINs if data is spread across multiple tables for CRM model alignment.

## Git Blame
```
0000000000000000000000000000000000000000 1 1 52
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TPC}}
0000000000000000000000000000000000000000 2 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TPC_OVERTIME_HIDDEN}}
0000000000000000000000000000000000000000 3 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_STARTDATE_HIDDEN}}
0000000000000000000000000000000000000000 4 4
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ENDDATE_HIDDEN}}
0000000000000000000000000000000000000000 5 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_STARTDATE}}
0000000000000000000000000000000000000000 6 6
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ENDDATE}}
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TEAM}}
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_REG}}
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_TERR}}
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ROLE_PAR_GEO}}
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{CDL_FA_ROLE_GEO}}
0000000000000000000000000000000000000000 12 12
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	// -- {{FI_CDL_SCHEMA_NAME}}
0000000000000000000000000000000000000000 13 13
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 14 14
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	WITH 
0000000000000000000000000000000000000000 15 15
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 16 16
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	SALES AS (SELECT 
0000000000000000000000000000000000000000 17 17
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{CDL_FA_ROLE_PAR_GEO}} AS Parent,
0000000000000000000000000000000000000000 18 18
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{CDL_FA_ROLE_GEO}} as Child,
0000000000000000000000000000000000000000 19 19
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	 SUM(Sales) AS Sales,
0000000000000000000000000000000000000000 20 20
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        CASE 
0000000000000000000000000000000000000000 21 21
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_REG}}') > 0 THEN REG
0000000000000000000000000000000000000000 22 22
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_TERR}}') > 0 THEN 1
0000000000000000000000000000000000000000 23 23
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            ELSE NAT
0000000000000000000000000000000000000000 24 24
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        END AS ROLE_PARENT,
0000000000000000000000000000000000000000 25 25
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        CASE 
0000000000000000000000000000000000000000 26 26
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            WHEN LEN('{{CDL_FA_REG}}') > 0 OR LEN('{{CDL_FA_TERR}}') > 0 THEN 1
0000000000000000000000000000000000000000 27 27
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	            ELSE REG
0000000000000000000000000000000000000000 28 28
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        END AS ROLE_CHILD
0000000000000000000000000000000000000000 29 29
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	FROM EUROPE_FIELD_INTELLIGENCE.AIP_G_SALES_BASE
0000000000000000000000000000000000000000 30 30
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	WHERE (
0000000000000000000000000000000000000000 31 31
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{G_FI_CDL_TIMEPERIOD}}
0000000000000000000000000000000000000000 32 32
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	{{G_FI_CDL_ALL_FILTERS}}
0000000000000000000000000000000000000000 33 33
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	           ) 
0000000000000000000000000000000000000000 34 34
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    GROUP BY {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}}, nat,reg
0000000000000000000000000000000000000000 35 35
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 36 36
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 37 37
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	FINAL AS (
0000000000000000000000000000000000000000 38 38
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    SELECT
0000000000000000000000000000000000000000 39 39
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        S.Parent AS Geography,
0000000000000000000000000000000000000000 40 40
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        SUM(S.Sales) AS Units
0000000000000000000000000000000000000000 41 41
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    FROM SALES S
0000000000000000000000000000000000000000 42 42
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    WHERE S.ROLE_PARENT = 1
0000000000000000000000000000000000000000 43 43
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    GROUP BY S.Parent
0000000000000000000000000000000000000000 44 44
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 45 45
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    UNION
0000000000000000000000000000000000000000 46 46
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 47 47
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    SELECT
0000000000000000000000000000000000000000 48 48
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        S.Child AS Geography,
0000000000000000000000000000000000000000 49 49
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	        SUM(S.Sales) AS Units
0000000000000000000000000000000000000000 50 50
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    FROM SALES S
0000000000000000000000000000000000000000 51 51
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	    WHERE S.ROLE_CHILD = 1
0000000000000000000000000000000000000000 52 52
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 54 54 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 55 55
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1768317452
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1768317452
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 1632917db53336b13358985e002c546d160e996d pasted_code.sql
filename pasted_code.sql
	SELECT Geography AS {{CDL_FA_REGION_TITLE_CHG}},Units FROM FINAL;
```
