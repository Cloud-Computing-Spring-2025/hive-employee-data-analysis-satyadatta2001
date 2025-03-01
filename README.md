Hive - Employee and Department Data Analysis
This repository contains Hive queries and scripts to analyze employee and department data using partitioned tables in Hive. The analysis includes querying employee records, department details, and performing various operations such as filtering, aggregation, and joins.

#### Objectives:
Load Data:

Load the employees.csv into a temporary Hive table.
Transform the data and insert it into a partitioned table based on the department.
Load the departments.csv into a Hive table.
Data Analysis:

Perform various analysis tasks such as filtering employees, calculating average salary by department, identifying employees on a specific project, and more.
Optimization and Partitioning:

Partition the data to improve query performance, especially when working with large datasets.
Generate Reports:

Generate reports on employee and department analysis, output the results to files, and save them for review or further analysis.
Problem Statement:
You are provided with two datasets:

employees.csv – Contains information about employees (e.g., employee ID, name, age, job role, salary, etc.).
departments.csv – Contains information about departments (e.g., department ID, name, and location).
You need to perform the following tasks:

Load the datasets into Hive.
Transform the data into the appropriate format and partition it for optimization.
Perform multiple queries to analyze employee and department data (e.g., calculate average salary by department, identify employees working on specific projects, etc.).
Write the output of your queries to files for review.

## Setup and Execution

### 1. **Start the Hadoop Cluster**
To initiate the Hadoop cluster, execute:

```bash
docker compose up -d
```

### 2. **Load Data into Temporary Hive Tables**

The employees_temp and departments_temp tables are being created as temporary tables to store raw data before transforming them into partitioned tables.
```sql
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
```

### 3. **Create Partitioned Table and Insert Data**

A partitioned table is created for employee data based on the department column to optimize querying.

```sql
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
```

### 4. **Querying the Data**

#### Retrieve employees who joined after 2015

The query filters employees based on their join_date to retrieve those who joined after 2015.

```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Retrieve Employees Who Joined After 2015'
SELECT * FROM employees_partitioned WHERE year(join_date) > 2015;
```

#### Find the average salary per department

The query groups employees by their department and calculates the average salary.

```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Average Salary by Department'
SELECT department, AVG(salary) AS avg_salary FROM employees_partitioned GROUP BY department;
```

#### Identify employees working on the 'Alpha' project
Filters the dataset for employees who are assigned to the "Alpha" project.

```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Identify Employees in 'Alpha' Project'
SELECT * FROM employees_partitioned WHERE project = 'Alpha';
```

#### Count employees per job role
Groups employees by their job role and counts the number of employees in each role.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Count Employees by Job Role'
SELECT job_role, COUNT(*) AS count FROM employees_partitioned GROUP BY job_role;
```

#### Retrieve employees earning above the average salary of their department
Using a subquery, the average salary per department is calculated, and employees earning more than the department’s average are selected.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Retrieve Employees Earning Above Department Average Salary'
SELECT * FROM employees_partitioned e 
WHERE salary > (SELECT AVG(salary) FROM employees_partitioned WHERE department = e.department);
```

#### Find the department with the highest number of employees
Groups by department and orders the results to identify the department with the highest number of employees.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Department with Highest Number of Employees'
SELECT department, COUNT(*) AS employee_count 
FROM employees_partitioned GROUP BY department 
ORDER BY employee_count DESC LIMIT 1;
```

#### Exclude employees with null values
 Filters out employees with missing values in any column to ensure complete data is used in analysis.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Exclude Employees with NULL Values'
SELECT * FROM employees_partitioned WHERE emp_id IS NOT NULL AND name IS NOT NULL AND age IS NOT NULL 
AND job_role IS NOT NULL AND salary IS NOT NULL AND project IS NOT NULL AND join_date IS NOT NULL AND department IS NOT NULL;
```

#### Join employees and departments to get department locations
 Join employees and department tables to display employee details along with department location.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Join Employees with Departments for Location Details'
SELECT e.*, d.location FROM employees_partitioned e INNER JOIN departments_temp d ON e.department = d.department_name;
```

#### Rank employees within each department by salary
Uses a ranking function to rank employees within each department based on their salary in descending order.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Rank Employees Within Each Department by Salary'
SELECT emp_id, name, department, salary, 
RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank 
FROM employees_partitioned;
```

#### Find the top 3 highest-paid employees in each department

 A subquery is used to rank employees by salary, and only the top 3 employees are selected for each department.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/Find Top 3 Highest-Paid Employees in Each Department'
SELECT * FROM (
    SELECT emp_id, name, department, salary, 
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank 
    FROM employees_partitioned
) ranked WHERE rank <= 3;
```


### 5. **Access Hive Server Container**
the command opens an interactive Bash session inside the Hive server container:

1. Use the following command to copy from HDFS:
    ```bash
    docker exec -it hive-server /bin/bash
    ```
### 6. **Copy Output from HDFS to Local Filesystem (Inside the Container)**

This retrieves the query results stored in HDFS (/user/hive/output) and saves them to /tmp/output inside the container:

```bash
hdfs dfs -get /user/hive/output /tmp/output
```
### 7. **Exit the Container**
   ```bash
   exit
   ```
### 8. **Check the Current Working Directory on the Host**
Displays the present working directory, which is where you want to copy the output files.
```bash
pwd
```
### 9. **Copy Output Files from the Docker Container to the Host Machine**
This command copies the /tmp/output directory from the Hive server container to your project directory on the host machine

```bash
docker cp hive-server:/tmp/output /........(Keep the link that is generated after compiling pwd)

```
### 10. **Commit it into GitHub**


```bash
git add.
git commit -m ""
git push origin main
```



### Challenges Faced

1. **Configuring Hive for Partitioning:** Setting up partitioned tables in Hive involved a detailed configuration process to ensure that data was efficiently partitioned and queries were executed with optimal performance.

2. **Handling Large Data Volumes:** Managing and processing large datasets in Hive required careful consideration of performance optimizations to ensure smooth data operations and reduce execution time.

3. **Issues with Dynamic Partitioning:** Enabling and correctly implementing dynamic partitioning for the insertion of data into partitioned tables presented challenges, particularly in handling partition creation and data loading effectively.

4. **Optimizing Join Performance:** Joining large datasets, such as `employees_partitioned` with `departments_temp`, required careful optimization techniques to improve the performance and speed of the join operations.

5. **Extracting Relevant Insights:** Designing and fine-tuning queries to generate meaningful insights, such as salary comparisons and departmental rankings, was an iterative process that involved testing and refining the queries for accuracy and efficiency.

