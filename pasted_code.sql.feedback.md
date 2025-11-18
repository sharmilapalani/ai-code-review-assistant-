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
 
 
Region  code
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
Execution blocked: Detected restricted keyword 'alter' in SQL. Execution blocked for safety.

## AI Feedback
1) Corrections  
- Change `DROP TABLE` to `TRUNCATE TABLE` or add `IF OBJECT_ID` check.  
- Add missing semicolons after statements.  
- Remove the extraneous final region code and CTE logic not part of the procedure.

2) Errors  
- Major: Using `DROP TABLE` permanently removes the structure, causing errors on next run.  
- Major: Ambiguous column aliases and inconsistent casing (e.g., `ACCT_TYP_CD_iv_GSK_CDE__C`).  
- No errors found for core logic in flag columns.

3) Quick Suggestions  
- Use consistent naming conventions for columns and aliases.  
- Add explicit column lists in INSERT for maintainability and to avoid future errors.  
- Simplify the nested CTEs where possible for clarity.

Example correction:
```sql
IF OBJECT_ID('AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL') IS NOT NULL
    TRUNCATE TABLE AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL;
-- Then do not recreate the table unless structure change needed.
```

## Git Blame
```
0000000000000000000000000000000000000000 1 1 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	Stored Procedure
0000000000000000000000000000000000000000 2 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	
0000000000000000000000000000000000000000 4 4 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	BEGIN
0000000000000000000000000000000000000000 5 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 6 6
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    SET NOCOUNT ON;
0000000000000000000000000000000000000000 7 7
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 8 8
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
0000000000000000000000000000000000000000 9 9
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 10 10
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    -- 1. DELETE EXISTING DATA
0000000000000000000000000000000000000000 11 11
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 12 12
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ------------------------------------------------------------
0000000000000000000000000000000000000000 13 13
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 14 14
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 17 17 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 19 19 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 21 21 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 23 23 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 25 25 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 27 27 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 29 29 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 31 31 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 33 33 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 35 35 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 37 37 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 39 39 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 41 41 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 43 43 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 45 45 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 47 47 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 49 49 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 51 51 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 53 53 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 55 55 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 57 57 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 59 59 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 61 61 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 63 63 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 65 65 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 67 67 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 69 69 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 71 71 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 73 73 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 75 75 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 77 77 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 79 79 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 81 81 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 83 83 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 85 85 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 87 87 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 89 89 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 91 91 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 93 93 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 95 95 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 97 97 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 99 99 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 101 101 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 102 102
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		NATION VARCHAR(20),
0000000000000000000000000000000000000000 103 103
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 105 105 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 107 107 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 109 109 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 111 111 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 113 113 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 115 115 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 117 117 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 119 119 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 120 120
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		REGION_ID VARCHAR(50),
0000000000000000000000000000000000000000 121 121
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 123 123 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 125 125 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 127 127 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 129 129 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 131 131 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 133 133 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 135 135 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 137 137 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 138 138
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		CLM_Calls INT,
0000000000000000000000000000000000000000 139 139
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 141 141 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 143 143 4
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 144 144
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
		Target_Detail_Calls INT,
0000000000000000000000000000000000000000 145 145
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 146 146
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 149 149 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 151 151 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 153 153 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 155 155 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 157 157 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 159 159 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 161 161 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 163 163 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 164 164
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        Product_Name,
0000000000000000000000000000000000000000 165 165
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 167 167 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 169 169 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 171 171 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 173 173 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 175 175 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 177 177 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 179 179 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 181 181 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 183 183 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 185 185 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 187 187 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 189 189 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 191 191 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 193 193 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 195 195 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 197 197 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 199 199 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 201 201 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 203 203 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 205 205 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 207 207 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 209 209 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 211 211 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 213 213 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 215 215 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 217 217 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 219 219 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 221 221 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 223 223 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 225 225 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 227 227 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 229 229 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 231 231 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 233 233 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 235 235 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 237 237 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 239 239 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 241 241 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 243 243 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 245 245 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 247 247 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 249 249 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 251 251 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 253 253 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 255 255 53
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 256 256
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    SELECT *
0000000000000000000000000000000000000000 257 257
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 258 258
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    FROM (
0000000000000000000000000000000000000000 259 259
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 260 260
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        SELECT
0000000000000000000000000000000000000000 261 261
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 262 262
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            EMP_ID,
0000000000000000000000000000000000000000 263 263
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 264 264
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            GEO_NAME AS TERRITORY_NAME,
0000000000000000000000000000000000000000 265 265
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 266 266
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ' ' AS DISTRICT_NAME,
0000000000000000000000000000000000000000 267 267
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 268 268
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            PARENT_GEO_NAME AS REGION_NAME,
0000000000000000000000000000000000000000 269 269
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 270 270
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            PARENT_GEO_Number AS REGION_ID,
0000000000000000000000000000000000000000 271 271
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 272 272
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            POSITION_TITLE,
0000000000000000000000000000000000000000 273 273
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 274 274
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            GEO_NUMBER,
0000000000000000000000000000000000000000 275 275
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 276 276
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            CAST(ASSIGNMENT_END_DATE AS DATE) AS ASSIGNMENT_END_DATE,
0000000000000000000000000000000000000000 277 277
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 278 278
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            REP_FLAG,
0000000000000000000000000000000000000000 279 279
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 280 280
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            TEAM,
0000000000000000000000000000000000000000 281 281
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 282 282
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            CASE
0000000000000000000000000000000000000000 283 283
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 284 284
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                WHEN ASSIGNMENT_END_DATE < GETDATE()
0000000000000000000000000000000000000000 285 285
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 286 286
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                    AND (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%')
0000000000000000000000000000000000000000 287 287
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 288 288
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                    THEN 'Vacant'
0000000000000000000000000000000000000000 289 289
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 290 290
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                ELSE FULL_NAME
0000000000000000000000000000000000000000 291 291
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 292 292
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            END AS Name,
0000000000000000000000000000000000000000 293 293
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 294 294
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ROW_NUMBER() OVER (
0000000000000000000000000000000000000000 295 295
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 296 296
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                PARTITION BY EMP_ID
0000000000000000000000000000000000000000 297 297
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 298 298
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	                ORDER BY ASSIGNMENT_END_DATE DESC
0000000000000000000000000000000000000000 299 299
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 300 300
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            ) AS rn
0000000000000000000000000000000000000000 301 301
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 302 302
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        FROM AIP_FULL_COMMERCIAL.AIP_SALES_REP_ALIGNMENT
0000000000000000000000000000000000000000 303 303
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 304 304
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ) x
0000000000000000000000000000000000000000 305 305
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 306 306
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE rn = 1
0000000000000000000000000000000000000000 307 307
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 309 309 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 311 311 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 313 313 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 314 314
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE (TEAM <> 'Field' OR POSITION_TITLE LIKE '%Sales Representatives%') AND REP_FLAG = 1
0000000000000000000000000000000000000000 315 315
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 317 317 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 319 319 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 321 321 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 323 323 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 325 325 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 327 327 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 329 329 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 331 331 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 333 333 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 335 335 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 337 337 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 339 339 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 341 341 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 343 343 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 345 345 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 347 347 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 349 349 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 351 351 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 353 353 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 355 355 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 357 357 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 359 359 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 361 361 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 363 363 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 365 365 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 367 367 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 369 369 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 371 371 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 373 373 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 375 375 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 377 377 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 379 379 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 381 381 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 383 383 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 385 385 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 387 387 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 389 389 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 390 390
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
			'NATION' AS NATION,
0000000000000000000000000000000000000000 391 391
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 393 393 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 395 395 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 397 397 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 399 399 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 401 401 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 403 403 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 405 405 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 407 407 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 409 409 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 411 411 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 413 413 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 415 415 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 417 417 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 419 419 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 421 421 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 423 423 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 425 425 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 427 427 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 429 429 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 431 431 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 433 433 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 435 435 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 437 437 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 439 439 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 441 441 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 443 443 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 445 445 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 447 447 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 449 449 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 451 451 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 453 453 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 455 455 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 457 457 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 459 459 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 461 461 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 463 463 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 465 465 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 467 467 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 469 469 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 471 471 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 472 472
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            WHEN i.Presentation_ID_vod__c <> '' AND i.Account_Type = 'HCP'  THEN 1 
0000000000000000000000000000000000000000 473 473
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 475 475 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 477 477 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 479 479 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 481 481 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 483 483 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 485 485 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 487 487 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 489 489 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 491 491 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 493 493 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 495 495 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 497 497 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 499 499 5
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 500 500
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
				END AS Target_Detail_Calls,
0000000000000000000000000000000000000000 501 501
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 502 502
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
				1 AS Total_Calls 
0000000000000000000000000000000000000000 503 503
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 505 505 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 507 507 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 509 509 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
0000000000000000000000000000000000000000 511 511 3
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	
0000000000000000000000000000000000000000 512 512
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	INSERT INTO  AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
0000000000000000000000000000000000000000 513 513
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	
0000000000000000000000000000000000000000 516 516 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	
0000000000000000000000000000000000000000 518 518 36
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	END;
0000000000000000000000000000000000000000 519 519
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 520 520
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 521 521
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	Region  code
0000000000000000000000000000000000000000 522 522
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	EXEC AIP_FULL_COMMERCIAL.SPLoad_AIP_G_CALLS_BASE_TBL
0000000000000000000000000000000000000000 523 523
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	WITH 
0000000000000000000000000000000000000000 524 524
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	base_tbl AS (SELECT dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod, dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank FROM AIP_FULL_COMMERCIAL.Dim_config_date dt
0000000000000000000000000000000000000000 525 525
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        WHERE (
0000000000000000000000000000000000000000 526 526
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            (({{CDL_FA_TPC}} <> 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
0000000000000000000000000000000000000000 527 527
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	         OR ({{CDL_FA_TPC}} = 'Custom' AND tp_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
0000000000000000000000000000000000000000 528 528
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	              )
0000000000000000000000000000000000000000 529 529
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	        GROUP BY dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str,dt.tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_rank
0000000000000000000000000000000000000000 530 530
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    ), 
0000000000000000000000000000000000000000 531 531
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	call_base AS (select {{CDL_FA_ROLE_PAR_GEO}},{{CDL_FA_ROLE_GEO}},Segment,ID,tp_{{CDL_FA_TPC_OVERTIME_HIDDEN}}_str AS TimePeriod FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL
0000000000000000000000000000000000000000 532 532
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	    WHERE (
0000000000000000000000000000000000000000 533 533
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	            (({{CDL_FA_TPC}} <> 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE_HIDDEN}} AND {{CDL_FA_ENDDATE_HIDDEN}})
0000000000000000000000000000000000000000 534 534
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	         OR ({{CDL_FA_TPC}} = 'Custom' AND Call_Date BETWEEN {{CDL_FA_STARTDATE}} AND {{CDL_FA_ENDDATE}}))
0000000000000000000000000000000000000000 535 535
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (Team = {{CDL_FA_TEAM}} or {{CDL_FA_TEAM}} = 'ALL' )
0000000000000000000000000000000000000000 536 536
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (Segment= {{CDL_FA_SEG}} or {{CDL_FA_SEG}} = 'ALL' )
0000000000000000000000000000000000000000 537 537
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (REGION_NAME = {{CDL_FA_REG}} or {{CDL_FA_REG}} = 'ALL' )
0000000000000000000000000000000000000000 538 538
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (GEO_NUMBER= {{CDL_FA_TERR}} or {{CDL_FA_TERR}} = 'ALL' )
0000000000000000000000000000000000000000 539 539
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (GEO_NUMBER= {{CDL_FA_REP}} or {{CDL_FA_REP}} = 'ALL' )
0000000000000000000000000000000000000000 540 540
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND (PRODUCT_CODE = {{CDL_FA_PROD}} or {{CDL_FA_PROD}} = 'ALL' )
0000000000000000000000000000000000000000 541 541
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	?         AND ({{CDL_FA_ACTIVITY_CALLS}} = 1)
0000000000000000000000000000000000000000 542 542
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	           ))
0000000000000000000000000000000000000000 543 543
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_PAR_GEO}} AS Geography,Segment FROM base_tbl T
0000000000000000000000000000000000000000 544 544
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
0000000000000000000000000000000000000000 545 545
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_PAR_GEO}},B.Segment
0000000000000000000000000000000000000000 546 546
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 547 547
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	UNION
0000000000000000000000000000000000000000 548 548
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 549 549
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT B.ID) AS Calls,T.TimePeriod,B.{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM base_tbl T
0000000000000000000000000000000000000000 550 550
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	LEFT JOIN call_base B ON T.TimePeriod = B.TimePeriod
0000000000000000000000000000000000000000 551 551
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY T.TimePeriod, B.{{CDL_FA_ROLE_GEO}},B.Segment
0000000000000000000000000000000000000000 552 552
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	 
0000000000000000000000000000000000000000 553 553
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	 
0000000000000000000000000000000000000000 555 555 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_PAR_GEO}} AS Geography ,Segment FROM call_base
0000000000000000000000000000000000000000 556 556
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	 
0000000000000000000000000000000000000000 558 558 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
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
	 
0000000000000000000000000000000000000000 560 560 2
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	SELECT COUNT(DISTINCT ID) AS Calls,NULL AS TimePeriod,{{CDL_FA_ROLE_GEO}} AS Geography,Segment FROM call_base
0000000000000000000000000000000000000000 561 561
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1763457177
author-tz +0530
committer Not Committed Yet
committer-mail <not.committed.yet>
committer-time 1763457177
committer-tz +0530
summary Version of pasted_code.sql from pasted_code.sql
previous 39fa14b6be6d7fd81c4ec5c1175df05cf56d7af9 pasted_code.sql
filename pasted_code.sql
	GROUP BY {{CDL_FA_ROLE_GEO}},Segment
```
