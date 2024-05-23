DROP SCHEMA if exists lab06 CASCADE;
CREATE SCHEMA lab06;
SET search_path = 'lab06';

CREATE TABLE if not exists students 
(
	id integer not null primary key,
	first varchar(50),
	last varchar(50),
	sex char(1)
);
CREATE TABLE if not exists discipline
(
	id  integer not null primary key,
	descr varchar(50)
);
CREATE TABLE if not exists exam
(
	id integer not null primary key,
	discip integer not null, 
	ts timestamp,
	FOREIGN KEY (discip) REFERENCES discipline (id)
);
CREATE TABLE if not exists mark 
(
	id integer not null primary key,
	exam integer not null, 
	stud integer not null, 
	res integer,
	FOREIGN KEY (exam) REFERENCES exam (id),
	FOREIGN KEY (stud) REFERENCES students (id)
);

CREATE SEQUENCE discip_id;

INSERT INTO discipline (id, descr) VALUES (nextval('discip_id'), 'Math');
INSERT INTO discipline (id, descr) VALUES (nextval('discip_id'), 'Physics');
INSERT INTO discipline (id, descr) VALUES (nextval('discip_id'), 'Computer Science');
INSERT INTO discipline (id, descr) VALUES (nextval('discip_id'), 'History');
INSERT INTO discipline (id, descr) VALUES (nextval('discip_id'), 'Foreign Language');

CREATE SEQUENCE exam_id;

INSERT INTO exam (id, discip, ts) SELECT nextval('exam_id'), currval('discip_id') - random() * (5 -1), 
TIMESTAMP '2021-09-01 00:00:00' + random() * (TIMESTAMP '2022-07-01 00:00:00' - TIMESTAMP '2022-09-01 00:00:00') 
FROM generate_series(1, 20);

CREATE EXTENSION if not exists file_fdw;
CREATE SERVER if not exists file_server FOREIGN DATA WRAPPER file_fdw;


CREATE FOREIGN TABLE if not exists firstfemalename(femname varchar) SERVER file_server 
   OPTIONS (filename 'C:/lab06Files/name-first-female.csv', format  'csv');
CREATE FOREIGN TABLE if not exists firstmalename(malename varchar) SERVER file_server 
   OPTIONS (filename 'C:/lab06Files/name-first-male.csv', format  'csv');
CREATE FOREIGN TABLE if not exists lastnameALL(lastAll varchar) SERVER file_server 
   OPTIONS (filename 'C:/lab06Files/name-last-all.csv', format  'csv');

CREATE SEQUENCE stud_id;

CREATE OR REPLACE PROCEDURE add_random_student() AS 
$$
DECLARE
    random_gender CHAR;
    random_first_name VARCHAR(50);
    random_last_name VARCHAR(50);
    i INTEGER := 1;
BEGIN
    LOOP
        -- Select random gender ('F' for female, 'M' for male)
        random_gender := CASE WHEN floor(random() * 2) = 0 THEN 'F' ELSE 'M' END;

        -- Select a random first name based on the gender
        IF random_gender = 'F' THEN
            SELECT femname INTO random_first_name FROM firstfemalename ORDER BY random() LIMIT 1;
        ELSE
            SELECT malename INTO random_first_name FROM firstmalename ORDER BY random() LIMIT 1;
        END IF;

        -- Select a random last name
        SELECT lastAll INTO random_last_name FROM lastnameALL ORDER BY random() LIMIT 1;

        -- Insert the random student record into the students table
INSERT INTO students (id, first, last, sex)
VALUES (nextval('stud_id'), random_first_name, random_last_name, random_gender);

        i := i + 1;

        -- Exit the loop after 100 records
        EXIT WHEN i > 100;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL add_random_student();




CREATE SEQUENCE mark_id;

CREATE OR REPLACE PROCEDURE fill_marks() LANGUAGE plpgsql AS 
$$
	DECLARE
	i integer;
	j integer;
	BEGIN
		FOR i in (SELECT id FROM exam) LOOP	
		j = 1 + random () *  (5 - 1);
		INSERT INTO mark (id, exam, stud, res) 
			SELECT nextval('mark_id'), i, id, 
			2 + random() * (5 - 2) FROM students WHERE random() < 0.10;
		END LOOP;
	END;
$$;



CALL fill_marks();


CREATE VIEW exam_count AS SELECT students.first, students.last, COUNT(mark.exam) AS exams 
FROM students
CROSS JOIN mark 
WHERE students.id = mark.stud
GROUP BY students.first, students.last;


CREATE VIEW exam_marks AS
SELECT d.descr AS discipline,
       m.res AS mark,
       e.ts AS exam_date
FROM mark m
JOIN exam e ON m.exam = e.id
JOIN discipline d ON e.discip = d.id
WHERE m.stud = (SELECT id FROM students WHERE first = 'ARMINDA' AND last = 'GROPP');

CREATE VIEW last_mark AS
SELECT DISTINCT ON (m.exam, m.stud)
       d.id AS discip,
       m.stud,
       e.ts AS exam_date
FROM mark m
JOIN exam e ON m.exam = e.id
JOIN discipline d ON e.discip = d.id
ORDER BY m.exam, m.stud, e.ts DESC;


CREATE MATERIALIZED VIEW last_mark_mat AS
SELECT DISTINCT ON (m.exam, m.stud)
       d.id AS discip,
       m.stud,
       e.ts AS exam_date
FROM mark m
JOIN exam e ON m.exam = e.id
JOIN discipline d ON e.discip = d.id
ORDER BY m.exam, m.stud, e.ts DESC;

CREATE VIEW final_marks AS
SELECT lm.discip,
       lm.stud,
       m.res AS result
FROM last_mark_mat lm
JOIN mark m ON lm.discip = m.exam AND lm.stud = m.stud
ORDER BY lm.discip, lm.stud, lm.exam_date DESC;

CREATE MATERIALIZED VIEW final_marks_mat AS
SELECT DISTINCT ON (lm.discip, lm.stud)
       lm.discip,
       lm.stud,
       m.res
FROM last_mark_mat lm
JOIN mark m ON lm.discip = m.exam AND lm.stud = m.stud
ORDER BY lm.discip, lm.stud, lm.exam_date DESC;

CREATE VIEW stud_marks AS
SELECT fm.stud,
       d.descr AS discipline,
       fm.result AS final_mark
FROM final_marks  fm
JOIN discipline d ON fm.discip = d.id;

CREATE VIEW stud_marks_alt AS
SELECT fmm.stud,
       d.descr AS discipline,
       fmm.res AS final_mark
FROM final_marks_mat fmm
JOIN discipline d ON fmm.discip = d.id;

EXPLAIN ANALYZE VERBOSE SELECT * FROM stud_marks WHERE stud = '3';
EXPLAIN ANALYZE VERBOSE SELECT * FROM stud_marks_alt WHERE stud = '3';

CREATE VIEW avg_marks AS
SELECT stud,
       AVG(result) AS average_mark
FROM final_marks
GROUP BY stud;


CREATE VIEW avg_marks_alt AS
SELECT stud,
       AVG(res) AS average_mark
FROM final_marks_mat
GROUP BY stud;

EXPLAIN ANALYZE VERBOSE SELECT * FROM avg_marks;
EXPLAIN ANALYZE VERBOSE SELECT * FROM avg_marks_alt;


