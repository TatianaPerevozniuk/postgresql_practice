--Составиим тестовую БД PostgreSQL—

CREATE TABLE department (
id SMALLSERIAL PRIMARY KEY,
    name varchar(100) NOT NULL
);

INSERT INTO department
(name)
VALUES
('D1'),
('D2'),
('D3'),
('D4'),
('D5');
 

CREATE TABLE employee (
    id bigint
     constraint employee_pk
      primary key,
    department_id integer
     constraint employee_department_id_fk
      references department,
    cheef_id integer
     constraint employee_cheef_id_fk
      references employee,
    name varchar(100) NOT NULL,
    salary numeric NOT NULL CONSTRAINT positive_salary CHECK (salary > 0)
        
);

--DROP TABLE  IF EXISTS  department;
--DROP TABLE  IF EXISTS  employee cascade;
INSERT INTO employee
(id, department_id, cheef_id, name, salary)
VALUES
(1,1,1,'Walter Garcia', 600000.0),
(2,1,1,'Walter Garcia', 600000.0),
(3,2,3,'Matthew Schmidt',300000.0),
(4,2,3,'Matthew Schmidt',300000.0),
(5,1,1,'John Moore',540000.0),
(6,1,5,'Howard Collins',540000.0),
(7,1,5,'Pamela Miller',540000.0),
(8,1,5,'Ruth Padilla',345000.0),
(9,1,6,'Zina Wollins',768000.0),
(10,2,3,'Vicki Banks',236000.0),
(11,2,3,'Vicki Lawrence',789000.0),
(12,2,11,'Karen Lawrence',347000.0),
(13,2,11,'Jill Jones',637000.0),
(14,2,13,'Kurw Robinzon',532000.0),
(15,3,15,'Ronald Sanchez',867000.0),
(16,3,15,'Kurt Robinson',362000.0),
(17,3,16,'Melissa Miller',467000.0),
(18,3,16,'Louise Nichols',563000.0),
(19,4,19,'Jennifer Berry',724000.0),
(20,4,19,'Melissa Miller',560000.0),
(21,4,20,'Mary Allen',340000.0),
(22,4,20,'Michelle Anderson',830000.0),
(23,4,21,'Julia Neal',320000.0),
(24,4,21,'Dorothy Taylor',450000.0),
(25,4,22,'John Hill',480000.0),
(26,5,26,'Judith Smith',350000.0),
(27,5,26,'Beverly Johnson',260000.0),
(28,5,27,'Anthony Hall',130000.0),
(29,5,28,'Shirley Bell',230000.0),
(30,5,28,'Wolly Ortiz',180000.0),
(31,5,28,'Gina Hopkins',210000.0);

select * from department;
select * from employee;
--------------------------------------------------------------------------------------
--Задачи и решения:

/*Задание 1
Для каждого департамента (DEPARTMEN) вывести его название и имя сотрудника (EMPLOYEE), 
работающего в этом департаменте и имеющего максимальный id.
*/
SELECT DISTINCT ON (d.id) 
    d.name AS department_name, 
    e.name AS employee_name, 
    e.id AS employee_id
FROM employee e
JOIN department d ON e.department_id = d.id
ORDER BY d.id, e.id DESC;


/*Задание 2
Вывести названия департаментов (DEPARTMEN), в которых нет сотрудников, 
имеющих в имени букв z и w одновременно без учета регистра.
*/
SELECT d.name
FROM department d
WHERE NOT EXISTS (
    SELECT 1
    FROM employee e
    WHERE e.department_id = d.id
      AND LOWER(e.name) LIKE '%z%'
      AND LOWER(e.name) LIKE '%w%'
)
ORDER BY d.name;

 
/*Задание 3
Для каждого сотрудника вывести его имя, а также имя и зарплату другого сотрудника, 
имеющего следующую по возрастанию зарплату и работающего в том же отделе. 
В случае, если таких сотрудников несколько, вывести данные по сотруднику, имеющему максимальный id.
*/
/*
select e.department_id, e.id, e.name, e.salary,
lead(e.name) over(partition by e.department_id order by e.salary, e.id desc) next_employer,
lead(e.salary) over(partition by e.department_id order by e.salary) next_salary
from employee e ;
*/

with d_rank as (
	SELECT  DISTINCT ON (e.department_id, e.salary) e.department_id, e.id, e.name as next_employer, e.salary as next_salary,
	DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary) AS d_salary_rank
	FROM employee e
	ORDER BY  e.department_id, e.salary,  e.id DESC
),
s_rank as (
	SELECT e.department_id, e.id, e.name as employer, e.salary,
	DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary) AS salary_rank
	FROM employee e
	ORDER BY  e.department_id, e.salary,  e.id DESC
)

select s.department_id, s.id, s.employer, s.salary, d.next_employer, d.next_salary
from s_rank s
join d_rank d on d.department_id = s.department_id and d.d_salary_rank = s.salary_rank + 1



/*Задание 4
Вывести список названий департаментов, суммарную зарплату сотрудников в департаменте и кумулятивную сумму 
суммарных зарплат по департаментам в порядке возрастания суммарной зарплаты.
*/
SELECT 
    d.name AS department_name, 
    SUM(e.salary) AS total_salary, 
    SUM(SUM(e.salary)) OVER (ORDER BY SUM(e.salary)) AS cumulative_salary
FROM employee e
JOIN department d ON e.department_id = d.id
GROUP BY d.name
ORDER BY total_salary;

/*Задание 5
Написать запрос, удаляющий из таблицы сотрудников дубли, т.е. всех, кроме одного, имеющих одинаковое имя, 
начальника, зарплату, и департамент. Оставить сотрудника с минимальным id.
*/

delete from employee e
where e.id not in (select min(id) id from employee
       group by department_id, cheef_id, name, salary);

/*Задание 6
Написать запрос, переводящий начальника с выбранным id и всех его подчиненных 
по всей иерархии подчинения в другой департамент. Например, имея иерархию 
группа – отдел –управление – департамент, необходимо учитывать, 
что для директора департамента нужно выбирать всех работников департамента, 
а не только прямых подчиненных, начальников управлений.
*/

BEGIN;

WITH RECURSIVE subordinates AS (
    -- Выбираем начальника
    SELECT e.id, e.cheef_id, e.name, e.department_id
    FROM employee e
    WHERE e.id = 20  -- ID начальника
    UNION ALL    
    -- Рекурсивно выбираем всех подчиненных начальника
    SELECT e.id, e.cheef_id, e.name, e.department_id
    FROM employee e
    INNER JOIN subordinates s ON s.id = e.cheef_id
)  
UPDATE employee
SET department_id = 1  -- Новый департамент в который переводим сотрудников
WHERE id IN (SELECT id FROM subordinates)
AND department_id <> 1;  -- Исключаем уже переведенных. предотвращает ненужные обновления строк, уже находящихся в целевом департаменте.

-- Проверяем результат
SELECT * FROM employee
WHERE department_id IN (1, 4)
ORDER BY department_id;

ROLLBACK; -- Откат изменений