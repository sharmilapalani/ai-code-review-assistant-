# Code Review Feedback for `Test1.sql`

## Description
Display the Student details from Student Table name starts with M

## Uploaded Code
```sql
SELECT * FROM Customer WHERE CustomerID > 30;

```

## AI Feedback
1. Corrected Code

```sql
SELECT * FROM Student WHERE Name LIKE 'M%';
```

2. Syntax Errors

✅ No syntax errors found in the uploaded code.

3. Suggestions / Improvements

- Always use table and column names that correctly reflect your data model and requirements.
- Prefer explicit column names (e.g., `SELECT Name, Age, ...`) over `SELECT *` for better performance and readability unless all columns are truly needed.
- When filtering text, consider case sensitivity (may depend on SQL dialect/collation).
- Add comments to clarify query intent, especially for business-critical logic.

4. Requirement Mismatch

**Requirement:**  
Display the Student details from Student Table where the name starts with 'M'.

**Uploaded Code:**  
```sql
SELECT * FROM Customer WHERE CustomerID > 30;
```
- **Mismatch Analysis:**  
  - Table: Used `Customer` instead of `Student`.
  - Filter: Used `CustomerID > 30` instead of filtering names starting with 'M'.
  - Column: No logic to check names starting with 'M'.

**Conclusion:**  
❌ The submitted code does NOT satisfy the requirement.

**Corrected Query:**  
```sql
SELECT * FROM Student WHERE Name LIKE 'M%';
```

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