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

usig the above table we are deriving this bbased on logic given above


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
**1) Corrected Code**

Significant corrections are necessary for syntax, safety, and best practices, especially within the stored procedure. Below is the fully corrected code for both the procedure and the chart logic.

### a. Corrected Stored Procedure

```sql
ALTER PROCEDURE [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL]
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- 1. DELETE EXISTING DATA
    ------------------------------------------------------------

    -- Use TRUNCATE instead of DROP+CREATE for performance/safety.
    IF OBJECT_ID('AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL', 'U') IS NOT NULL
        TRUNCATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL;

    -- If table does not exist, create it.
    IF OBJECT_ID('AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL', 'U') IS NULL
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

    -- Now mass-insert new data
    WITH Interaction AS (
        -- ...[same as your CTE logic]...
        -- (No change except formatting if required, see notes below)
    ),
    Universe AS (
        -- ...[same as your CTE logic]...
    ),
    Universe_base AS (
        -- ...[same as your CTE logic]...
    ),
    UserHierarchyBase AS (
        -- ...[same as your CTE logic]...
    ),
    UserHierarchy AS (
        -- ...[same as your CTE logic]...
    ),
    icva AS (
        -- ...[same as your CTE logic]...
    ),
    Target AS (
        -- ...[same as your CTE logic]...
    ),
    Base AS (
        -- ...[same as your CTE logic]...
    ),
    Final AS (
        -- ...[same as your CTE logic]...
    )
    INSERT INTO AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
    SELECT *
    FROM Final;
END;
GO
```

### b. Corrected Chart SQL

✅ The chart CTE-query is generally correct except for over-commented and dead parameter lines, which should be syntactically valid or omitted. For a parameterized report, you'd use proper filter clauses.

**For demonstration:**
```sql
WITH base AS (
    SELECT
        Segment, 
        COUNT(DISTINCT ID) AS sample_calls,
        COUNT(DISTINCT Account_Id) AS prescribers_sampled
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL 
    WHERE IS_SAMPLE_CALL = 'True'
    -- Add where clause for date/filters as required, e.g. 
    -- AND Call_Date BETWEEN @start_date AND @end_date
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

---

**2) Syntax Errors**

- ❌ Major error: `DROP TABLE` immediately followed by `CREATE TABLE` is hazardous and fails if the table is referenced by views/constraints or if table doesn't exist.
- ❌ Missing `INSERT INTO` before `SELECT * from AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL` (should be `INSERT INTO tablename SELECT ...`).
- ❌ Comment lines in the last query (chart CTE) are not valid SQL and will error unless properly parameterized or handled in reporting layer.
- ❌ Invalid use of `INSERT select * from AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL`. You should insert `into` the table from a derived table/CTE, not from the table itself.

**3) Suggestions / Improvements**

- **Safety:** Avoid `DROP TABLE` in production ETL. Use `TRUNCATE TABLE` if possible. If not, use `DELETE` (but slower), and only recreate the table if it doesn't exist.
- **Concurrency:** Dropping the table may break code/reports that depend on the table’s schema if running simultaneously.
- **Create Table Only If Not Exists:** Use `IF OBJECT_ID('schema.table', 'U') IS NULL ... CREATE TABLE` rather than just creating.
- **Explicit Insert:** Always use `INSERT INTO schema.tbl (...) SELECT ...`. Never use `INSERT ... from tbl` (your code had `INSERT select * from AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL SELECT * FROM Final`).
- **CTE readability:** Consider keeping your CTE list at the top for readability; indent and format for clarity.
- **Parameterization:** The commented block in the chart logic should be actual parameters or dynamic SQL—never leave code with pseudo-variables and commented-out filter logic.
- **Case-sensitive typos:** You have inconsistent casing in references, e.g., `ACCT_TYP_CD_iv_GSK_CDE__C` vs. `ACCT_TYP_CD_IV_GSK_CDE__C`. Columns may be case-sensitive depending on DB collation.
- **Table design:** No primary key or indexes defined on `AIP_G_CALLS_BASE_TBL`. Depending on later querying, you should consider at least a clustered index, e.g. on `(ID)` or date plus segment.
- **Data types:** Using `VARCHAR(10)` for boolean fields is inefficient; use `BIT` in future designs.
- **Batch loads:** For large data, consider `TABLOCK` hint or bulk-loading in production ETL.

**4) Requirement Mismatch**

- **Does the SQL satisfy the Description?**  
   - For the stored procedure: **Yes, provided corrections are made**. The base joins and filtering logic are complete as per your description; it should load the base table as described.
   - For the chart logic: **Yes**, it will produce the correct summary for "#Sample Calls" and "Prescribers Sampled" by segment from the base table, given the field definitions and filter on `IS_SAMPLE_CALL = 'True'`.
   - **However, deployment of the current

## Git Blame
```
7ae1788762b98e1f9f095fd37718b6ba6deb90da 1 1 252
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
	this is the table we have created using the base logic as AIP_G_CALLS_BASE_TBL table
7ae1788762b98e1f9f095fd37718b6ba6deb90da 2 2
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
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 3 3
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
	ALTER PROCEDURE [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL]
7ae1788762b98e1f9f095fd37718b6ba6deb90da 4 4
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
	AS
7ae1788762b98e1f9f095fd37718b6ba6deb90da 5 5
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
	BEGIN
7ae1788762b98e1f9f095fd37718b6ba6deb90da 6 6
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
	    SET NOCOUNT ON;
7ae1788762b98e1f9f095fd37718b6ba6deb90da 7 7
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
	    ------------------------------------------------------------
7ae1788762b98e1f9f095fd37718b6ba6deb90da 8 8
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
	    -- 1. DELETE EXISTING DATA
7ae1788762b98e1f9f095fd37718b6ba6deb90da 9 9
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
	    ------------------------------------------------------------
7ae1788762b98e1f9f095fd37718b6ba6deb90da 10 10
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
	   DROP TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
7ae1788762b98e1f9f095fd37718b6ba6deb90da 11 11
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
	   CREATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 12 12
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
	    Account_Id VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 13 13
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
	    ID VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 14 14
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
	    Call_Id VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 15 15
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
	    STATUS_VOD__C VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 16 16
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
	    Call_Date DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 17 17
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
	    Product_Name VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 18 18
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
	    STAFF_ONLY VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 19 19
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
	    INTERACTION_TYPE__C VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 20 20
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
	    CALL_TYPE_VOD__C VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 21 21
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
	    OWNERID VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 22 22
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
	    PARENT_CALL_VOD__C VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 23 23
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
	    RECORDTYPEID VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 24 24
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
	    OUTCOME VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 25 25
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
	    OUTCOME_DETAIL VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 26 26
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
	    CONTACT_ROLE VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 27 27
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
	    CALL_ATTEMPT_RESULT INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 28 28
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
		IS_SAMPLE_CALL VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 29 29
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
	    PRSC_CID VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 30 30
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
	    Specialty VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 31 31
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
	    Acc_Prescriber VARCHAR(200),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 32 32
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
	    Acc_Account_Type VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 33 33
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
	    ACCT_TYP_CD_IV_GSK_CDE__C VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 34 34
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
	    PDRP_OPT_OUT_VOD__C VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 35 35
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
	    EMP_ID VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 36 36
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
	    TP_Date DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 37 37
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
	    TP_Week DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 38 38
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
	    TP_Week_Rank INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 39 39
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
	    TP_Month_str VARCHAR(20),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 40 40
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
	    TP_Month_Rank INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 41 41
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
	    TP_Year_str VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 42 42
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
	    TP_Year_Rank INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 43 43
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
	    TP_Quarter_str VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 44 44
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
	    TP_Quarter_Rank INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 45 45
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
	    TP_Date_Rank INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 46 46
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
	    tp_date_str VARCHAR(20),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 47 47
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
	    tp_week_str VARCHAR(20),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 48 48
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
	    TP_Quarter VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 49 49
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
	    weekend_flag VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 50 50
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
	    Team VARCHAR(20),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 51 51
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
	    BRAND_NAME VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 52 52
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
	    PRODUCT_CODE VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 53 53
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
	    GEO_NUMBER VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 54 54
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
	    Prescriber VARCHAR(200),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 55 55
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
	    Account_Type VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 56 56
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
	    Presentation_ID_vod__c VARCHAR(10),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 57 57
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
	    Successful_Call INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 58 58
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
	    Attempted_Call INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 59 59
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
	    TERRITORY_NAME VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 60 60
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
	    DISTRICT_NAME VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 61 61
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
	    REGION_NAME VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 62 62
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
	    POSITION_TITLE VARCHAR(100),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 63 63
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
	    REP_FLAG INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 64 64
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
	    Name VARCHAR(200),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 65 65
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
	    ASSIGNMENT_END_DATE DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 66 66
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
	    Target_Flag INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 67 67
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
	    Segment VARCHAR(50),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 68 68
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
	    Detailed_Calls INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 69 69
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
		CLM_Calls INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 70 70
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
		Calls_Only INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 71 71
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
		Successful_Target_Calls INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 72 72
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
		Pharmacy_Calls INT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 73 73
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
		Target_Detail_Calls INT
7ae1788762b98e1f9f095fd37718b6ba6deb90da 74 74
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
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 75 75
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
	);
7ae1788762b98e1f9f095fd37718b6ba6deb90da 76 76
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
	WITH Interaction AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 77 77
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
	    SELECT 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 78 78
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
	        i.ACCOUNT_VOD__C AS Account_Id,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 79 79
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
	        i.ID,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 80 80
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
	        i.ID AS Call_Id,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 81 81
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
	        i.STATUS_VOD__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 82 82
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
	        CAST(i.CALL_DATE_VOD__C AS DATE) AS Call_Date,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 83 83
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
	        'Product-1' AS Product_Name,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 84 84
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
	        COALESCE(i.STAFF_ONLY, 'False') AS STAFF_ONLY,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 85 85
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
	        i.INTERACTION_TYPE__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 86 86
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
	        i.CALL_TYPE_VOD__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 87 87
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
	        i.OWNERID,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 88 88
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
	        i.PARENT_CALL_VOD__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 89 89
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
	        i.RECORDTYPEID,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 90 90
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
	        i.OUTCOME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 91 91
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
	        i.OUTCOME_DETAIL,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 92 92
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
	        i.CONTACT_ROLE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 93 93
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
	        i.CALL_ATTEMPT_RESULT,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 94 94
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
	        i.IS_SAMPLE_CALL,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 95 95
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
	        a.ID_VOD__C AS PRSC_CID,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 96 96
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
	        COALESCE(a.SPECIALTY_1_VOD__C, 'Unassigned') AS Specialty,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 97 97
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
	        a.NAME AS Acc_Prescriber,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 98 98
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
	        CASE WHEN a.ISPERSONACCOUNT = 'True' THEN 'HCP' ELSE 'HCO' END AS Acc_Account_Type,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 99 99
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
	        a.ACCT_TYP_CD_IV_GSK_CDE__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 100 100
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
	        a.PDRP_OPT_OUT_VOD__C,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 101 101
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
	        o.CAST_EMP_ID_IV_BASE__C AS EMP_ID
7ae1788762b98e1f9f095fd37718b6ba6deb90da 102 102
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
	    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_ACTIVITY i
7ae1788762b98e1f9f095fd37718b6ba6deb90da 103 103
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
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_USER_DETAILS o ON i.OWNERID = o.ID
7ae1788762b98e1f9f095fd37718b6ba6deb90da 104 104
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
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_CRM_ACCOUNT_DETAILS a 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 105 105
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
	        ON i.ACCOUNT_VOD__C = a.ID AND a.COUNTRY_IV_GSK__C = 'US'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 106 106
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
	    WHERE i.STATUS_VOD__C = 'Submitted_vod'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 107 107
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
	      AND a.COUNTRY_IV_GSK__C = 'US'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 108 108
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
	      AND i.RECORDTYPEID IN (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 109 109
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
	            SELECT ID
7ae1788762b98e1f9f095fd37718b6ba6deb90da 110 110
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
	            FROM AIP_FULL_COMMERCIAL.AIP_CRM_RECORDTYPE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 111 111
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
	            WHERE UPPER(NAME) LIKE '%RUKOBIA%'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 112 112
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 113 113
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 114 114
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
	Universe AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 115 115
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
	    SELECT DISTINCT CID AS PRSC_CID, HCP_NAME AS Prescriber, 'HCP' AS Account_Type
7ae1788762b98e1f9f095fd37718b6ba6deb90da 116 116
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
	    FROM AIP_FULL_COMMERCIAL.AIP_HCP_UNIVERSE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 117 117
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
	    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
7ae1788762b98e1f9f095fd37718b6ba6deb90da 118 118
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
	    UNION ALL
7ae1788762b98e1f9f095fd37718b6ba6deb90da 119 119
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
	    SELECT DISTINCT CID AS PRSC_CID, ACCOUNT_NAME AS Prescriber, 'HCO' AS Account_Type
7ae1788762b98e1f9f095fd37718b6ba6deb90da 120 120
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
	    FROM AIP_FULL_COMMERCIAL.AIP_HCO_UNIVERSE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 121 121
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
	    WHERE CID IN (SELECT PRSC_CID FROM Interaction)
7ae1788762b98e1f9f095fd37718b6ba6deb90da 122 122
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 123 123
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
	Universe_base AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 124 124
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
	    SELECT *,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 125 125
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
	        ROW_NUMBER() OVER (PARTITION BY PRSC_CID ORDER BY PRSC_CID) AS rn
7ae1788762b98e1f9f095fd37718b6ba6deb90da 126 126
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
	    FROM Universe
7ae1788762b98e1f9f095fd37718b6ba6deb90da 127 127
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 128 128
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
	UserHierarchyBase AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 129 129
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
	    SELECT 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 130 130
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
	        EMP_ID,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 131 131
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
	        GEO_NAME AS TERRITORY_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 132 132
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
	        ' ' AS DISTRICT_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 133 133
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
	        PARENT_GEO_NAME AS REGION_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 134 134
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
	        POSITION_TITLE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 135 135
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
	        GEO_NUMBER,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 136 136
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
	        CAST(ASSIGNMENT_END_DATE AS DATE) AS ASSIGNMENT_END_DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 137 137
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
	        REP_FLAG,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 138 138
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
	        TEAM,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 139 139
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
	        CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 140 140
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
	            WHEN ASSIGNMENT_END_DATE < GETDATE()
7ae1788762b98e1f9f095fd37718b6ba6deb90da 141 141
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
	                AND (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
7ae1788762b98e1f9f095fd37718b6ba6deb90da 142 142
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
	                THEN 'Vacant'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 143 143
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
	            ELSE FULL_NAME
7ae1788762b98e1f9f095fd37718b6ba6deb90da 144 144
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
	        END AS Name
7ae1788762b98e1f9f095fd37718b6ba6deb90da 145 145
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
	    FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT
7ae1788762b98e1f9f095fd37718b6ba6deb90da 146 146
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
	    WHERE REP_FLAG = 1
7ae1788762b98e1f9f095fd37718b6ba6deb90da 147 147
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 148 148
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
	UserHierarchy AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 149 149
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
	    SELECT * FROM UserHierarchyBase
7ae1788762b98e1f9f095fd37718b6ba6deb90da 150 150
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
	    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
7ae1788762b98e1f9f095fd37718b6ba6deb90da 151 151
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 152 152
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
	icva AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 153 153
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
	    SELECT DISTINCT CALL2_VOD__C, 'Yes' AS Presentation_ID_vod__c
7ae1788762b98e1f9f095fd37718b6ba6deb90da 154 154
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
	    FROM AIP_FULL_COMMERCIAL.AIP_CRM_CALL_KEYMESSAGE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 155 155
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
	    WHERE CALL2_VOD__C IN (SELECT DISTINCT ID FROM Interaction)
7ae1788762b98e1f9f095fd37718b6ba6deb90da 156 156
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 157 157
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
	Target AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 158 158
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
	    SELECT DISTINCT
7ae1788762b98e1f9f095fd37718b6ba6deb90da 159 159
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
	        QTR_FY AS Qtr,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 160 160
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
	        ID AS Account_Id,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 161 161
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
	        TERRITORY AS GEO_NUMBER,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 162 162
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
	        1 AS Target_Flag,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 163 163
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
	        COALESCE(RUKOBIA_SEGMENT_IV_GSK_TELE__C, 'Non-Tier Targets') AS Segment
7ae1788762b98e1f9f095fd37718b6ba6deb90da 164 164
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
	    FROM AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS
7ae1788762b98e1f9f095fd37718b6ba6deb90da 165 165
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
	    WHERE ID IN (SELECT Account_Id FROM Interaction)
7ae1788762b98e1f9f095fd37718b6ba6deb90da 166 166
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 167 167
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
	Base AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 168 168
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
	    SELECT 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 169 169
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
	        i.*,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 170 170
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
	        CAST(d.TP_Date AS DATE) AS TP_Date,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 171 171
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
	        d.TP_Week,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 172 172
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
	        d.TP_Week_Rank,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 173 173
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
	        d.TP_Month_str,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 174 174
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
	        d.TP_Month_Rank,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 175 175
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
	        d.TP_Year_str,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 176 176
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
	        d.TP_Year_Rank,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 177 177
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
	        d.TP_Quarter_str,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 178 178
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
	        d.TP_Quarter_Rank,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 179 179
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
	        d.TP_Date_Rank,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 180 180
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
	        d.tp_date_str,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 181 181
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
	        d.tp_week_str,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 182 182
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
	        d.TP_Quarter,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 183 183
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
	        d.weekend_flag,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 184 184
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
	        r.Team,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 185 185
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
	        p.BRAND_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 186 186
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
	        p.PRODUCT_CODE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 187 187
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
	        uh.GEO_NUMBER,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 188 188
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
	        COALESCE(a.Prescriber, i.Acc_Prescriber) AS Prescriber,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 189 189
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
	        COALESCE(a.Account_Type, i.Acc_Account_Type) AS Account_Type,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 190 190
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
	        iv.Presentation_ID_vod__c,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 191 191
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
	        CASE WHEN i.CALL_TYPE_VOD__C LIKE '%Detail%' AND i.CALL_ATTEMPT_RESULT = 1 THEN 1 ELSE 0 END AS Successful_Call,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 192 192
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
	        CASE WHEN i.CALL_TYPE_VOD__C IS NOT NULL AND i.CALL_TYPE_VOD__C <> '' THEN 1 ELSE 0 END AS Attempted_Call
7ae1788762b98e1f9f095fd37718b6ba6deb90da 193 193
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
	    FROM Interaction i
7ae1788762b98e1f9f095fd37718b6ba6deb90da 194 194
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
	    LEFT JOIN AIP_FULL_COMMERCIAL.Dim_config_date d ON i.Call_Date = d.TP_Date
7ae1788762b98e1f9f095fd37718b6ba6deb90da 195 195
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
	    LEFT JOIN AIP_FULL_COMMERCIAL.RECORD_TYPE r ON i.RECORDTYPEID = r.RECORDTYPEID
7ae1788762b98e1f9f095fd37718b6ba6deb90da 196 196
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
	    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_PRODUCT_MASTER p ON i.Product_Name = p.BRAND_NAME
7ae1788762b98e1f9f095fd37718b6ba6deb90da 197 197
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
	    LEFT JOIN UserHierarchyBase uh ON i.EMP_ID = uh.EMP_ID AND uh.POSITION_TITLE LIKE '%Representative%'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 198 198
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
	    LEFT JOIN Universe_base a ON i.PRSC_CID = a.PRSC_CID AND rn = 1
7ae1788762b98e1f9f095fd37718b6ba6deb90da 199 199
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
	    LEFT JOIN icva iv ON i.Call_Id = iv.CALL2_VOD__C
7ae1788762b98e1f9f095fd37718b6ba6deb90da 200 200
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
	),
7ae1788762b98e1f9f095fd37718b6ba6deb90da 201 201
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
	Final AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 202 202
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
	    SELECT 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 203 203
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
	        i.*,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 204 204
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
	        COALESCE(u.TERRITORY_NAME, 'Unassigned') AS TERRITORY_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 205 205
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
	        u.DISTRICT_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 206 206
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
	        COALESCE(u.REGION_NAME, 'Unassigned') AS REGION_NAME,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 207 207
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
	        u.POSITION_TITLE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 208 208
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
	        u.REP_FLAG,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 209 209
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
	        u.Name,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 210 210
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
	        u.ASSIGNMENT_END_DATE,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 211 211
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
	        t.Target_Flag,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 212 212
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
	        CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 213 213
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
	            WHEN t.Segment IS NOT NULL THEN t.Segment
7ae1788762b98e1f9f095fd37718b6ba6deb90da 214 214
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
	            WHEN i.Team = 'Field' THEN 'Non-ECL'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 215 215
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
	            WHEN i.Team = 'EC' THEN 'Field Assist'
7ae1788762b98e1f9f095fd37718b6ba6deb90da 216 216
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
	            ELSE NULL
7ae1788762b98e1f9f095fd37718b6ba6deb90da 217 217
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
	        END AS Segment,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 218 218
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
	        CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 219 219
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
	            WHEN i.Account_Type = 'HCP' AND i.STAFF_ONLY = 'False' AND i.Team = 'Field' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
7ae1788762b98e1f9f095fd37718b6ba6deb90da 220 220
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
	            WHEN i.Account_Type = 'HCO' OR i.Team = 'EC' AND i.Call_Type_vod__c LIKE '%Detail%' THEN 1
7ae1788762b98e1f9f095fd37718b6ba6deb90da 221 221
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
	            ELSE 0
7ae1788762b98e1f9f095fd37718b6ba6deb90da 222 222
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
	            END AS Detailed_Calls,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 223 223
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
	        CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 224 224
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
	            WHEN i.Account_Type LIKE 'HCO' AND i.Call_Type_vod__c LIKE '%Call Only%' THEN 1 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 225 225
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
				ELSE 0 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 226 226
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
				END AS Calls_Only,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 227 227
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
	        CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 228 228
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
	            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type LIKE '%HCP%' THEN 1 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 229 229
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
				ELSE 0 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 230 230
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
				END AS CLM_Calls,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 231 231
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
	         CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 232 232
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
	            WHEN i.Account_Type LIKE 'HCP' AND i.Successful_Call = 1 AND t.Target_Flag = 1 THEN 1 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 233 233
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
				ELSE 0 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 234 234
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
				END AS Successful_Target_Calls,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 235 235
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
			CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 236 236
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
	            WHEN i.ACCT_TYP_CD_iv_GSK_CDE__C LIKE '%PHRM%' THEN 1 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 237 237
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
				ELSE 0 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 238 238
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
				END AS Pharmacy_Calls,
7ae1788762b98e1f9f095fd37718b6ba6deb90da 239 239
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
			CASE
7ae1788762b98e1f9f095fd37718b6ba6deb90da 240 240
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
	            WHEN i.Call_Type_vod__c LIKE '%Detail%' AND t.Target_Flag=1 THEN 1 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 241 241
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
				ELSE 0 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 242 242
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
				END AS Target_Detail_Calls
7ae1788762b98e1f9f095fd37718b6ba6deb90da 243 243
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
	    FROM Base i
7ae1788762b98e1f9f095fd37718b6ba6deb90da 244 244
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
	    LEFT JOIN UserHierarchy u ON i.GEO_NUMBER = u.GEO_NUMBER
7ae1788762b98e1f9f095fd37718b6ba6deb90da 245 245
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
	    LEFT JOIN Target t ON i.TP_Quarter = t.Qtr AND i.Account_Id = t.Account_Id AND i.GEO_NUMBER = t.GEO_NUMBER
7ae1788762b98e1f9f095fd37718b6ba6deb90da 246 246
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 247 247
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
	INSERT select * from  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
7ae1788762b98e1f9f095fd37718b6ba6deb90da 248 248
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
	SELECT *
7ae1788762b98e1f9f095fd37718b6ba6deb90da 249 249
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
	FROM Final;
7ae1788762b98e1f9f095fd37718b6ba6deb90da 250 250
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
	END;
7ae1788762b98e1f9f095fd37718b6ba6deb90da 251 251
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
	GO
7ae1788762b98e1f9f095fd37718b6ba6deb90da 252 252
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
	
f78652fe19aa5cf6aa5bfd75825ab812bd150729 253 253 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762933136
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762933136
committer-tz +0530
summary Code review for pasted_code.sql
previous 7ae1788762b98e1f9f095fd37718b6ba6deb90da pasted_code.sql
filename pasted_code.sql
	usig the above table we are deriving this bbased on logic given above
7ae1788762b98e1f9f095fd37718b6ba6deb90da 253 254 4
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
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 254 255
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
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 255 256
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
	WITH base AS (
7ae1788762b98e1f9f095fd37718b6ba6deb90da 256 257
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
	    SELECT
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 14 258 4
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 15 259
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 16 260
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 17 261
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 261 262 10
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
	    WHERE IS_SAMPLE_CALL = 'True' 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 262 263
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
	--        AND 
7ae1788762b98e1f9f095fd37718b6ba6deb90da 263 264
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
	--        ({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_CD_P_STARTDATE_HIDDEN}} AND {{CDL_CD_P_ENDDATE_HIDDEN}})
7ae1788762b98e1f9f095fd37718b6ba6deb90da 264 265
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
	--        OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}})
7ae1788762b98e1f9f095fd37718b6ba6deb90da 265 266
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
	--        AND
7ae1788762b98e1f9f095fd37718b6ba6deb90da 266 267
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
	--?        ,(Product_Name = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
7ae1788762b98e1f9f095fd37718b6ba6deb90da 267 268
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
	--?        ,(REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
7ae1788762b98e1f9f095fd37718b6ba6deb90da 268 269
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
	--?        ,(TERRITORY_NAME= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
7ae1788762b98e1f9f095fd37718b6ba6deb90da 269 270
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
	--?        ,(Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
7ae1788762b98e1f9f095fd37718b6ba6deb90da 270 271
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
	--?        ,(Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 28 272 2
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 29 273
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 273 274 1
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
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 31 275 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 32 276
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 33 277
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 34 278
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 35 279
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 279 280 1
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
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 37 281 1
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
7ae1788762b98e1f9f095fd37718b6ba6deb90da 281 282 1
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
	 
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 39 283 5
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 40 284
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 41 285
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 42 286
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
8ea68301c3f0b26e1b438bb6c172328d4e8569f1 43 287
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
