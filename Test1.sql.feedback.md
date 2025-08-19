# Code Review Feedback for `Test1.sql`

## Description
Select all the Employees where the Salary between 20000 and 50000

## Uploaded Code
```sql
SELECT * FROM Customer WHERE CustomerID > 30;

```

## AI Feedback
1. Corrected Code

```sql
SELECT * FROM Employees WHERE Salary BETWEEN 20000 AND 50000;
```

2. Syntax Errors

✅ No syntax errors found.

3. Suggestions / Improvements

- Use explicit column names instead of `SELECT *` where possible for performance and clarity.
- Ensure the table name matches the intended entity (“Employees” as per the requirement, not “Customer”).
- Format keywords in uppercase for readability and maintainability.

Example best practice:

```sql
SELECT EmployeeID, EmployeeName, Salary
FROM Employees
WHERE Salary BETWEEN 20000 AND 50000;
```

4. Requirement Mismatch

**Mismatch Explanation:**  
- The uploaded code selects rows from the `Customer` table based on `CustomerID > 30`, which is unrelated to selecting employees or salary.
- The requirement specifically asks to select all employees with a salary between 20,000 and 50,000, which the uploaded query does NOT address.

**Corrected Query:**  
```sql
SELECT * FROM Employees WHERE Salary BETWEEN 20000 AND 50000;
```

**Conclusion:**  
The uploaded code does **not satisfy** the requirement. Please use the corrected query above.

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