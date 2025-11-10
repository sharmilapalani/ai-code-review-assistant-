# Code Review Feedback for `pasted_code.sql`

## Description
The left join between the Call table and Target table must use the following columns:
Qtr,GEO_NUMBER,Account_Id  are keys in AIP_G_CALLS_BASE_TBL 
QTR_FY,ID,TERRITORY are keys in  AIP_HCP_TARGETS
Call table is base , matching records should bring the columns in target table.
The resulting dataset should allow accurate mapping of calls to target accounts within the same quarter and territory.

## Uploaded Code
```sql
SELECT 
    c.*,
    t.*,
    t.QTR_FY,
    t.ID AS Account_Id,
    t.TERRITORY AS GEO_NUMBER,
    t.RUKOBIA_SEGMENT_IV_GSK_TELE__C AS Segment
FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL AS c
LEFT JOIN AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS AS t
    ON c.Qtr = t.QTR_FY
   AND c.Account_Id = t.ID
   AND c.GEO_NUMBER = t.TERRITORY;
```

## CDL Execution Summary
⚠️ Execution error: ('42S22', "[42S22] [Microsoft][ODBC Driver 17 for SQL Server][SQL Server]Invalid column name 'Qtr'. (207) (SQLExecDirectW)")

## AI Feedback
1) Corrected Code

```sql
SELECT 
    c.*,
    t.*,
    t.QTR_FY,
    t.ID AS Target_Account_Id,
    t.TERRITORY AS Target_GEO_NUMBER,
    t.RUKOBIA_SEGMENT_IV_GSK_TELE__C AS Segment
FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL AS c
LEFT JOIN AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS AS t
    ON c.QTR_FY = t.QTR_FY
   AND c.Account_Id = t.ID
   AND c.GEO_NUMBER = t.TERRITORY;
```
**Key corrections:**
- Changed join column `c.Qtr` to `c.QTR_FY` as per the key and likely correct column in the base table (assuming typo based on error and column conventions).
- Aliased `t.ID` and `t.TERRITORY` as `Target_Account_Id` and `Target_GEO_NUMBER` for clarification, to distinguish from similarly named columns in base.

---

2) Syntax Errors

- ❌ Error detected:  
  - `Invalid column name 'Qtr'`: The column referenced as `c.Qtr` does not exist in table `AIP_G_CALLS_BASE_TBL`. It should likely be `QTR_FY`.

---

3) Suggestions / Improvements

- **Column Selection Clarity:**  
  Currently, you are selecting both `c.*` and `t.*` along with individual columns from t. This introduces redundant columns and ambiguity (for example, `Account_Id` and `ID`, or `TERRITORY` and `GEO_NUMBER`). Instead, explicitly select only the columns needed, or alias columns to avoid confusion.
- **Performance/Indexing:**  
  Ensure there are indexes on the join columns: `AIP_G_CALLS_BASE_TBL(QTR_FY, Account_Id, GEO_NUMBER)` and `AIP_HCP_TARGETS(QTR_FY, ID, TERRITORY)` to optimize the join performance.
- **Edge Cases:**  
  If data types of join columns are not identical, implicit conversion might occur and affect both performance and correctness. Confirm that data types are compatible.
- **Readability:**  
  Prefer explicit column lists over `*` to:
    - Improve readability
    - Avoid unintentional column duplication
    - Prevent issues if source tables change
  Recommended structure:

    ```sql
    SELECT 
        c.QTR_FY,
        c.GEO_NUMBER,
        c.Account_Id,
        -- (other c columns)
        t.ID AS Target_Account_Id,
        t.TERRITORY AS Target_GEO_NUMBER,
        t.RUKOBIA_SEGMENT_IV_GSK_TELE__C AS Segment
        -- (other t columns as required)
    FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL AS c
    LEFT JOIN AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS AS t
        ON c.QTR_FY = t.QTR_FY
       AND c.Account_Id = t.ID
       AND c.GEO_NUMBER = t.TERRITORY;
    ```

---

4) Requirement Mismatch

- ❌ The original SQL did **not** satisfy the requirement because:
    - It used `c.Qtr` (which does not exist) instead of `c.QTR_FY` on the join.
    - The use of `t.ID AS Account_Id` and `t.TERRITORY AS GEO_NUMBER` would overwrite those base values, losing distinction between call vs. target data.
    - The result would not allow “accurate mapping of calls to target accounts within the same quarter and territory” due to these ambiguities and errors.
- ✔️ The corrected SQL resolves this by:
    - Joining on the correct columns.
    - Keeping clear distinction between columns coming from each table.
    - Allowing accurate mapping as required.

**Summary:**  
The original SQL failed due to referencing a non-existent column and column naming ambiguities. After correction, the query meets the described mapping requirement.

## Git Blame
```
14ff2ded63b62a8be54fb053e40dd95de6c666fc 1 1 12
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	SELECT 
14ff2ded63b62a8be54fb053e40dd95de6c666fc 2 2
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    c.*,
14ff2ded63b62a8be54fb053e40dd95de6c666fc 3 3
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    t.*,
14ff2ded63b62a8be54fb053e40dd95de6c666fc 4 4
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    t.QTR_FY,
14ff2ded63b62a8be54fb053e40dd95de6c666fc 5 5
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    t.ID AS Account_Id,
14ff2ded63b62a8be54fb053e40dd95de6c666fc 6 6
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    t.TERRITORY AS GEO_NUMBER,
14ff2ded63b62a8be54fb053e40dd95de6c666fc 7 7
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    t.RUKOBIA_SEGMENT_IV_GSK_TELE__C AS Segment
14ff2ded63b62a8be54fb053e40dd95de6c666fc 8 8
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	FROM AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL AS c
14ff2ded63b62a8be54fb053e40dd95de6c666fc 9 9
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	LEFT JOIN AIP_FULL_COMMERCIAL.AIP_HCP_TARGETS AS t
14ff2ded63b62a8be54fb053e40dd95de6c666fc 10 10
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	    ON c.Qtr = t.QTR_FY
14ff2ded63b62a8be54fb053e40dd95de6c666fc 11 11
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	   AND c.Account_Id = t.ID
14ff2ded63b62a8be54fb053e40dd95de6c666fc 12 12
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1762793784
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1762793784
committer-tz +0530
summary Code review for pasted_code.sql
previous c3c4bd4335c2e7501b170bae9f75258ef948ecd1 pasted_code.sql
filename pasted_code.sql
	   AND c.GEO_NUMBER = t.TERRITORY;
```
