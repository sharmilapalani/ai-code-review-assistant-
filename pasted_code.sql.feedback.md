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
	
Sample Calls  : Count distinct ID from the AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY.

HCPs Sampled by Segment :

Count of distinct ACCOUNT_VOD__C from AIP_CRM_CALL_ACTVITY  where IS_SAMPLE_CALL = True , for selected Time period in the Dashboard , the Time period is determined by CALL_DATE_VOD__C column from the AIP_CRM_CALL_ACTVITY and HCP segment is derived from AIP_CRM_TARGET_LIST identified by AIP_CRM_CALL_ACTVITY  . ACCOUNT_VOD__C= AIP_CRM_TARGET_LIST .ACCOUNT_VOD__C and pull the column SEGMENT.

## Uploaded Code
```sql
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
```

## CDL Execution Summary
⚠️ Execution error: ('42000', '[42000] [Microsoft][ODBC Driver 17 for SQL Server]Syntax error, permission violation, or other nonspecific error (0) (SQLExecDirectW)')

## AI Feedback
**1) Corrected Code**

```sql
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
```
**(Moved the final SELECT outside the CTE, as SQL Server requires this. The original code left a hanging closing parenthesis without starting a CTE. See Syntax Errors section below.)**

---

**2) Syntax Errors**

❌ Found the following syntax issue(s):

- The code starts with `SELECT ... FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL ... )` which leaves a dangling closing parenthesis before the next `SELECT`, indicating an improperly terminated CTE. In SQL Server, you must use `WITH base AS (...) SELECT ...` not `(...) SELECT ...` on its own.
- No semicolon is strictly required at the end of SQL Server statements, but good practice is to terminate statements for clarity.
- The variables such as `{{CDL_FA_TPC}}` are template variables and not valid SQL; they will only resolve if replaced/handled by a higher-level tool (like Looker, Tableau, etc.).
- There was no `WITH base AS (...)`, only a parenthesized subquery.
- No alias for the subquery, which is not allowed in T-SQL.

---

**3) Suggestions / Improvements**

- **Performance**
    - Ensure an index exists on `IS_SAMPLE_CALL`, `Call_Date`, and `Segment` in `AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL` to optimize WHERE and GROUP BY performance.
    - The use of multiple ORs in the WHERE clause (e.g., for custom vs. default dates) may inhibit index usage. Consider splitting queries programmatically when possible.
- **Readability**
    - Template variables should be commented or replaced with defaults for easier standalone testing/debugging.
    - Consider factoring the repeated structure in WHERE with parameters or explicit block comments.
- **Edge-Cases**
    - If any of the lookups (e.g., on `Segment`) can be NULL, ensure results do not get dropped due to GROUP BY or WHERE.
    - If filters are optional (e.g., `{{CDL_FA_PROD}} = 'ALL'`), make sure the front-end guarantees the value 'ALL' and it is case-consistent.
- **Result format**
    - This "pivot" approach is fine, but if the dashboard requires one row per segment with multiple columns, consider providing results as:
      ```sql
      SELECT 
          Segment, 
          COUNT(DISTINCT ID) AS [Sample Calls],
          COUNT(DISTINCT Account_Id) AS [Prescribers Sampled]
      FROM ...
      GROUP BY Segment
      ```

---

**4) Requirement Mismatch**

❌ The SQL does *not* fully satisfy the requirements as described:

- The code properly calculates:
    - **Sample Calls:** By counting distinct `ID` where `IS_SAMPLE_CALL = 'True'` in the base table and for selected `Call_Date` period.
    - **HCPs Sampled by Segment (Prescribers Sampled):** By counting distinct `Account_Id` with the same filters and grouping by `Segment`.
- **However**, per the Description, "HCP segment is derived from AIP_CRM_TARGET_LIST identified by AIP_CRM_CALL_ACTIVITY.ACCOUNT_VOD__C = AIP_CRM_TARGET_LIST.ACCOUNT_VOD__C", and "Segment" comes from that logic.  
    - The code assumes "Segment" is **already in** `AIP_G_CALLS_BASE_TBL`. You must be absolutely sure that the field in the base table is populated correctly per the business requirement. If not, then the SQL is *insufficient*.
    - If "Segment" is *not* pre-joined in the base, the SQL must join to AIP_CRM_TARGET_LIST in this reporting query to assign accurate segment.
- The SQL structure (after syntactic fix) otherwise matches the aggregation needs.

**Summary**:  
- If `AIP_G_CALLS_BASE_TBL` has the correct `Segment` value for each row, this SQL (with corrected syntax) matches requirements.
- If not, the query is incomplete for requirement 2 and must join with the target list.  
- Syntax errors must be fixed for code to be executable.

---

**Final Review Summary Table**

| Area                   | OK? | Comments                                                     |
|------------------------|-----|--------------------------------------------------------------|
| Accurate Syntax        | ❌  | CTE not properly declared/closed.                            |
| Filters per Spec       | ✅  | Logic and filter implementation are correct.                 |
| Output Format          | ✅  | Matches dashboard requirements (pivoted small table).         |
| Segment Derivation     | ⚠️  | Only compliant if base table already contains true segments. |
| Performance/Index Hints| ⚠️  | Indexes recommended for critical columns.                    |

## Git Blame
```
0000000000000000000000000000000000000000 1 1 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	SELECT
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 14 2 4
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 15 3
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 16 4
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 17 5
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
0000000000000000000000000000000000000000 6 6 16
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	    WHERE IS_SAMPLE_CALL = 'True'
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND (
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	            (
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	                {{CDL_FA_TPC}} <> 'Custom'
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	                AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}}
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	            )
0000000000000000000000000000000000000000 12 12
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	            OR (
0000000000000000000000000000000000000000 13 13
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	                {{CDL_FA_TPC}} = 'Custom'
0000000000000000000000000000000000000000 14 14
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	                AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}
0000000000000000000000000000000000000000 15 15
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	            )
0000000000000000000000000000000000000000 16 16
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	        )
0000000000000000000000000000000000000000 17 17
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND ({{CDL_FA_PROD}} = 'ALL' OR Product_Name = {{CDL_FA_PROD}})
0000000000000000000000000000000000000000 18 18
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND ({{CDL_FA_REG}} = 'ALL' OR REGION_NAME = {{CDL_FA_REG}})
0000000000000000000000000000000000000000 19 19
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND ({{CDL_FA_TERR}} = 'ALL' OR TERRITORY_NAME = {{CDL_FA_TERR}})
0000000000000000000000000000000000000000 20 20
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND ({{CDL_FA_TEAM}} = 'ALL' OR Team = {{CDL_FA_TEAM}})
0000000000000000000000000000000000000000 21 21
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932240
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932240
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 37c2dd7ee9ada63e6b8d2ca7a3273267d4634d23 pasted_code.sql
filename pasted_code.sql
	      AND ({{CDL_FA_SEG}} = 'ALL' OR Segment = {{CDL_FA_SEG}})
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 28 22 2
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 29 23
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 31 24 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 32 25
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 33 26
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 34 27
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 35 28
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 37 29 1
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 39 30 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 40 31
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 41 32
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 42 33
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 43 34
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
