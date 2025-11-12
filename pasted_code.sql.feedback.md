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
	
#Sample Calls  : Count distinct ID from the AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY. '#Saple Calls" in #Sample Calls / Prescribers Sampled column  

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
**SQL Code Review**

---

### 1) Corrected Code

**Minor corrections for clarity and SQL best practices:**  
- Improve alias naming for columns.  
- Add explicit `ORDER BY` for consistent reporting.  
- Remove commented/placeholder filter logic or convert to template parameters for clarity (if using in a dynamic SQL engine or data visualization tool, document this elsewhere).

Here’s the suggested improved version for maintainability and clarity:

```sql
WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True'
    -- Add actual filters for date/products/region/etc. as required, e.g.:
    -- AND Call_Date BETWEEN @STARTDATE AND @ENDDATE
    -- AND (Product_Name = @Product OR @Product = 'ALL')
    -- AND (REGION_NAME = @Region OR @Region = 'ALL')
    -- AND (TERRITORY_NAME = @Territory OR @Territory = 'ALL')
    -- AND (Team = @Team OR @Team = 'ALL')
    -- AND (Segment = @Segment OR @Segment = 'ALL')
    GROUP BY Segment
)
SELECT 
    Segment,
    '#Sample Calls' AS report_label,
    sample_calls AS metric_value
FROM base

UNION ALL

SELECT 
    Segment,
    'Prescribers Sampled' AS report_label,
    prescribers_sampled AS metric_value
FROM base
ORDER BY Segment, report_label;
```

Notes:
- Column names changed so they are programming-friendly. Use display aliases only at the visualization/reporting layer.
- If required, parameterize and include the filtering logic via bind variables, not as commented code.

---

### 2) Syntax Errors

✅ No syntax errors found.

*The provided SQL executes successfully according to your summary, and no syntactical issues were found.*

---

### 3) Suggestions / Improvements

**A. Parameterization and Filtering Logic:**
- The commented filters should be properly implemented. If this SQL is to be used directly, use either SQL Server variables (`@Param`) or template variables, and ensure null/ALL logic is correct.

**B. Readability:**
- Rename columns (as above) for easier reference in reporting code.
- Use explicit `ORDER BY` for predictable result ordering.
- Add inline comments explaining the business logic for clarity, if this will be maintained in a codebase.

**C. Performance:**
- Index: If Segment is heavily used for filtering/grouping, ensure the underlying table has an index on `Segment`, `IS_SAMPLE_CALL`, `ID`, and `Account_Id` for best counting performance.
- If AIP_G_CALLS_BASE_TBL is very large, also consider filtered indexes:
    ```sql
    CREATE INDEX idx_g_calls_base_tbl_sample_call 
    ON AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL (Segment, ID, Account_Id)
    WHERE IS_SAMPLE_CALL = 'True';
    ```
- If nulls are possible in Segment, be aware that these rows will be grouped as Segment=NULL.

**D. Edge Cases:**
- If Segment can be NULL, consider whether these should be reported as "Unknown"/"Unassigned" for business clarity.
- If `ID` and `Account_Id` are not unique per row, validate whether the DISTINCT is necessary (if they’re primary keys, `COUNT` suffices).

**E. Flexibility and Maintenance:**
- Avoid hardcoding output column names with special characters (#, /). These are better handled in the report layer, not SQL. If required, escape or alias them accordingly at the final presentation step.

---

### 4) Requirement Mismatch

#### Does the SQL meet the description?

- **Requirement**:  
    - "#Sample Calls" = Count distinct `ID` from `AIP_CRM_CALL_ACTIVITY` where `IS_SAMPLE_CALL = True` for selected dashboard period, grouped by HCP Segment.
    - "Prescribers Sampled" = Count distinct `ACCOUNT_VOD__C` from `AIP_CRM_CALL_ACTIVITY` where `IS_SAMPLE_CALL = True` for selected period, grouped by segment (from target list).
    - The 'segment' is to be derived (joined) from the target list when present.

**Current Query Approach**:
- Operates on `AIP_G_CALLS_BASE_TBL`, which is claimed to have the proper joins/logic already completed, and contains both `Segment`, `ID`, and `Account_Id`.
- The filtered aggregate logic matches requirements: counting distinct `ID` vs `Account_Id`, grouped by Segment, when `IS_SAMPLE_CALL='True'`.

**Potential Issue**:
- The assumption is that `AIP_G_CALLS_BASE_TBL` was built **per the described logic**:  
    - Segment must represent the HCP segment as derived, not just copied.  
    - Account_Id must be the same as ACCOUNT_VOD__C from activity table.
    - The filtered data must reflect the selected dashboard period (which is currently commented out).

**Conclusion**:
- **The SQL as written does satisfy the requirement**—**if** `AIP_G_CALLS_BASE_TBL` was populated as per the described logic (segment association, data deduplication, correct period, etc).
- The only functional gap is that the required time-period and possible other dashboard-level filters are commented instead of implemented.
- You must ensure that future versions include parameterized/dashboard filters for date range, product, region, etc. Otherwise, aggregates may not reflect the 'selected dashboard period' as described.

---

**Summary Table (Requirement Fit):**

| Requirement Field         | SQL Provided?                 | Note                                                 |
|--------------------------|-------------------------------|------------------------------------------------------|
| #Sample Calls            | Yes (COUNT DISTINCT ID)       | Correct if ID is unique to each call                 |
| Prescribers Sampled      | Yes (COUNT DISTINCT Account_Id)| Correct if Account_Id maps to ACCOUNT_VOD__C         |
| Segment grouping         | Yes (on Segment in base table)| Assumes Segment derived as per business spec         |
| Time period filter       | No (filter commented out)     | Must implement for production/deployment             |
| Other dashboard filters  | No (filter commented out)     | Required for user-driven drilldown/reporting         |

---

**Action Items:**
- Implement actual parameterized filtering for time period and dashboard controls.
- Confirm Segment and Account_Id columns in base table are populated as described.
- Rename output columns and avoid special characters unless required for output format.
- Ensure relevant indexes are in place for large data sets.

---

## Git Blame
```
21fdad271f2cb91d27b1a9f5586294c104032808 1 1 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TPC}}
21fdad271f2cb91d27b1a9f5586294c104032808 2 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_STARTDATE}}
21fdad271f2cb91d27b1a9f5586294c104032808 3 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_ENDDATE}}
21fdad271f2cb91d27b1a9f5586294c104032808 4 4
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_CD_P_STARTDATE_HIDDEN}}
21fdad271f2cb91d27b1a9f5586294c104032808 5 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_PROD}}
21fdad271f2cb91d27b1a9f5586294c104032808 6 6
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_REG}}
21fdad271f2cb91d27b1a9f5586294c104032808 7 7
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TERR}}
21fdad271f2cb91d27b1a9f5586294c104032808 8 8
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_TEAM}}
21fdad271f2cb91d27b1a9f5586294c104032808 9 9
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	-- // {{CDL_FA_SEG}}
21fdad271f2cb91d27b1a9f5586294c104032808 10 10
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	 
21fdad271f2cb91d27b1a9f5586294c104032808 11 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
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
21fdad271f2cb91d27b1a9f5586294c104032808 18 18 10
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	    WHERE IS_SAMPLE_CALL = 'True' 
21fdad271f2cb91d27b1a9f5586294c104032808 19 19
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        AND 
21fdad271f2cb91d27b1a9f5586294c104032808 20 20
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
21fdad271f2cb91d27b1a9f5586294c104032808 21 21
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
21fdad271f2cb91d27b1a9f5586294c104032808 22 22
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--        AND
21fdad271f2cb91d27b1a9f5586294c104032808 23 23
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
21fdad271f2cb91d27b1a9f5586294c104032808 24 24
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
21fdad271f2cb91d27b1a9f5586294c104032808 25 25
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
21fdad271f2cb91d27b1a9f5586294c104032808 26 26
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
previous 177c0502e053d936ef9c3a723c05e8c65c8b7388 pasted_code.sql
filename pasted_code.sql
	--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
21fdad271f2cb91d27b1a9f5586294c104032808 27 27
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
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
21fdad271f2cb91d27b1a9f5586294c104032808 30 30 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
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
21fdad271f2cb91d27b1a9f5586294c104032808 36 36 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
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
21fdad271f2cb91d27b1a9f5586294c104032808 38 38 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762931798
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762931798
committer-tz +0530
summary Code review for pasted_code.sql
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
