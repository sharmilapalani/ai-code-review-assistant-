# Code Review Feedback for `Test1.sql`

## Description
Display all the records from Customer Table

## Uploaded Code
```sql
SELECT * FROM Customer WHERE CustomerID > 30;

```

## AI Feedback
1. Corrected Code

```sql
SELECT * FROM Customer;
```

2. Syntax Errors

✅ No syntax errors found.

3. Suggestions / Improvements

- Avoid using unnecessary WHERE clauses unless specified by the requirements.
- Use `SELECT *` only when you need all columns; for production code, explicitly list columns to improve maintainability.
- Ensure table and column names are consistently capitalized, according to your SQL style guide.

4. Requirement Mismatch

**Requirement:** Display all the records from Customer Table.

**Uploaded Code:**  
```sql
SELECT * FROM Customer WHERE CustomerID > 30;
```
- The provided code only displays records where `CustomerID > 30`.  
- This does **not** display **all** the records from the `Customer` table.

**Conclusion:** The code does **not** satisfy the requirement.  
**Correction:** Remove the `WHERE` clause as shown in the corrected code above.

## Git Blame Info
```
663ed254d74a44da03dca7dfe86e8af8e7e8879c 1 1 1
author a241983
author-mail <a241983@LWPG02MPMR>
author-time 1755507877
author-tz +0530
committer a241983
committer-mail <a241983@LWPG02MPMR>
committer-time 1755507877
committer-tz +0530
summary Code review for Test1.sql
previous 84ec716bd47db31c8efa0013af66c642d2b6f99d Test1.sql
filename Test1.sql
	SELECT * FROM Customer WHERE CustomerID > 30;
```