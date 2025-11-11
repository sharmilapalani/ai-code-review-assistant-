# Code Review Feedback for `pasted_code.sql`

## Description
there are few parameters used for dashboard interactivty pls ignore that

Sample Calls  : Count distinct ID from the AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY.

HCPs Sampled by Segment :

Count of distinct ACCOUNT_VOD__C from AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY and HCP segment is derived from AIP_CRM_TARGET_LIST identified by AIP_CRM_CALL_ACTVITY  . ACCOUNT_VOD__C= AIP_CRM_TARGET_LIST .ACCOUNT_VOD__C and pull the column SEGMENT

## Uploaded Code
```sql
-- // {{CDL_FA_TPC}}
-- // {{CDL_FA_STARTDATE}}
-- // {{CDL_FA_ENDDATE}}
-- // {{CDL_CD_P_STARTDATE_HIDDEN}}
-- // {{CDL_FA_PROD}}
-- // {{CDL_FA_REG}}
-- // {{CDL_FA_TERR}}
-- // {{CDL_FA_TEAM}}
-- // {{CDL_FA_SEG}}
 
 
WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True' 
--        AND 
--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
--        AND
--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
--?        ,(Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
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
```

## CDL Execution Summary
✅ Execution succeeded. Sample rows:
Segment | #Sample Calls / Prescribers Sampled | Calls / Prescriber
--------|-------------------------------------|-------------------
Tier 3 | #Sample Calls | 1204
Direct Competitor Writer | #Sample Calls | 8
Non-ECL | #Sample Calls | 3469
Non-Tier Targets | #Sample Calls | 845
Tier 2 | #Sample Calls | 444
Tier 3 | Prescribers Sampled | 290
Tier 1 | #Sample Calls | 388
Non-ECL | Prescribers Sampled | 1001
Non-Tier Targets | Prescribers Sampled | 266
Tier 2 | Prescribers Sampled | 87
...plus 2 more rows (sample truncated).

## Sample Rows
```
Segment | #Sample Calls / Prescribers Sampled | Calls / Prescriber
--------|-------------------------------------|-------------------
Tier 3 | #Sample Calls | 1204
Direct Competitor Writer | #Sample Calls | 8
Non-ECL | #Sample Calls | 3469
Non-Tier Targets | #Sample Calls | 845
Tier 2 | #Sample Calls | 444
Tier 3 | Prescribers Sampled | 290
Tier 1 | #Sample Calls | 388
Non-ECL | Prescribers Sampled | 1001
Non-Tier Targets | Prescribers Sampled | 266
Tier 2 | Prescribers Sampled | 87
...plus 2 more rows (sample truncated).
```

## AI Feedback
1) Corrected Code

The provided SQL has issues matching the requirements:

- The main source table in the requirements is AIP_CRM_CALL_ACTVITY, but the SQL uses AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL.
- SEGMENT is required from AIP_CRM_TARGET_LIST, joined via ACCOUNT_VOD__C. (SEGMENT is referenced as ‘Segment’ in the SQL, but the join is not visible.)
- The filters on CALL_DATE and IS_SAMPLE_CALL should be based on the columns as named in the description.
- The requirements are for two independent metrics: one for Sample Calls (COUNT DISTINCT ID) and one for HCPs Sampled by Segment (COUNT DISTINCT ACCOUNT_VOD__C BY SEGMENT).

Corrected SQL to precisely reflect the requirements:

```sql
-- Assumptions:
-- - Parameters are injected or handled by dashboard (CALL_DATE_VOD__C range)
-- - Boolean values stored as TRUE (not 'True') in IS_SAMPLE_CALL
-- - Replace placeholder {start_date}, {end_date} with actual dashboard parameter bindings

-- Sample Calls: COUNT DISTINCT ID
SELECT 
    'All' AS Segment,
    '#Sample Calls' AS [#Sample Calls / Prescribers Sampled],
    COUNT(DISTINCT ID) AS [Calls / Prescriber]
FROM AIP_CRM_CALL_ACTVITY
WHERE IS_SAMPLE_CALL = TRUE
  AND CALL_DATE_VOD__C BETWEEN {start_date} AND {end_date}

UNION ALL

-- HCPs Sampled by Segment: COUNT DISTINCT ACCOUNT_VOD__C BY SEGMENT
SELECT 
    TL.SEGMENT AS Segment,
    'Prescribers Sampled' AS [#Sample Calls / Prescribers Sampled],
    COUNT(DISTINCT CA.ACCOUNT_VOD__C) AS [Calls / Prescriber]
FROM AIP_CRM_CALL_ACTVITY CA
JOIN AIP_CRM_TARGET_LIST TL 
    ON CA.ACCOUNT_VOD__C = TL.ACCOUNT_VOD__C
WHERE CA.IS_SAMPLE_CALL = TRUE
  AND CA.CALL_DATE_VOD__C BETWEEN {start_date} AND {end_date}
GROUP BY TL.SEGMENT
```

**Key Corrections:**
- Use the correct tables/column names per requirement.
- Explicitly join the TARGET_LIST table for SEGMENT.
- Compute overall sample calls as one line, HCPs sampled grouped by segment.

---

2) Syntax Errors

- ✅ No syntax errors found in the original SQL for its own structure, but see above for logic/semantic issues.

---

3) Suggestions / Improvements

- **Source Table Consistency:** Use the correct table as per business logic (AIP_CRM_CALL_ACTVITY, not a summary/mart unless validated).
- **Explicit Join for Segment:** Segment is derived from target list, not the base call table.
- **Parameterization:** Use parameter binding for time window, not SQL comments.
- **Column Typing:** If IS_SAMPLE_CALL is boolean, use IS_SAMPLE_CALL = TRUE (not 'True'), otherwise stick with string literal if the datatype is text (i.e., 'True').
- **Indexing:** Make sure there are indexes on IS_SAMPLE_CALL, CALL_DATE_VOD__C, ACCOUNT_VOD__C; and TL.ACCOUNT_VOD__C for join performance.
- **Readability:** Use meaningful column aliases and structure for clarity.
- **Edge Cases:** Ensure all sampled accounts in CA actually exist in TL. Will any be missing? LEFT JOIN if needed, but requirements indicate only those present in the target list.
- **Dashboard Filtering:** Comments indicate possible dashboard parameters on region, territory, etc. Add those as needed for further filtering.

---

4) Requirement Mismatch

- ❌ The provided SQL does **not** fully satisfy the Description:
    - It uses a different, possibly pre-aggregated/table (AIP_G_CALLS_BASE_TBL) not referenced in the requirements.
    - Does **not** join AIP_CRM_TARGET_LIST to derive SEGMENT for accounts, which is required.
    - Uses generic columns (Segment, Account_Id) instead of explicit mapping to underlying business table/column names.
    - Lumps both metrics into a single CTE, splitting only on the second SELECT, instead of separating out “Sample Calls” as a total distinct count and “HCP Sampled by Segment” as a grouped count.
    - Does not clearly allow "Sample Calls" overall (without segment), only by segment.

**Conclusion:** The provided SQL does not implement the business requirements as described. Use the corrected code above as a template and ensure source tables/column names and joins are consistent with requirements.

## Git Blame
```
0000000000000000000000000000000000000000 1 1 43
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TPC}}
0000000000000000000000000000000000000000 2 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_STARTDATE}}
0000000000000000000000000000000000000000 3 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_ENDDATE}}
0000000000000000000000000000000000000000 4 4
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_CD_P_STARTDATE_HIDDEN}}
0000000000000000000000000000000000000000 5 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_PROD}}
0000000000000000000000000000000000000000 6 6
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_REG}}
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TERR}}
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TEAM}}
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_SEG}}
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 12 12
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	WITH base AS (
0000000000000000000000000000000000000000 13 13
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    SELECT
0000000000000000000000000000000000000000 14 14
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        Segment, 
0000000000000000000000000000000000000000 15 15
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        COUNT(DISTINCT ID) AS sample_calls,
0000000000000000000000000000000000000000 16 16
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        COUNT(DISTINCT Account_Id) AS prescribers_sampled
0000000000000000000000000000000000000000 17 17
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
0000000000000000000000000000000000000000 18 18
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    WHERE IS_SAMPLE_CALL = 'True' 
0000000000000000000000000000000000000000 19 19
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--        AND 
0000000000000000000000000000000000000000 20 20
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
0000000000000000000000000000000000000000 21 21
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
0000000000000000000000000000000000000000 22 22
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--        AND
0000000000000000000000000000000000000000 23 23
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
0000000000000000000000000000000000000000 24 24
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
0000000000000000000000000000000000000000 25 25
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
0000000000000000000000000000000000000000 26 26
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
0000000000000000000000000000000000000000 27 27
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	--?        ,(Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
0000000000000000000000000000000000000000 28 28
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    GROUP BY Segment
0000000000000000000000000000000000000000 29 29
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	)
0000000000000000000000000000000000000000 30 30
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 31 31
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	SELECT 
0000000000000000000000000000000000000000 32 32
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    Segment,
0000000000000000000000000000000000000000 33 33
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    '#Sample Calls' AS [#Sample Calls / Prescribers Sampled],
0000000000000000000000000000000000000000 34 34
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    sample_calls AS [Calls / Prescriber]
0000000000000000000000000000000000000000 35 35
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	FROM base
0000000000000000000000000000000000000000 36 36
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 37 37
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	UNION ALL
0000000000000000000000000000000000000000 38 38
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 39 39
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	SELECT 
0000000000000000000000000000000000000000 40 40
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    Segment,
0000000000000000000000000000000000000000 41 41
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    'Prescribers Sampled' AS [#Sample Calls / Prescribers Sampled],
0000000000000000000000000000000000000000 42 42
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    prescribers_sampled AS [Calls / Prescriber]
0000000000000000000000000000000000000000 43 43
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762848046
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762848046
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	FROM base;
```
