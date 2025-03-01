CREATE TABLE employees_temp (
    emp_id INT,
    name STRING,
    age INT,
    job_role STRING,
    salary INT,
    project STRING,
    join_date STRING,
    department STRING
) ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

LOAD DATA INPATH 'hdfs:///user/hive/employees.csv' INTO TABLE employees_temp;

CREATE TABLE departments_temp (
    dept_id INT,
    department_name STRING,
    location STRING
) ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

LOAD DATA INPATH 'hdfs:///user/hive/departments.csv' INTO TABLE departments_temp;


SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = non-strict;

CREATE TABLE employees_partitioned (
    emp_id INT,
    name STRING,
    age INT,
    job_role STRING,
    salary INT,
    project STRING,
    join_date STRING
) 
PARTITIONED BY (department STRING)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS PARQUET;

-- Add multiple partitions in a single command
ALTER TABLE employees_partitioned 
ADD PARTITION (department='HR')
PARTITION (department='Engineering')
PARTITION (department='Marketing')
PARTITION (department='Finance')
PARTITION (department='Sales');


INSERT OVERWRITE TABLE employees_partitioned PARTITION (department)
SELECT emp_id, name, age, job_role, salary, project, join_date, department 
FROM employees_temp;

SELECT DISTINCT department FROM employees_partitioned;


INSERT OVERWRITE DIRECTORY '/user/hive/output/Retrieve Employees Who Joined After 2015'
SELECT * FROM employees_partitioned 
WHERE YEAR(FROM_UNIXTIME(UNIX_TIMESTAMP(join_date, 'yyyy-MM-dd'))) > 2015;


INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Average Salary by Department'
SELECT department, AVG(salary) AS avg_salary 
FROM employees_partitioned 
GROUP BY department;

INSERT OVERWRITE DIRECTORY '/user/hive/output/Identify Employees in Alpha Project'
SELECT * FROM employees_partitioned WHERE project = 'Alpha';

INSERT OVERWRITE DIRECTORY '/user/hive/output/Count Employees by Job Role'
SELECT job_role, COUNT(*) AS employee_count 
FROM employees_partitioned 
GROUP BY job_role;


INSERT OVERWRITE DIRECTORY '/user/hive/output/Retrieve Employees Earning Above Department Average Salary'
SELECT * FROM employees_partitioned e 
WHERE salary > (SELECT AVG(salary) FROM employees_partitioned WHERE department = e.department);



INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Department with Highest Number of Employees'
SELECT department, COUNT(*) AS employee_count 
FROM employees_partitioned 
GROUP BY department 
ORDER BY employee_count DESC;



INSERT OVERWRITE DIRECTORY '/user/hive/output/Exclude Employees with NULL Values'

SELECT * FROM employees_partitioned 
WHERE emp_id IS NOT NULL 
AND name IS NOT NULL 
AND age IS NOT NULL 
AND job_role IS NOT NULL 
AND salary IS NOT NULL 
AND project IS NOT NULL 
AND join_date IS NOT NULL 
AND department IS NOT NULL;


INSERT OVERWRITE DIRECTORY '/user/hive/output/Join Employees with Departments for Location Details'
SELECT e.*, d.location 
FROM employees_partitioned e 
JOIN departments_temp d 
ON e.department = d.department_name;


INSERT OVERWRITE DIRECTORY '/user/hive/output/Rank Employees Within Each Department by Salary'
SELECT emp_id, name, department, salary, 
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank 
FROM employees_partitioned;

INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Top 3 Highest-Paid Employees in Each Department'
SELECT emp_id, name, department, salary, rank
FROM (
    SELECT emp_id, name, department, salary, 
           DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank
    FROM employees_partitioned
) AS ranked_employees
WHERE rank <= 3;
