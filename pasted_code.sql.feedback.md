# Code Review Feedback for `pasted_code.sql`

## Description
We have a created a stored procedure and created  few Flag columns in it. Pls chk those flag columns satisfy the logic given below.
 
 
Detailed_Calls: Count of Call Id where Call_type = Detail /Group Detail from AIP_CRM_CALL_ACTIVITY to (Accounts , where IS_PERSON_ACCOUNT=1 from the AIP_ACCOUNT_DETAILS able) Group by AIP_ACCOUNT_TARGETS.SEGMENT = Tier1, Tier2, Tier3 and Non-Target when the SEGMENT is Null.
Pharmacy_Calls: Pharmacy call is HCO Calls. Sum of Calls (AIP_CRM_CALL_ACTIVITY join with AIP_ACCOUNT_DETAILS based on AIP_CRM_CALL_ACTIVITY.ACCOUNT_VOD__C= AIP_ACCOUNT_DETAILS.ID , where AIP_ACCOUNT_DETAILS.IS_PERSON_ACCOUNT=0) for the selected time period.
CLM_Calls: Count distinct CALL2_VOD_C by joining AIP_CRM_CALL_ACTIVITY and AIP_CRM_CALL_KEYMESSAGE based on CALL2_VOD_C.AIP_CRM_CALL_KEYMESSAGE =Id.AIP_CRM_CALL_ACTIVITY for the selected time period.

## Uploaded Code
```sql
Stored Procedure
ALTER PROC [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL] AS

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

	NATION VARCHAR(20),

    Prescriber VARCHAR(200),

    Account_Type VARCHAR(10),

    Presentation_ID_vod__c VARCHAR(10),

    Successful_Call INT,

    Attempted_Call INT,

    TERRITORY_NAME VARCHAR(100),

    DISTRICT_NAME VARCHAR(100),

    REGION_NAME VARCHAR(100),

	REGION_ID VARCHAR(50),

    POSITION_TITLE VARCHAR(100),

    REP_FLAG INT,

    Name VARCHAR(200),

    ASSIGNMENT_END_DATE DATE,

    Target_Flag INT,

    Segment VARCHAR(50),

    Detailed_Calls INT,

	Calls_Only INT,

	CLM_Calls INT,

	Successful_Target_Calls INT,

	Pharmacy_Calls INT,

	Target_Detail_Calls INT,

	Total_Calls INT

);

WITH Interaction AS (

    SELECT 

        i.ACCOUNT_VOD__C AS Account_Id,

        i.ID,

        i.ID AS Call_Id,

        i.STATUS_VOD__C,

        CAST(i.CALL_DATE_VOD__C AS DATE) AS Call_Date,

        Product_Name,

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
 
    SELECT *
 
    FROM (
 
        SELECT
 
            EMP_ID,
 
            GEO_NAME AS TERRITORY_NAME,
 
            ' ' AS DISTRICT_NAME,
 
            PARENT_GEO_NAME AS REGION_NAME,

            PARENT_GEO_Number AS REGION_ID,
 
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
 
            END AS Name,
 
            ROW_NUMBER() OVER (
 
                PARTITION BY EMP_ID
 
                ORDER BY ASSIGNMENT_END_DATE DESC
 
            ) AS rn
 
        FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT

    ) x

    WHERE rn = 1

),

UserHierarchy AS (

    SELECT * FROM UserHierarchyBase

    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%') AND REP_FLAG = 1

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

		'NATION' AS NATION,

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

            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type = 'HCP'  THEN 1 

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

			END AS Target_Detail_Calls,

			1 AS Total_Calls 

    FROM Base i

    LEFT JOIN UserHierarchy u ON i.GEO_NUMBER = u.GEO_NUMBER

    LEFT JOIN Target t ON i.TP_Quarter = t.Qtr AND i.Account_Id = t.Account_Id AND i.GEO_NUMBER = t.GEO_NUMBER

)

INSERT INTO  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL

SELECT *

FROM Final;

END;
 
 
Region  code:
EXEC AIP_FULL_COMMERCIAL.SPLoad_AIP_G_CALLS_BASE_TBL
WITH 
base_tbl AS (SELECT dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod, dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank FROM AIP_FULL_COMMERCIAL.Dim_config_date dt
        WHERE (
            (({{CDL_FA_TPC}} <> 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
         OR ({{CDL_FA_TPC}} = 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
              )
        GROUP BY dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str,dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank
    ), 
call_base AS (select {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}},Segment,ID,tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
    WHERE (
            (({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
         OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
?         AND (Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
?         AND (Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
?         AND (REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
?         AND (GEO_NUMBER= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
?         AND (GEO_NUMBER= {{CDL_FA_REP}} or {{CDL_FA_REP}} = 'ALL' )
?         AND (PRODUCT_CODE = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
?         AND ({{CDL_FA_ACTIVITY_CALLS}} = 1)
           ))
SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_PAR_GEO}} AS Geography,Segment FROM base_tbl T
LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_PAR_GEO}},B.Segment
 
UNION
 
SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM base_tbl T
LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_GEO}},B.Segment
 
UNION
 
SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_PAR_GEO}} AS Geography ,Segment FROM call_base
GROUP BY {{CDL_FA_ROLE_PAR_GEO}},Segment
 
UNION
 
SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM call_base
GROUP BY {{CDL_FA_ROLE_GEO}},Segment
```

## CDL Execution Summary
Execution blocked: Detected restricted keyword 'delete' in SQL. Execution blocked for safety.

## AI Feedback
1) Corrections  
- Pharmacy_Calls logic should use IS_PERSON_ACCOUNT = 0 from AIP_ACCOUNT_DETAILS, not ACCT_TYP_CD_iv_GSK_CDE__C LIKE '%PHRM%'.  
- Detailed_Calls/CLM_Calls flag logic needs to strictly match the specified call type and join/group conditions.  
- Replace DROP TABLE with TRUNCATE TABLE for safety and performance.

2) Errors  
- Major error: Pharmacy_Calls does not implement HCO (IS_PERSON_ACCOUNT = 0) logic; uses incorrect field and condition.  
- Major error: Detailed_Calls does not group by SEGMENT appropriately, and SEGMENT NULL logic is missing.  
- No errors found for CLM_Calls calculation, except for missing distinct grouping.

3) Quick Suggestions  
- Use explicit GROUP BY and aggregation for flag columns instead of CASE for scalars.  
- Consider CTEs or temp tables for segment grouping and call calculation for better clarity and performance.  
- Validate all JOIN conditions; indexes recommended for frequently joined columns.

## Git Blame
```
520f43fa19d62c68d6b1e0d9b42abea857f116dc 1 1 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	Stored Procedure
520f43fa19d62c68d6b1e0d9b42abea857f116dc 2 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	ALTER PROC [AIP_FULL_COMMERCIAL].[SPLoad_AIP_G_CALLS_BASE_TBL] AS
7ae1788762b98e1f9f095fd37718b6ba6deb90da 2 3 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 4 4 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	BEGIN
520f43fa19d62c68d6b1e0d9b42abea857f116dc 5 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 6 6
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    SET NOCOUNT ON;
520f43fa19d62c68d6b1e0d9b42abea857f116dc 7 7
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 8 8
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
520f43fa19d62c68d6b1e0d9b42abea857f116dc 9 9
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 10 10
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    -- 1. DELETE EXISTING DATA
520f43fa19d62c68d6b1e0d9b42abea857f116dc 11 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 12 12
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
520f43fa19d62c68d6b1e0d9b42abea857f116dc 13 13
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 14 14
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	   DROP TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
9b7c0b0b0edaacdf590aee2f458e7b0ee4aee87c 3 15 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762933459
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762933459
committer-tz +0530
summary Code review for pasted_code.sql
previous 3e62b71746f91040e169bbfae59bdc9e9f5e53c1 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 11 16 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 17 17 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 12 18 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 19 19 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 13 20 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 21 21 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 14 22 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 23 23 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 15 24 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 25 25 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 16 26 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 27 27 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 17 28 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 29 29 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 18 30 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 31 31 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 19 32 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 33 33 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 20 34 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 35 35 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 21 36 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 37 37 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 22 38 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 39 39 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 23 40 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 41 41 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 24 42 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 43 43 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 25 44 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 45 45 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 26 46 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 47 47 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 27 48 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 49 49 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 28 50 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 51 51 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 29 52 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 53 53 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 30 54 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 55 55 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 31 56 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 57 57 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 32 58 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 59 59 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 33 60 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 61 61 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 34 62 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 63 63 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 35 64 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 65 65 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 36 66 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 67 67 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 37 68 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 69 69 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 38 70 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 71 71 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 39 72 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 73 73 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 40 74 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 75 75 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 41 76 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 77 77 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 42 78 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 79 79 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 43 80 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 81 81 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 44 82 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 83 83 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 45 84 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 85 85 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 46 86 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 87 87 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 47 88 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 89 89 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 48 90 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 91 91 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 49 92 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 93 93 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 50 94 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 95 95 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 51 96 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 97 97 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 52 98 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 99 99 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 53 100 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 101 101 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 102 102
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		NATION VARCHAR(20),
520f43fa19d62c68d6b1e0d9b42abea857f116dc 103 103
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 54 104 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 105 105 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 55 106 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 107 107 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 56 108 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 109 109 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 57 110 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 111 111 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 58 112 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 113 113 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 59 114 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 115 115 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 60 116 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 117 117 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 61 118 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 119 119 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 120 120
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		REGION_ID VARCHAR(50),
520f43fa19d62c68d6b1e0d9b42abea857f116dc 121 121
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 62 122 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 123 123 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 63 124 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 125 125 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 64 126 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 127 127 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 65 128 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 129 129 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 66 130 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 131 131 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 67 132 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 133 133 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 68 134 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 135 135 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 70 136 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 137 137 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 138 138
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		CLM_Calls INT,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 139 139
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 71 140 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 141 141 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 72 142 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 143 143 4
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 144 144
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		Target_Detail_Calls INT,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 145 145
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 146 146
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		Total_Calls INT
7ae1788762b98e1f9f095fd37718b6ba6deb90da 74 147 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 75 148
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 149 149 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 76 150 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 151 151 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 77 152 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 153 153 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 78 154 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 155 155 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 79 156 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 157 157 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 80 158 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 159 159 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 81 160 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 161 161 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 82 162 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 163 163 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 164 164
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        Product_Name,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 165 165
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 84 166 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 167 167 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 85 168 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 169 169 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 86 170 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 171 171 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 87 172 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 173 173 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 88 174 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 175 175 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 89 176 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 177 177 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 90 178 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 179 179 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 91 180 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 181 181 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 92 182 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 183 183 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 93 184 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 185 185 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 94 186 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 187 187 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 95 188 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 189 189 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 96 190 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 191 191 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 97 192 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 193 193 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 98 194 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 195 195 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 99 196 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 197 197 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 100 198 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 199 199 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 101 200 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 201 201 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 102 202 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 203 203 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 103 204 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 205 205 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 104 206 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 207 207 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 105 208 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 209 209 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 106 210 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 211 211 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 107 212 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 213 213 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 108 214 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 215 215 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 109 216 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 217 217 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 110 218 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 219 219 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 111 220 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 221 221 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 112 222 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 223 223 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 113 224 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 225 225 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 114 226 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 227 227 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 115 228 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 229 229 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 116 230 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 231 231 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 117 232 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 233 233 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 118 234 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 235 235 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 119 236 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 237 237 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 120 238 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 239 239 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 121 240 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 241 241 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 122 242 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 243 243 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 123 244 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 245 245 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 124 246 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 247 247 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 125 248 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 249 249 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 126 250 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 251 251 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 127 252 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 253 253 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 128 254 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 255 255 53
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 256 256
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    SELECT *
520f43fa19d62c68d6b1e0d9b42abea857f116dc 257 257
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 258 258
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    FROM (
520f43fa19d62c68d6b1e0d9b42abea857f116dc 259 259
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 260 260
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        SELECT
520f43fa19d62c68d6b1e0d9b42abea857f116dc 261 261
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 262 262
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            EMP_ID,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 263 263
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 264 264
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            GEO_NAME AS TERRITORY_NAME,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 265 265
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 266 266
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ' ' AS DISTRICT_NAME,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 267 267
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 268 268
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            PARENT_GEO_NAME AS REGION_NAME,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 269 269
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 270 270
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            PARENT_GEO_Number AS REGION_ID,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 271 271
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 272 272
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            POSITION_TITLE,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 273 273
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 274 274
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            GEO_NUMBER,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 275 275
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 276 276
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            CAST(ASSIGNMENT_END_DATE AS DATE) AS ASSIGNMENT_END_DATE,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 277 277
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 278 278
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            REP_FLAG,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 279 279
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 280 280
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            TEAM,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 281 281
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 282 282
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            CASE
520f43fa19d62c68d6b1e0d9b42abea857f116dc 283 283
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 284 284
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                WHEN ASSIGNMENT_END_DATE < GETDATE()
520f43fa19d62c68d6b1e0d9b42abea857f116dc 285 285
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 286 286
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                    AND (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
520f43fa19d62c68d6b1e0d9b42abea857f116dc 287 287
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 288 288
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                    THEN 'Vacant'
520f43fa19d62c68d6b1e0d9b42abea857f116dc 289 289
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 290 290
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                ELSE FULL_NAME
520f43fa19d62c68d6b1e0d9b42abea857f116dc 291 291
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 292 292
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            END AS Name,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 293 293
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 294 294
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ROW_NUMBER() OVER (
520f43fa19d62c68d6b1e0d9b42abea857f116dc 295 295
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 296 296
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                PARTITION BY EMP_ID
520f43fa19d62c68d6b1e0d9b42abea857f116dc 297 297
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 298 298
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                ORDER BY ASSIGNMENT_END_DATE DESC
520f43fa19d62c68d6b1e0d9b42abea857f116dc 299 299
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 300 300
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ) AS rn
520f43fa19d62c68d6b1e0d9b42abea857f116dc 301 301
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 302 302
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT
520f43fa19d62c68d6b1e0d9b42abea857f116dc 303 303
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 304 304
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ) x
520f43fa19d62c68d6b1e0d9b42abea857f116dc 305 305
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 306 306
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE rn = 1
520f43fa19d62c68d6b1e0d9b42abea857f116dc 307 307
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 147 308 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 309 309 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 148 310 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 311 311 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 149 312 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 313 313 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 314 314
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%') AND REP_FLAG = 1
520f43fa19d62c68d6b1e0d9b42abea857f116dc 315 315
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 151 316 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 317 317 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 152 318 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 319 319 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 153 320 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 321 321 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 154 322 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 323 323 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 155 324 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 325 325 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 156 326 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 327 327 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 157 328 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 329 329 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 158 330 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 331 331 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 159 332 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 333 333 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 160 334 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 335 335 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 161 336 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 337 337 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 162 338 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 339 339 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 163 340 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 341 341 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 164 342 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 343 343 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 165 344 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 345 345 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 166 346 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 347 347 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 167 348 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 349 349 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 168 350 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 351 351 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 169 352 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 353 353 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 170 354 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 355 355 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 171 356 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 357 357 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 172 358 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 359 359 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 173 360 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 361 361 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 174 362 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 363 363 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 175 364 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 365 365 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 176 366 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 367 367 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 177 368 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 369 369 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 178 370 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 371 371 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 179 372 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 373 373 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 180 374 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 375 375 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 181 376 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 377 377 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 182 378 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 379 379 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 183 380 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 381 381 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 184 382 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 383 383 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 185 384 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 385 385 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 186 386 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 387 387 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 187 388 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 389 389 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 390 390
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
			'NATION' AS NATION,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 391 391
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 188 392 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 393 393 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 189 394 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 395 395 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 190 396 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 397 397 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 191 398 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 399 399 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 192 400 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 401 401 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 193 402 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 403 403 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 194 404 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 405 405 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 195 406 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 407 407 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 196 408 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 409 409 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 197 410 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 411 411 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 198 412 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 413 413 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 199 414 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 415 415 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 200 416 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 417 417 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 201 418 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 419 419 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 202 420 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 421 421 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 203 422 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 423 423 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 204 424 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 425 425 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 205 426 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 427 427 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 206 428 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 429 429 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 207 430 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 431 431 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 208 432 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 433 433 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 209 434 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 435 435 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 210 436 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 437 437 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 211 438 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 439 439 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 212 440 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 441 441 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 213 442 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 443 443 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 214 444 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 445 445 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 215 446 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 447 447 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 216 448 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 449 449 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 217 450 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 451 451 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 218 452 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 453 453 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 219 454 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 455 455 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 220 456 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 457 457 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 221 458 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 459 459 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 222 460 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 461 461 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 223 462 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 463 463 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 224 464 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 465 465 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 225 466 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 467 467 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 226 468 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 469 469 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 227 470 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 471 471 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 472 472
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type = 'HCP'  THEN 1 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 473 473
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 229 474 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 475 475 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 230 476 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 477 477 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 231 478 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 479 479 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 232 480 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 481 481 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 233 482 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 483 483 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 234 484 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 485 485 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 235 486 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 487 487 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 236 488 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 489 489 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 237 490 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 491 491 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 238 492 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 493 493 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 239 494 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 495 495 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 240 496 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 497 497 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 241 498 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 499 499 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 500 500
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
				END AS Target_Detail_Calls,
520f43fa19d62c68d6b1e0d9b42abea857f116dc 501 501
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 502 502
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
				1 AS Total_Calls 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 503 503
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 243 504 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 505 505 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 244 506 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 507 507 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 245 508 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 509 509 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 246 510 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
520f43fa19d62c68d6b1e0d9b42abea857f116dc 511 511 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 512 512
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	INSERT INTO  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
520f43fa19d62c68d6b1e0d9b42abea857f116dc 513 513
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
7ae1788762b98e1f9f095fd37718b6ba6deb90da 248 514 1
author a241983
author-mail <a241983@LWPG02MPMR>
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
9b7c0b0b0edaacdf590aee2f458e7b0ee4aee87c 243 515 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762933459
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762933459
committer-tz +0530
summary Code review for pasted_code.sql
previous 3e62b71746f91040e169bbfae59bdc9e9f5e53c1 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 516 516 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	FROM Final;
7ae1788762b98e1f9f095fd37718b6ba6deb90da 252 517 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	
520f43fa19d62c68d6b1e0d9b42abea857f116dc 518 518 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	END;
520f43fa19d62c68d6b1e0d9b42abea857f116dc 519 519
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 520 520
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 521 521 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763458520
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763458520
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 520f43fa19d62c68d6b1e0d9b42abea857f116dc pasted_code.sql
filename pasted_code.sql
	Region  code:
520f43fa19d62c68d6b1e0d9b42abea857f116dc 522 522 32
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	EXEC AIP_FULL_COMMERCIAL.SPLoad_AIP_G_CALLS_BASE_TBL
520f43fa19d62c68d6b1e0d9b42abea857f116dc 523 523
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	WITH 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 524 524
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	base_tbl AS (SELECT dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod, dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank FROM AIP_FULL_COMMERCIAL.Dim_config_date dt
520f43fa19d62c68d6b1e0d9b42abea857f116dc 525 525
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        WHERE (
520f43fa19d62c68d6b1e0d9b42abea857f116dc 526 526
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            (({{CDL_FA_TPC}} <> 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
520f43fa19d62c68d6b1e0d9b42abea857f116dc 527 527
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	         OR ({{CDL_FA_TPC}} = 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
520f43fa19d62c68d6b1e0d9b42abea857f116dc 528 528
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	              )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 529 529
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        GROUP BY dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str,dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank
520f43fa19d62c68d6b1e0d9b42abea857f116dc 530 530
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ), 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 531 531
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	call_base AS (select {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}},Segment,ID,tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
520f43fa19d62c68d6b1e0d9b42abea857f116dc 532 532
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE (
520f43fa19d62c68d6b1e0d9b42abea857f116dc 533 533
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            (({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
520f43fa19d62c68d6b1e0d9b42abea857f116dc 534 534
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	         OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
520f43fa19d62c68d6b1e0d9b42abea857f116dc 535 535
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 536 536
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 537 537
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 538 538
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (GEO_NUMBER= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 539 539
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (GEO_NUMBER= {{CDL_FA_REP}} or {{CDL_FA_REP}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 540 540
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (PRODUCT_CODE = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
520f43fa19d62c68d6b1e0d9b42abea857f116dc 541 541
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND ({{CDL_FA_ACTIVITY_CALLS}} = 1)
520f43fa19d62c68d6b1e0d9b42abea857f116dc 542 542
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	           ))
520f43fa19d62c68d6b1e0d9b42abea857f116dc 543 543
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_PAR_GEO}} AS Geography,Segment FROM base_tbl T
520f43fa19d62c68d6b1e0d9b42abea857f116dc 544 544
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
520f43fa19d62c68d6b1e0d9b42abea857f116dc 545 545
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_PAR_GEO}},B.Segment
520f43fa19d62c68d6b1e0d9b42abea857f116dc 546 546
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 547 547
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	UNION
520f43fa19d62c68d6b1e0d9b42abea857f116dc 548 548
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 549 549
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM base_tbl T
520f43fa19d62c68d6b1e0d9b42abea857f116dc 550 550
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
520f43fa19d62c68d6b1e0d9b42abea857f116dc 551 551
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_GEO}},B.Segment
520f43fa19d62c68d6b1e0d9b42abea857f116dc 552 552
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 553 553
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	UNION
7ae1788762b98e1f9f095fd37718b6ba6deb90da 273 554 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 555 555 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_PAR_GEO}} AS Geography ,Segment FROM call_base
520f43fa19d62c68d6b1e0d9b42abea857f116dc 556 556
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY {{CDL_FA_ROLE_PAR_GEO}},Segment
7ae1788762b98e1f9f095fd37718b6ba6deb90da 279 557 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 558 558 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	UNION
7ae1788762b98e1f9f095fd37718b6ba6deb90da 281 559 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762932957
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762932957
committer-tz +0530
summary Code review for pasted_code.sql
previous 8578b69fcc1ddd78f4cd68cfe3fc3853a5b644d7 pasted_code.sql
filename pasted_code.sql
	 
520f43fa19d62c68d6b1e0d9b42abea857f116dc 560 560 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM call_base
520f43fa19d62c68d6b1e0d9b42abea857f116dc 561 561
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1763457177
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1763457177
committer-tz +0530
summary Code review for pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY {{CDL_FA_ROLE_GEO}},Segment
```
