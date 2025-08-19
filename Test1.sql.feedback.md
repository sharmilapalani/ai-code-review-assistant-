# Code Review Feedback for `Test1.sql`

## Description
Select all the Student Details where the Name Starts with A

## Uploaded Code
```sql
SELECT * FROM Customer WHERE CustomerID > 30;

```

## AI Feedback
1. Corrected Code

```sql
SELECT * FROM Student WHERE Name LIKE 'A%';
```

2. Syntax Errors

✅ No syntax errors found in the submitted code.

3. Suggestions / Improvements

- **Table Name:** Use the correct table (`Student`) instead of `Customer`, as per the requirement.
- **Filter Logic:** Use a `LIKE 'A%'` filter on the `Name` column to get names starting with ‘A’, as requested, instead of filtering by `CustomerID`.
- **Readability:** Consider specifying column names instead of `SELECT *` for better performance and maintainability.
- **SQL Semicolon:** Optional, but using semicolon at the end of SQL statement is standard practice (already present in the submission).

4. Requirement Mismatch

**Mismatch Identified:**  
The provided code selects records from the `Customer` table where `CustomerID > 30`. The requirement is to select all student details from the `Student` table where the `Name` starts with 'A'.

**Correction:**  
Your code does **not** meet the requirement. Please use:

```sql
SELECT * FROM Student WHERE Name LIKE 'A%';
```

This will retrieve all student records where the `Name` begins with 'A', satisfying the stated requirement.

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