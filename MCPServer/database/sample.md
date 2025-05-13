# Sample Data

The database contains sample employee records for demonstration purposes.

## Example Queries

### Get all employees

```sql
SELECT * FROM employees;
```

### Get employees by department

```sql
SELECT * FROM employees WHERE department = 'Engineering';
```

### Get average salary by department

```sql
SELECT department, AVG(salary) as avg_salary 
FROM employees 
GROUP BY department
ORDER BY avg_salary DESC;
```

