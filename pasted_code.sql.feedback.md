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
this is the table we have created using the base logic as AIP_G_CALLS_BASE_TBL table

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
Execution blocked: Detected restricted keyword 'drop' in SQL. Execution blocked for safety.

## AI Feedback
**Strict Senior SQL Code Review**

---

### 1) Corrected Code

Your script demonstrates serious procedural, syntax, and logic errors. I will note and fix the most critical issues below.

**Key issues:**
- You cannot use `DROP TABLE` then immediately `CREATE TABLE` in a stored procedure and then `INSERT SELECT * FROM` that same table. Use `TRUNCATE TABLE` or `DELETE FROM` to preserve the object and its privileges/definitions.
- There is no explicit `INSERT INTO ... SELECT ...` statement. The syntax `INSERT select * from table` is invalid.
- The script runs a CTE (WITH statement) starting right after `CREATE TABLE`, which is not valid at this location.
- The second query (for the chart) is missing a semicolon after the prior batch; but more importantly, you try to UNION different measures under one result set, effectively pivoting rather than stacking, which may or may not be correct.
- Variable assignments (e.g., `{{CDL_FA_TPC}}`) are shown as comments. These should be parameterized if used.
- Naming inconsistencies: e.g., `ACCT_TYP_CD_iv_GSK_CDE__C` (lowercase `iv`?) vs original uppercase elsewhere.
- Poor commenting, lack of error handling, layout, etc.

**Here is a corrected version (for MS SQL Server, with major focus on the stored procedure).**  
**Assumptions:**
- You want to completely refresh the base table; for that, you should use `TRUNCATE TABLE` if you want to preserve the schema, permissions, indexes, etc.
- The `INSERT INTO` should target `AIP_G_CALLS_BASE_TBL`.

```sql
ALTER PROCEDURE [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL]
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------------
    -- 1. DELETE EXISTING DATA (DROP/CREATE is highly discouraged)
    ----------------------------------------------------------------------
    -- Use TRUNCATE to clear table, preserving structure, permissions, etc.
    IF OBJECT_ID('AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL', 'U') IS NOT NULL
        TRUNCATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL;
    ELSE
    BEGIN
        CREATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL (
            -- (repeat all columns...)
        );
    END

    ----------------------------------------------------------------------
    -- 2. Load Data Using CTEs
    ----------------------------------------------------------------------
    ;WITH Interaction AS (
        -- ... [REMAINS THE SAME AS YOUR LOGIC] ...
    ),
    Universe AS (
        -- ... (SAME) ...
    ),
    Universe_base AS (
        -- ...
    ),
    UserHierarchyBase AS (
        -- ...
    ),
    UserHierarchy AS (
        -- ...
    ),
    icva AS (
        -- ...
    ),
    Target AS (
        -- ...
    ),
    Base AS (
        -- ...
    ),
    Final AS (
        -- ...
    )
    INSERT INTO AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
    SELECT * FROM Final;

END
GO
```

**If you want to enforce schema recreation, do it separately, outside runtime ETL stored procedure.**

The second part (for the chart summary) should be a SELECT statement, e.g.:

```sql
WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True'
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
FROM base
ORDER BY Segment, [#Sample Calls / Prescribers Sampled];
```

---

### 2) Syntax Errors

- ❌ The use of `DROP TABLE` inside a procedure followed immediately by `CREATE TABLE` and then an `INSERT` into the same table is fundamentally problematic. You lose associated schema binding, indexes, and permissions when using `DROP`.
- ❌ Invalid statement: `INSERT select * from  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL` — this is not valid T-SQL.  
  Correct is:  
  `INSERT INTO AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL SELECT ...`
- ❌ CTE (WITH clause) must be immediately followed by a SELECT/INSERT/UPDATE/etc. Your placement after the CREATE statement is incorrect for an ALTER PROCEDURE.
- ❌ Various syntax issues in your CASE statements (e.g., missing parentheses can lead to precedence issues).
- ❌ Potential case-sensitivity in object/column names.
- ✅ Otherwise, the SELECT logic in the CTEs is mostly valid (ignoring context issues above).

---

### 3) Suggestions / Improvements

**Performance and Readability:**
- Do NOT use `DROP TABLE`/`CREATE TABLE` in stored procedures unless for temp tables.  
  Use `TRUNCATE TABLE` if refresh is necessary.
- Properly separate DDL and ETL logic. Table structure should not be recreated at each ETL run—that should be handled in schema deployment.
- Comment **output columns** and purpose for every major CTE section.
- Consider adding **error handling** (TRY...CATCH) for production code.
- Fully qualify all objects (schema.object) for clarity.
- If columns allow, use proper datatypes (not always `VARCHAR(50)`).  
  Example: if `IS_SAMPLE_CALL` is 'True'/'False', consider `BIT`.
- Check for possible NULLs in JOIN keys, to avoid silent row loss.
- Indexes on foreign key columns (`ACCOUNT_VOD__C`, `EMP_ID`, `ID`, etc) will significantly improve join/query performance.
- `LIKE '%RUKOBIA%'` in `RECORDTYPE` subquery can be slow; consider indexing or refactoring.
- Use **meaningful variable/column casing**—be consistent.
- Where relevant, replace `COUNT(DISTINCT ...)` with approximate calculations if appropriate for performance.
- Avoid `SELECT *`—in ETL use, prefer explicit column lists for upstream change resilience.

**Edge Cases:**
- Refresh scenarios where input relations change: ensure the data model and population accurately reflect rapidly changing business definitions (new segments, status changes, etc.).
- Handle non-matched dimension lookups explicitly.
- For chart/summary query, guard against NULL `Segment` values.

---

### 4) Requirement Mismatch

**Does the SQL satisfy the Description?**

**Part 1: AIP_G_CALLS_BASE_TBL Construction**  
- The CTE chain results in a full outer join/mapping for Calls, Personnel, Timeframes, HCP/HCO, and Target Segments, with derived fields per requirement.
- Sample Calls and HCPs Sampled, by Segment, are correctly countable from the main table as shown in the summary/second query, using IS_SAMPLE_CALL and Segment.
- However, the implementation has significant technical faults as per above—most notably, illegal DDL usage inside the procedure, poor INSERT logic, and inappropriate use of CTE placement.
- The code does (apart from syntax/runtime errors) almost match the described ETL logic for base table construction.

**Part 2: Chart Summary**  
- Logic for counting `#Sample Calls` (distinct Call ID where Sample Call, by Segment) and `Prescribers Sampled` (distinct Account ID where Sample Call, by Segment) is correct, assuming Segment is always populated in the base table.
- However, any filtering logic (e.g., dates or Product, Region, etc.) is missing or commented. In production, these should be parameters, not comments.

**Summary:**  
- ❌ The intended logic is present, but there are critical implementation mistakes that would make this fail in a live environment (bad DDL usage, invalid syntax, lack of filtering support, etc.).
- ❌ You do not have robust parameter handling or error checking, which is critical for trustworthy ETL jobs.

---

**Final Evaluation:**  
- The SQL does *attempt* to fulfill the Description, but technically, it will not execute as intended.  
- It must be rewritten as per corrections above, with major

## Git Blame
```
0000000000000000000000000000000000000000 1 1 256
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	this is the table we have created using the base logic as AIP_G_CALLS_BASE_TBL table
0000000000000000000000000000000000000000 2 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 3 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	ALTER PROCEDURE [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL]
0000000000000000000000000000000000000000 4 4
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	AS
0000000000000000000000000000000000000000 5 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	BEGIN
0000000000000000000000000000000000000000 6 6
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SET NOCOUNT ON;
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    -- 1. DELETE EXISTING DATA
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	   DROP TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	   CREATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL (
0000000000000000000000000000000000000000 12 12
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Account_Id VARCHAR(50),
0000000000000000000000000000000000000000 13 13
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    ID VARCHAR(50),
0000000000000000000000000000000000000000 14 14
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Call_Id VARCHAR(50),
0000000000000000000000000000000000000000 15 15
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    STATUS_VOD__C VARCHAR(50),
0000000000000000000000000000000000000000 16 16
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Call_Date DATE,
0000000000000000000000000000000000000000 17 17
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Product_Name VARCHAR(100),
0000000000000000000000000000000000000000 18 18
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    STAFF_ONLY VARCHAR(10),
0000000000000000000000000000000000000000 19 19
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    INTERACTION_TYPE__C VARCHAR(100),
0000000000000000000000000000000000000000 20 20
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    CALL_TYPE_VOD__C VARCHAR(100),
0000000000000000000000000000000000000000 21 21
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    OWNERID VARCHAR(50),
0000000000000000000000000000000000000000 22 22
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    PARENT_CALL_VOD__C VARCHAR(50),
0000000000000000000000000000000000000000 23 23
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    RECORDTYPEID VARCHAR(50),
0000000000000000000000000000000000000000 24 24
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    OUTCOME VARCHAR(100),
0000000000000000000000000000000000000000 25 25
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    OUTCOME_DETAIL VARCHAR(100),
0000000000000000000000000000000000000000 26 26
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    CONTACT_ROLE VARCHAR(100),
0000000000000000000000000000000000000000 27 27
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    CALL_ATTEMPT_RESULT INT,
0000000000000000000000000000000000000000 28 28
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		IS_SAMPLE_CALL VARCHAR(10),
0000000000000000000000000000000000000000 29 29
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    PRSC_CID VARCHAR(50),
0000000000000000000000000000000000000000 30 30
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Specialty VARCHAR(100),
0000000000000000000000000000000000000000 31 31
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Acc_Prescriber VARCHAR(200),
0000000000000000000000000000000000000000 32 32
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Acc_Account_Type VARCHAR(10),
0000000000000000000000000000000000000000 33 33
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    ACCT_TYP_CD_IV_GSK_CDE__C VARCHAR(50),
0000000000000000000000000000000000000000 34 34
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    PDRP_OPT_OUT_VOD__C VARCHAR(10),
0000000000000000000000000000000000000000 35 35
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    EMP_ID VARCHAR(50),
0000000000000000000000000000000000000000 36 36
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Date DATE,
0000000000000000000000000000000000000000 37 37
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Week DATE,
0000000000000000000000000000000000000000 38 38
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Week_Rank INT,
0000000000000000000000000000000000000000 39 39
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Month_str VARCHAR(20),
0000000000000000000000000000000000000000 40 40
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Month_Rank INT,
0000000000000000000000000000000000000000 41 41
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Year_str VARCHAR(10),
0000000000000000000000000000000000000000 42 42
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Year_Rank INT,
0000000000000000000000000000000000000000 43 43
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Quarter_str VARCHAR(10),
0000000000000000000000000000000000000000 44 44
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Quarter_Rank INT,
0000000000000000000000000000000000000000 45 45
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Date_Rank INT,
0000000000000000000000000000000000000000 46 46
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    tp_date_str VARCHAR(20),
0000000000000000000000000000000000000000 47 47
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    tp_week_str VARCHAR(20),
0000000000000000000000000000000000000000 48 48
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TP_Quarter VARCHAR(10),
0000000000000000000000000000000000000000 49 49
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    weekend_flag VARCHAR(10),
0000000000000000000000000000000000000000 50 50
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Team VARCHAR(20),
0000000000000000000000000000000000000000 51 51
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    BRAND_NAME VARCHAR(100),
0000000000000000000000000000000000000000 52 52
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    PRODUCT_CODE VARCHAR(50),
0000000000000000000000000000000000000000 53 53
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    GEO_NUMBER VARCHAR(50),
0000000000000000000000000000000000000000 54 54
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Prescriber VARCHAR(200),
0000000000000000000000000000000000000000 55 55
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Account_Type VARCHAR(10),
0000000000000000000000000000000000000000 56 56
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Presentation_ID_vod__c VARCHAR(10),
0000000000000000000000000000000000000000 57 57
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Successful_Call INT,
0000000000000000000000000000000000000000 58 58
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Attempted_Call INT,
0000000000000000000000000000000000000000 59 59
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    TERRITORY_NAME VARCHAR(100),
0000000000000000000000000000000000000000 60 60
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    DISTRICT_NAME VARCHAR(100),
0000000000000000000000000000000000000000 61 61
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    REGION_NAME VARCHAR(100),
0000000000000000000000000000000000000000 62 62
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    POSITION_TITLE VARCHAR(100),
0000000000000000000000000000000000000000 63 63
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    REP_FLAG INT,
0000000000000000000000000000000000000000 64 64
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Name VARCHAR(200),
0000000000000000000000000000000000000000 65 65
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    ASSIGNMENT_END_DATE DATE,
0000000000000000000000000000000000000000 66 66
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Target_Flag INT,
0000000000000000000000000000000000000000 67 67
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Segment VARCHAR(50),
0000000000000000000000000000000000000000 68 68
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    Detailed_Calls INT,
0000000000000000000000000000000000000000 69 69
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		CLM_Calls INT,
0000000000000000000000000000000000000000 70 70
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		Calls_Only INT,
0000000000000000000000000000000000000000 71 71
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		Successful_Target_Calls INT,
0000000000000000000000000000000000000000 72 72
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		Pharmacy_Calls INT,
0000000000000000000000000000000000000000 73 73
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
		Target_Detail_Calls INT
0000000000000000000000000000000000000000 74 74
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 75 75
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	);
0000000000000000000000000000000000000000 76 76
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	WITH Interaction AS (
0000000000000000000000000000000000000000 77 77
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT 
0000000000000000000000000000000000000000 78 78
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.ACCOUNT_VOD__C AS Account_Id,
0000000000000000000000000000000000000000 79 79
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.ID,
0000000000000000000000000000000000000000 80 80
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.ID AS Call_Id,
0000000000000000000000000000000000000000 81 81
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.STATUS_VOD__C,
0000000000000000000000000000000000000000 82 82
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CAST(i.CALL_DATE_VOD__C AS DATE) AS Call_Date,
0000000000000000000000000000000000000000 83 83
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        'Product-1' AS Product_Name,
0000000000000000000000000000000000000000 84 84
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(i.STAFF_ONLY, 'False') AS STAFF_ONLY,
0000000000000000000000000000000000000000 85 85
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.INTERACTION_TYPE__C,
0000000000000000000000000000000000000000 86 86
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.CALL_TYPE_VOD__C,
0000000000000000000000000000000000000000 87 87
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.OWNERID,
0000000000000000000000000000000000000000 88 88
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.PARENT_CALL_VOD__C,
0000000000000000000000000000000000000000 89 89
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.RECORDTYPEID,
0000000000000000000000000000000000000000 90 90
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.OUTCOME,
0000000000000000000000000000000000000000 91 91
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.OUTCOME_DETAIL,
0000000000000000000000000000000000000000 92 92
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.CONTACT_ROLE,
0000000000000000000000000000000000000000 93 93
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.CALL_ATTEMPT_RESULT,
0000000000000000000000000000000000000000 94 94
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.IS_SAMPLE_CALL,
0000000000000000000000000000000000000000 95 95
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        a.ID_VOD__C AS PRSC_CID,
0000000000000000000000000000000000000000 96 96
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(a.SPECIALTY_1_VOD__C, 'Unassigned') AS Specialty,
0000000000000000000000000000000000000000 97 97
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        a.NAME AS Acc_Prescriber,
0000000000000000000000000000000000000000 98 98
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE WHEN a.ISPERSONACCOUNT = 'True' THEN 'HCP' ELSE 'HCO' END AS Acc_Account_Type,
0000000000000000000000000000000000000000 99 99
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        a.ACCT_TYP_CD_IV_GSK_CDE__C,
0000000000000000000000000000000000000000 100 100
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        a.PDRP_OPT_OUT_VOD__C,
0000000000000000000000000000000000000000 101 101
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        o.CAST_EMP_ID_IV_BASE__C AS EMP_ID
0000000000000000000000000000000000000000 102 102
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_ACTIVITY i
0000000000000000000000000000000000000000 103 103
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_USER_DETAILS o ON i.OWNERID = o.ID
0000000000000000000000000000000000000000 104 104
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_ACCOUNT_DETAILS a 
0000000000000000000000000000000000000000 105 105
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        ON i.ACCOUNT_VOD__C = a.ID AND a.COUNTRY_IV_GSK__C = 'US'
0000000000000000000000000000000000000000 106 106
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE i.STATUS_VOD__C = 'Submitted_vod'
0000000000000000000000000000000000000000 107 107
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	      AND a.COUNTRY_IV_GSK__C = 'US'
0000000000000000000000000000000000000000 108 108
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	      AND i.RECORDTYPEID IN (
0000000000000000000000000000000000000000 109 109
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            SELECT ID
0000000000000000000000000000000000000000 110 110
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            FROM AIP_FULL_COMMERCIAL.AIP_CRM_RECORDTYPE
0000000000000000000000000000000000000000 111 111
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHERE UPPER(NAME) LIKE '%RUKOBIA%'
0000000000000000000000000000000000000000 112 112
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	      )
0000000000000000000000000000000000000000 113 113
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 114 114
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	Universe AS (
0000000000000000000000000000000000000000 115 115
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT DISTINCT CID AS PRSC_CID, HCP_NAME AS Prescriber, 'HCP' AS Account_Type
0000000000000000000000000000000000000000 116 116
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_HCP_UNIVERSE
0000000000000000000000000000000000000000 117 117
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
0000000000000000000000000000000000000000 118 118
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    UNION ALL
0000000000000000000000000000000000000000 119 119
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT DISTINCT CID AS PRSC_CID, ACCOUNT_NAME AS Prescriber, 'HCO' AS Account_Type
0000000000000000000000000000000000000000 120 120
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_HCO_UNIVERSE
0000000000000000000000000000000000000000 121 121
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
0000000000000000000000000000000000000000 122 122
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 123 123
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	Universe_base AS (
0000000000000000000000000000000000000000 124 124
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT *,
0000000000000000000000000000000000000000 125 125
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        ROW_NUMBER() OVER (PARTITION BY PRSC_CID ORDER BY PRSC_CID) AS rn
0000000000000000000000000000000000000000 126 126
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM Universe
0000000000000000000000000000000000000000 127 127
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 128 128
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	UserHierarchyBase AS (
0000000000000000000000000000000000000000 129 129
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT 
0000000000000000000000000000000000000000 130 130
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        EMP_ID,
0000000000000000000000000000000000000000 131 131
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        GEO_NAME AS TERRITORY_NAME,
0000000000000000000000000000000000000000 132 132
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        ' ' AS DISTRICT_NAME,
0000000000000000000000000000000000000000 133 133
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        PARENT_GEO_NAME AS REGION_NAME,
0000000000000000000000000000000000000000 134 134
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        POSITION_TITLE,
0000000000000000000000000000000000000000 135 135
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        GEO_NUMBER,
0000000000000000000000000000000000000000 136 136
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CAST(ASSIGNMENT_END_DATE AS DATE) AS ASSIGNMENT_END_DATE,
0000000000000000000000000000000000000000 137 137
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        REP_FLAG,
0000000000000000000000000000000000000000 138 138
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        TEAM,
0000000000000000000000000000000000000000 139 139
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE
0000000000000000000000000000000000000000 140 140
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN ASSIGNMENT_END_DATE < GETDATE()
0000000000000000000000000000000000000000 141 141
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	                AND (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
0000000000000000000000000000000000000000 142 142
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	                THEN 'Vacant'
0000000000000000000000000000000000000000 143 143
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            ELSE FULL_NAME
0000000000000000000000000000000000000000 144 144
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        END AS Name
0000000000000000000000000000000000000000 145 145
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT
0000000000000000000000000000000000000000 146 146
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE REP_FLAG = 1
0000000000000000000000000000000000000000 147 147
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 148 148
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	UserHierarchy AS (
0000000000000000000000000000000000000000 149 149
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT * FROM UserHierarchyBase
0000000000000000000000000000000000000000 150 150
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
0000000000000000000000000000000000000000 151 151
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 152 152
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	icva AS (
0000000000000000000000000000000000000000 153 153
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT DISTINCT CALL2_VOD__C, 'Yes' AS Presentation_ID_vod__c
0000000000000000000000000000000000000000 154 154
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_KEYMESSAGE
0000000000000000000000000000000000000000 155 155
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE CALL2_VOD__C IN (SELECT DISTINCT ID FROM Interaction)
0000000000000000000000000000000000000000 156 156
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 157 157
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	Target AS (
0000000000000000000000000000000000000000 158 158
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT DISTINCT
0000000000000000000000000000000000000000 159 159
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        QTR_FY AS Qtr,
0000000000000000000000000000000000000000 160 160
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        ID AS Account_Id,
0000000000000000000000000000000000000000 161 161
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        TERRITORY AS GEO_NUMBER,
0000000000000000000000000000000000000000 162 162
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        1 AS Target_Flag,
0000000000000000000000000000000000000000 163 163
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(RUKOBIA_SEGMENT_IV_GSK_TELE__C, 'Non-Tier Targets') AS Segment
0000000000000000000000000000000000000000 164 164
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS
0000000000000000000000000000000000000000 165 165
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE ID IN (SELECT Account_Id FROM Interaction)
0000000000000000000000000000000000000000 166 166
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 167 167
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	Base AS (
0000000000000000000000000000000000000000 168 168
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT 
0000000000000000000000000000000000000000 169 169
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.*,
0000000000000000000000000000000000000000 170 170
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CAST(d.TP_Date AS DATE) AS TP_Date,
0000000000000000000000000000000000000000 171 171
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Week,
0000000000000000000000000000000000000000 172 172
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Week_Rank,
0000000000000000000000000000000000000000 173 173
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Month_str,
0000000000000000000000000000000000000000 174 174
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Month_Rank,
0000000000000000000000000000000000000000 175 175
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Year_str,
0000000000000000000000000000000000000000 176 176
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Year_Rank,
0000000000000000000000000000000000000000 177 177
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Quarter_str,
0000000000000000000000000000000000000000 178 178
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Quarter_Rank,
0000000000000000000000000000000000000000 179 179
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Date_Rank,
0000000000000000000000000000000000000000 180 180
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.tp_date_str,
0000000000000000000000000000000000000000 181 181
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.tp_week_str,
0000000000000000000000000000000000000000 182 182
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.TP_Quarter,
0000000000000000000000000000000000000000 183 183
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        d.weekend_flag,
0000000000000000000000000000000000000000 184 184
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        r.Team,
0000000000000000000000000000000000000000 185 185
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        p.BRAND_NAME,
0000000000000000000000000000000000000000 186 186
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        p.PRODUCT_CODE,
0000000000000000000000000000000000000000 187 187
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        uh.GEO_NUMBER,
0000000000000000000000000000000000000000 188 188
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(a.Prescriber, i.Acc_Prescriber) AS Prescriber,
0000000000000000000000000000000000000000 189 189
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(a.Account_Type, i.Acc_Account_Type) AS Account_Type,
0000000000000000000000000000000000000000 190 190
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        iv.Presentation_ID_vod__c,
0000000000000000000000000000000000000000 191 191
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE WHEN i.CALL_TYPE_VOD__C LIKE '%Detail%' AND i.CALL_ATTEMPT_RESULT = 1 THEN 1 ELSE 0 END AS Successful_Call,
0000000000000000000000000000000000000000 192 192
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE WHEN i.CALL_TYPE_VOD__C IS NOT NULL AND i.CALL_TYPE_VOD__C <> '' THEN 1 ELSE 0 END AS Attempted_Call
0000000000000000000000000000000000000000 193 193
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM Interaction i
0000000000000000000000000000000000000000 194 194
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN AIP_FULL_COMMERCIAL.Dim_config_date d ON i.Call_Date = d.TP_Date
0000000000000000000000000000000000000000 195 195
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN AIP_FULL_COMMERCIAL.RECORD_TYPE r ON i.RECORDTYPEID = r.RECORDTYPEID
0000000000000000000000000000000000000000 196 196
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_PRODUCT_MASTER p ON i.Product_Name = p.BRAND_NAME
0000000000000000000000000000000000000000 197 197
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN UserHierarchyBase uh ON i.EMP_ID = uh.EMP_ID AND uh.POSITION_TITLE LIKE '%Representative%'
0000000000000000000000000000000000000000 198 198
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN Universe_base a ON i.PRSC_CID = a.PRSC_CID AND rn = 1
0000000000000000000000000000000000000000 199 199
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN icva iv ON i.Call_Id = iv.CALL2_VOD__C
0000000000000000000000000000000000000000 200 200
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	),
0000000000000000000000000000000000000000 201 201
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	Final AS (
0000000000000000000000000000000000000000 202 202
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT 
0000000000000000000000000000000000000000 203 203
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        i.*,
0000000000000000000000000000000000000000 204 204
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(u.TERRITORY_NAME, 'Unassigned') AS TERRITORY_NAME,
0000000000000000000000000000000000000000 205 205
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        u.DISTRICT_NAME,
0000000000000000000000000000000000000000 206 206
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        COALESCE(u.REGION_NAME, 'Unassigned') AS REGION_NAME,
0000000000000000000000000000000000000000 207 207
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        u.POSITION_TITLE,
0000000000000000000000000000000000000000 208 208
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        u.REP_FLAG,
0000000000000000000000000000000000000000 209 209
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        u.Name,
0000000000000000000000000000000000000000 210 210
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        u.ASSIGNMENT_END_DATE,
0000000000000000000000000000000000000000 211 211
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        t.Target_Flag,
0000000000000000000000000000000000000000 212 212
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE
0000000000000000000000000000000000000000 213 213
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN t.Segment IS NOT NULL THEN t.Segment
0000000000000000000000000000000000000000 214 214
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Team = 'Field' THEN 'Non-ECL'
0000000000000000000000000000000000000000 215 215
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Team = 'EC' THEN 'Field Assist'
0000000000000000000000000000000000000000 216 216
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            ELSE NULL
0000000000000000000000000000000000000000 217 217
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        END AS Segment,
0000000000000000000000000000000000000000 218 218
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE
0000000000000000000000000000000000000000 219 219
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Account_Type = 'HCP' AND i.STAFF_ONLY = 'False' AND i.Team = 'Field' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
0000000000000000000000000000000000000000 220 220
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Account_Type = 'HCO' OR i.Team = 'EC' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
0000000000000000000000000000000000000000 221 221
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            ELSE 0
0000000000000000000000000000000000000000 222 222
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            END AS Detailed_Calls,
0000000000000000000000000000000000000000 223 223
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE
0000000000000000000000000000000000000000 224 224
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Account_Type LIKE 'HCO' AND i.Call_Type_vod__c LIKE '%Call Only%' THEN 1 
0000000000000000000000000000000000000000 225 225
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				ELSE 0 
0000000000000000000000000000000000000000 226 226
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				END AS Calls_Only,
0000000000000000000000000000000000000000 227 227
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	        CASE
0000000000000000000000000000000000000000 228 228
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type LIKE '%HCP%' THEN 1 
0000000000000000000000000000000000000000 229 229
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				ELSE 0 
0000000000000000000000000000000000000000 230 230
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				END AS CLM_Calls,
0000000000000000000000000000000000000000 231 231
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	         CASE
0000000000000000000000000000000000000000 232 232
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Account_Type LIKE 'HCP' AND i.Successful_Call = 1 AND t.Target_Flag = 1 THEN 1 
0000000000000000000000000000000000000000 233 233
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				ELSE 0 
0000000000000000000000000000000000000000 234 234
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				END AS Successful_Target_Calls,
0000000000000000000000000000000000000000 235 235
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
			CASE
0000000000000000000000000000000000000000 236 236
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.ACCT_TYP_CD_iv_GSK_CDE__C LIKE '%PHRM%' THEN 1 
0000000000000000000000000000000000000000 237 237
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				ELSE 0 
0000000000000000000000000000000000000000 238 238
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				END AS Pharmacy_Calls,
0000000000000000000000000000000000000000 239 239
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
			CASE
0000000000000000000000000000000000000000 240 240
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Call_Type_vod__c LIKE '%Detail%' AND t.Target_Flag=1 THEN 1 
0000000000000000000000000000000000000000 241 241
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				ELSE 0 
0000000000000000000000000000000000000000 242 242
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
				END AS Target_Detail_Calls
0000000000000000000000000000000000000000 243 243
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    FROM Base i
0000000000000000000000000000000000000000 244 244
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN UserHierarchy u ON i.GEO_NUMBER = u.GEO_NUMBER
0000000000000000000000000000000000000000 245 245
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    LEFT JOIN Target t ON i.TP_Quarter = t.Qtr AND i.Account_Id = t.Account_Id AND i.GEO_NUMBER = t.GEO_NUMBER
0000000000000000000000000000000000000000 246 246
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	)
0000000000000000000000000000000000000000 247 247
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	INSERT select * from  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
0000000000000000000000000000000000000000 248 248
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	SELECT *
0000000000000000000000000000000000000000 249 249
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	FROM Final;
0000000000000000000000000000000000000000 250 250
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	END;
0000000000000000000000000000000000000000 251 251
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	GO
0000000000000000000000000000000000000000 252 252
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 253 253
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 254 254
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 255 255
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	WITH base AS (
0000000000000000000000000000000000000000 256 256
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    SELECT
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 14 257 4
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 15 258
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 16 259
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 17 260
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
0000000000000000000000000000000000000000 261 261 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	    WHERE IS_SAMPLE_CALL = 'True' 
0000000000000000000000000000000000000000 262 262
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--        AND 
0000000000000000000000000000000000000000 263 263
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
0000000000000000000000000000000000000000 264 264
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
0000000000000000000000000000000000000000 265 265
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--        AND
0000000000000000000000000000000000000000 266 266
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
0000000000000000000000000000000000000000 267 267
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
0000000000000000000000000000000000000000 268 268
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
0000000000000000000000000000000000000000 269 269
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
0000000000000000000000000000000000000000 270 270
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	--?        ,(Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 28 271 2
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 29 272
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
0000000000000000000000000000000000000000 273 273 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 31 274 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 32 275
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 33 276
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 34 277
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 35 278
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
0000000000000000000000000000000000000000 279 279 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 37 280 1
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
0000000000000000000000000000000000000000 281 281 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1762932957
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1762932957
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 39 282 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 40 283
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 41 284
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 42 285
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 43 286
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
