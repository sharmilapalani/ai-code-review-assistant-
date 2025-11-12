# Code Review Feedback for `pasted_code.sql`

## Description
AIP_G_CALLS_BASE_TBL is a table we have created, here base joins and where conditions are completed, this is the code for that
ALTER PROCEDURE [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL]
AS
BEGIN
    SET NOCOUNT ON;
    ------------------------------------------------------------
    -- 1. DELETE EXISTING DATA
    ------------------------------------------------------------
   DROP TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
   CREATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL (
    Account_Id VARCHAR(50),
    ID VARCHAR(50),
    Call_Id VARCHAR(50),
    STATUS_VOD__C VARCHAR(50),
    Call_Date DATE,
    Product_Name VARCHAR(100),
    STAFF_ONLY VARCHAR(10),
    INTERACTION_TYPE__C VARCHAR(100),
    CALL_TYPE_VOD__C VARCHAR(100),
    OWNERID VARCHAR(50),
    PARENT_CALL_VOD__C VARCHAR(50),
    RECORDTYPEID VARCHAR(50),
    OUTCOME VARCHAR(100),
    OUTCOME_DETAIL VARCHAR(100),
    CONTACT_ROLE VARCHAR(100),
    CALL_ATTEMPT_RESULT INT,
	IS_SAMPLE_CALL VARCHAR(10),
    PRSC_CID VARCHAR(50),
    Specialty VARCHAR(100),
    Acc_Prescriber VARCHAR(200),
    Acc_Account_Type VARCHAR(10),
    ACCT_TYP_CD_IV_GSK_CDE__C VARCHAR(50),
    PDRP_OPT_OUT_VOD__C VARCHAR(10),
    EMP_ID VARCHAR(50),
    TP_Date DATE,
    TP_Week DATE,
    TP_Week_Rank INT,
    TP_Month_str VARCHAR(20),
    TP_Month_Rank INT,
    TP_Year_str VARCHAR(10),
    TP_Year_Rank INT,
    TP_Quarter_str VARCHAR(10),
    TP_Quarter_Rank INT,
    TP_Date_Rank INT,
    tp_date_str VARCHAR(20),
    tp_week_str VARCHAR(20),
    TP_Quarter VARCHAR(10),
    weekend_flag VARCHAR(10),
    Team VARCHAR(20),
    BRAND_NAME VARCHAR(100),
    PRODUCT_CODE VARCHAR(50),
    GEO_NUMBER VARCHAR(50),
    Prescriber VARCHAR(200),
    Account_Type VARCHAR(10),
    Presentation_ID_vod__c VARCHAR(10),
    Successful_Call INT,
    Attempted_Call INT,
    TERRITORY_NAME VARCHAR(100),
    DISTRICT_NAME VARCHAR(100),
    REGION_NAME VARCHAR(100),
    POSITION_TITLE VARCHAR(100),
    REP_FLAG INT,
    Name VARCHAR(200),
    ASSIGNMENT_END_DATE DATE,
    Target_Flag INT,
    Segment VARCHAR(50),
    Detailed_Calls INT,
	CLM_Calls INT,
	Calls_Only INT,
	Successful_Target_Calls INT,
	Pharmacy_Calls INT,
	Target_Detail_Calls INT

);
WITH Interaction AS (
    SELECT 
        i.ACCOUNT_VOD__C AS Account_Id,
        i.ID,
        i.ID AS Call_Id,
        i.STATUS_VOD__C,
        CAST(i.CALL_DATE_VOD__C AS DATE) AS Call_Date,
        'Product-1' AS Product_Name,
        COALESCE(i.STAFF_ONLY, 'False') AS STAFF_ONLY,
        i.INTERACTION_TYPE__C,
        i.CALL_TYPE_VOD__C,
        i.OWNERID,
        i.PARENT_CALL_VOD__C,
        i.RECORDTYPEID,
        i.OUTCOME,
        i.OUTCOME_DETAIL,
        i.CONTACT_ROLE,
        i.CALL_ATTEMPT_RESULT,
        i.IS_SAMPLE_CALL,
        a.ID_VOD__C AS PRSC_CID,
        COALESCE(a.SPECIALTY_1_VOD__C, 'Unassigned') AS Specialty,
        a.NAME AS Acc_Prescriber,
        CASE WHEN a.ISPERSONACCOUNT = 'True' THEN 'HCP' ELSE 'HCO' END AS Acc_Account_Type,
        a.ACCT_TYP_CD_IV_GSK_CDE__C,
        a.PDRP_OPT_OUT_VOD__C,
        o.CAST_EMP_ID_IV_BASE__C AS EMP_ID
    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_ACTIVITY i
    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_USER_DETAILS o ON i.OWNERID = o.ID
    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_ACCOUNT_DETAILS a 
        ON i.ACCOUNT_VOD__C = a.ID AND a.COUNTRY_IV_GSK__C = 'US'
    WHERE i.STATUS_VOD__C = 'Submitted_vod'
      AND a.COUNTRY_IV_GSK__C = 'US'
      AND i.RECORDTYPEID IN (
            SELECT ID
            FROM AIP_FULL_COMMERCIAL.AIP_CRM_RECORDTYPE
            WHERE UPPER(NAME) LIKE '%RUKOBIA%'
      )
),
Universe AS (
    SELECT DISTINCT CID AS PRSC_CID, HCP_NAME AS Prescriber, 'HCP' AS Account_Type
    FROM AIP_FULL_COMMERCIAL.AIP_HCP_UNIVERSE
    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
    UNION ALL
    SELECT DISTINCT CID AS PRSC_CID, ACCOUNT_NAME AS Prescriber, 'HCO' AS Account_Type
    FROM AIP_FULL_COMMERCIAL.AIP_HCO_UNIVERSE
    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
),
Universe_base AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY PRSC_CID ORDER BY PRSC_CID) AS rn
    FROM Universe
),
UserHierarchyBase AS (
    SELECT 
        EMP_ID,
        GEO_NAME AS TERRITORY_NAME,
        ' ' AS DISTRICT_NAME,
        PARENT_GEO_NAME AS REGION_NAME,
        POSITION_TITLE,
        GEO_NUMBER,
        CAST(ASSIGNMENT_END_DATE AS DATE) AS ASSIGNMENT_END_DATE,
        REP_FLAG,
        TEAM,
        CASE
            WHEN ASSIGNMENT_END_DATE < GETDATE()
                AND (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
                THEN 'Vacant'
            ELSE FULL_NAME
        END AS Name
    FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT
    WHERE REP_FLAG = 1
),
UserHierarchy AS (
    SELECT * FROM UserHierarchyBase
    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
),
icva AS (
    SELECT DISTINCT CALL2_VOD__C, 'Yes' AS Presentation_ID_vod__c
    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_KEYMESSAGE
    WHERE CALL2_VOD__C IN (SELECT DISTINCT ID FROM Interaction)
),
Target AS (
    SELECT DISTINCT
        QTR_FY AS Qtr,
        ID AS Account_Id,
        TERRITORY AS GEO_NUMBER,
        1 AS Target_Flag,
        COALESCE(RUKOBIA_SEGMENT_IV_GSK_TELE__C, 'Non-Tier Targets') AS Segment
    FROM AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS
    WHERE ID IN (SELECT Account_Id FROM Interaction)
),
Base AS (
    SELECT 
        i.*,
        CAST(d.TP_Date AS DATE) AS TP_Date,
        d.TP_Week,
        d.TP_Week_Rank,
        d.TP_Month_str,
        d.TP_Month_Rank,
        d.TP_Year_str,
        d.TP_Year_Rank,
        d.TP_Quarter_str,
        d.TP_Quarter_Rank,
        d.TP_Date_Rank,
        d.tp_date_str,
        d.tp_week_str,
        d.TP_Quarter,
        d.weekend_flag,
        r.Team,
        p.BRAND_NAME,
        p.PRODUCT_CODE,
        uh.GEO_NUMBER,
        COALESCE(a.Prescriber, i.Acc_Prescriber) AS Prescriber,
        COALESCE(a.Account_Type, i.Acc_Account_Type) AS Account_Type,
        iv.Presentation_ID_vod__c,
        CASE WHEN i.CALL_TYPE_VOD__C LIKE '%Detail%' AND i.CALL_ATTEMPT_RESULT = 1 THEN 1 ELSE 0 END AS Successful_Call,
        CASE WHEN i.CALL_TYPE_VOD__C IS NOT NULL AND i.CALL_TYPE_VOD__C <> '' THEN 1 ELSE 0 END AS Attempted_Call
    FROM Interaction i
    LEFT JOIN AIP_FULL_COMMERCIAL.Dim_config_date d ON i.Call_Date = d.TP_Date
    LEFT JOIN AIP_FULL_COMMERCIAL.RECORD_TYPE r ON i.RECORDTYPEID = r.RECORDTYPEID
    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_PRODUCT_MASTER p ON i.Product_Name = p.BRAND_NAME
    LEFT JOIN UserHierarchyBase uh ON i.EMP_ID = uh.EMP_ID AND uh.POSITION_TITLE LIKE '%Representative%'
    LEFT JOIN Universe_base a ON i.PRSC_CID = a.PRSC_CID AND rn = 1
    LEFT JOIN icva iv ON i.Call_Id = iv.CALL2_VOD__C
),
Final AS (
    SELECT 
        i.*,
        COALESCE(u.TERRITORY_NAME, 'Unassigned') AS TERRITORY_NAME,
        u.DISTRICT_NAME,
        COALESCE(u.REGION_NAME, 'Unassigned') AS REGION_NAME,
        u.POSITION_TITLE,
        u.REP_FLAG,
        u.Name,
        u.ASSIGNMENT_END_DATE,
        t.Target_Flag,
        CASE
            WHEN t.Segment IS NOT NULL THEN t.Segment
            WHEN i.Team = 'Field' THEN 'Non-ECL'
            WHEN i.Team = 'EC' THEN 'Field Assist'
            ELSE NULL
        END AS Segment,
        CASE
            WHEN i.Account_Type = 'HCP' AND i.STAFF_ONLY = 'False' AND i.Team = 'Field' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
            WHEN i.Account_Type = 'HCO' OR i.Team = 'EC' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
            ELSE 0
            END AS Detailed_Calls,
        CASE
            WHEN i.Account_Type LIKE 'HCO' AND i.Call_Type_vod__c LIKE '%Call Only%' THEN 1 
			ELSE 0 
			END AS Calls_Only,
        CASE
            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type LIKE '%HCP%' THEN 1 
			ELSE 0 
			END AS CLM_Calls,
         CASE
            WHEN i.Account_Type LIKE 'HCP' AND i.Successful_Call = 1 AND t.Target_Flag = 1 THEN 1 
			ELSE 0 
			END AS Successful_Target_Calls,
		CASE
            WHEN i.ACCT_TYP_CD_iv_GSK_CDE__C LIKE '%PHRM%' THEN 1 
			ELSE 0 
			END AS Pharmacy_Calls,
		CASE
            WHEN i.Call_Type_vod__c LIKE '%Detail%' AND t.Target_Flag=1 THEN 1 
			ELSE 0 
			END AS Target_Detail_Calls
    FROM Base i
    LEFT JOIN UserHierarchy u ON i.GEO_NUMBER = u.GEO_NUMBER
    LEFT JOIN Target t ON i.TP_Quarter = t.Qtr AND i.Account_Id = t.Account_Id AND i.GEO_NUMBER = t.GEO_NUMBER
)
INSERT select * from  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
SELECT *
FROM Final;
END;
GO
Below is the logic for chart 
	
#Sample Calls  : Count distinct ID from the AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY. '#Smaple Calls" in #Sample Calls / Prescribers Sampled column  

HCPs Sampled by Segment :
Count of distinct ACCOUNT_VOD__C from AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True ,'Prescribers Sampled" in #Sample Calls / Prescribers Sampled column  for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY and HCP segment is derived from AIP_CRM_TARGET_LIST identified by AIP_CRM_CALL_ACTVITY  . ACCOUNT_VOD__C= AIP_CRM_TARGET_LIST .ACCOUNT_VOD__C and pull the column SEGMENT. Review this

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
**Strict SQL Code Review**

---

### 1) Corrected Code

**Corrected SQL:**

Below is the corrected code with SQL best practices, proper aliasing, and clarity. I have also added more precise comments and eliminated unnecessary line breaks.

```sql
WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True'
        -- Uncomment and adapt the following filters as needed:
        -- AND 
        -- (
        --      ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
        --   OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
        -- )
        -- AND (Product_Name = {{CDL_FA_PROD}} OR {{CDL_FA_PROD}} = 'ALL')
        -- AND (REGION_NAME = {{CDL_FA_REG}} OR {{CDL_FA_REG}} = 'ALL')
        -- AND (TERRITORY_NAME = {{CDL_FA_TERR}} OR {{CDL_FA_TERR}} = 'ALL')
        -- AND (Team = {{CDL_FA_TEAM}} OR {{CDL_FA_TEAM}} = 'ALL')
        -- AND (Segment = {{CDL_FA_SEG}} OR {{CDL_FA_SEG}} = 'ALL')
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

**No major logic or syntax corrections required for the provided SQL.**

---

### 2) Syntax Errors

- ✅ No syntax errors found.
- All clauses (WITH, SELECT, FROM, WHERE, GROUP BY, UNION ALL) are used correctly.
- Aliasing columns with `AS` in SELECT is acceptable and clear.

**NOTES:**  
The provided SQL is syntactically valid, assuming macros like `{{CDL_FA_PROD}}` are replaced properly by the calling/reporting layer.

---

### 3) Suggestions / Improvements

**a) Performance:**
- Ensure that `IS_SAMPLE_CALL` and `Segment` are indexed or that statistics are maintained on AIP_G_CALLS_BASE_TBL to support fast filtering and aggregation.
- Consider a filtered nonclustered index for rows where `IS_SAMPLE_CALL = 'True'` if this is a frequent/critical path.

**b) Filters and Commented Code:**
- Commented-out filters should be incorporated in a way that supports maintainability (e.g., add all filters and leave default placeholders for macros).
- Use parentheses correctly to avoid precedence issues if multiple filters are switched on.

**c) Readability:**
- Provide a clear comment block at the top stating input expectations (e.g., macro variables describe expected values/data types).
- Use consistent indentation.

**d) Edge Cases:**
- If Segment can be NULL, consider whether NULLs are allowed in the output or whether a COALESCE is needed (e.g., `COALESCE(Segment, 'Unassigned')`).

**e) Output Format:**
- Be aware: The result shape is "unpivoted" (i.e., two rows per Segment). For dashboard use, consider whether a wide format (one row per Segment, two columns for each metric) might be preferable in some cases.

**f) NULL Handling:**
- If the table contains rows where ID or Account_Id is NULL, those are counted separately in COUNT(DISTINCT ...). If that's not desired, you should add `AND ID IS NOT NULL` or `AND Account_Id IS NOT NULL` to your WHERE clause.

**g) Column Data Types:**
- Ensure ID and Account_Id are always of consistent datatype and match base table definition.

---

### 4) Requirement Mismatch

**Does the SQL satisfy the requirements as described?**

- **Requirement 1:**  
  "#Sample Calls: Count distinct ID from the AIP_CRM_CALL_ACTVITY where IS_SAMPLE_CALL = True, for selected Time period in the Dashboard, ... '#Sample Calls' in #Sample Calls / Prescribers Sampled column"  
  **Match:** The provided SQL counts `COUNT(DISTINCT ID)` as `sample_calls` for each Segment in AIP_G_CALLS_BASE_TBL filtered by `IS_SAMPLE_CALL = 'True'`, which appears to be consistent.
  - Slight ambiguity if `Segment` comes from the correct source (AIP_CRM_TARGET_LIST as in requirement 2), but given it's precomputed into AIP_G_CALLS_BASE_TBL, it's acceptable.

- **Requirement 2:**  
  "HCPs Sampled by Segment: Count of distinct ACCOUNT_VOD__C from AIP_CRM_CALL_ACTVITY where IS_SAMPLE_CALL = True, ... pull the column SEGMENT."  
  **Match:** The SQL counts `COUNT(DISTINCT Account_Id)` as `prescribers_sampled`. Assuming `Account_Id` maps to `ACCOUNT_VOD__C` (from your ETL/view/table logic), this is correct.

  - **Assumption**: SEGMENT is already materialized in AIP_G_CALLS_BASE_TBL, derived from the join described in your Data Mart logic.

- **Filter Handling**:  
  The SQL does **not currently** restrict time period, product, team, territory, region, or segment, as those filters are commented out. THIS COULD BE A PARTIAL REQUIREMENT MISMATCH if those filters are required for the dashboard; clarify if the dashboard tool is pushing those as parameters and uncomment code accordingly.

**Summary Judgment:**  
**✅ The core logic (for sample calls and prescribers sampled by segment) matches the requirement as long as the dashboard/reporting tool correctly manages additional filters with macro variables and the AIP_G_CALLS_BASE_TBL accurately reflects the ETL/join logic described. If commentary filters are not implemented, filter-based requirements are not fully met, but the table structure/logics are acceptable for the summary metric calculation.**

---

**If you want the result in a wide format, consider this:**

```sql
SELECT
    Segment,
    COUNT(DISTINCT CASE WHEN IS_SAMPLE_CALL = 'True' THEN ID END) AS [#Sample Calls],
    COUNT(DISTINCT CASE WHEN IS_SAMPLE_CALL = 'True' THEN Account_Id END) AS [Prescribers Sampled]
FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
GROUP BY Segment;
```

---

**Let me know if you need pivoted output or want to address commented conditions as active filters.**

## Git Blame
```
0000000000000000000000000000000000000000 1 1 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TPC}}
0000000000000000000000000000000000000000 2 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_STARTDATE}}
0000000000000000000000000000000000000000 3 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_ENDDATE}}
0000000000000000000000000000000000000000 4 4
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_CD_P_STARTDATE_HIDDEN}}
0000000000000000000000000000000000000000 5 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_PROD}}
0000000000000000000000000000000000000000 6 6
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_REG}}
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TERR}}
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TEAM}}
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_SEG}}
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 12 12 6
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	WITH base AS (
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 13 13
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    SELECT
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 14 14
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        Segment, 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 15 15
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        COUNT(DISTINCT ID) AS sample_calls,
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 16 16
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	        COUNT(DISTINCT Account_Id) AS prescribers_sampled
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 17 17
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
0000000000000000000000000000000000000000 18 18 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	    WHERE IS_SAMPLE_CALL = 'True' 
0000000000000000000000000000000000000000 19 19
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        AND 
0000000000000000000000000000000000000000 20 20
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
0000000000000000000000000000000000000000 21 21
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
0000000000000000000000000000000000000000 22 22
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        AND
0000000000000000000000000000000000000000 23 23
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
0000000000000000000000000000000000000000 24 24
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
0000000000000000000000000000000000000000 25 25
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
0000000000000000000000000000000000000000 26 26
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
0000000000000000000000000000000000000000 27 27
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 28 28 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    GROUP BY Segment
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 29 29
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	)
0000000000000000000000000000000000000000 30 30 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 31 31 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	SELECT 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 32 32
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    Segment,
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 33 33
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    '#Sample Calls' AS [#Sample Calls / Prescribers Sampled],
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 34 34
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    sample_calls AS [Calls / Prescriber]
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 35 35
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	FROM base
0000000000000000000000000000000000000000 36 36 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 37 37 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	UNION ALL
0000000000000000000000000000000000000000 38 38 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762931798
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762931798
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 39 39 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	SELECT 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 40 40
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    Segment,
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 41 41
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    'Prescribers Sampled' AS [#Sample Calls / Prescribers Sampled],
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 42 42
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	    prescribers_sampled AS [Calls / Prescriber]
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 43 43
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762848046
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762848046
committer-tz +0530
summary Code review for pasted_code.sql
previous 0bebcbcf95ef394824b7edfac94496e42111e0c9 pasted_code.sql
filename pasted_code.sql
	FROM base;
```
