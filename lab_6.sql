--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: lab06; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA lab06;


ALTER SCHEMA lab06 OWNER TO postgres;

--
-- Name: add_random_student(); Type: PROCEDURE; Schema: lab06; Owner: postgres
--

CREATE PROCEDURE lab06.add_random_student()
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE lab06.add_random_student() OWNER TO postgres;

--
-- Name: fill_marks(); Type: PROCEDURE; Schema: lab06; Owner: postgres
--

CREATE PROCEDURE lab06.fill_marks()
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE lab06.fill_marks() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: discipline; Type: TABLE; Schema: lab06; Owner: postgres
--

CREATE TABLE lab06.discipline (
    id integer NOT NULL,
    descr character varying(50)
);


ALTER TABLE lab06.discipline OWNER TO postgres;

--
-- Name: exam; Type: TABLE; Schema: lab06; Owner: postgres
--

CREATE TABLE lab06.exam (
    id integer NOT NULL,
    discip integer NOT NULL,
    ts timestamp without time zone
);


ALTER TABLE lab06.exam OWNER TO postgres;

--
-- Name: mark; Type: TABLE; Schema: lab06; Owner: postgres
--

CREATE TABLE lab06.mark (
    id integer NOT NULL,
    exam integer NOT NULL,
    stud integer NOT NULL,
    res integer
);


ALTER TABLE lab06.mark OWNER TO postgres;

--
-- Name: last_mark_mat; Type: MATERIALIZED VIEW; Schema: lab06; Owner: postgres
--

CREATE MATERIALIZED VIEW lab06.last_mark_mat AS
 SELECT DISTINCT ON (m.exam, m.stud) d.id AS discip,
    m.stud,
    e.ts AS exam_date
   FROM ((lab06.mark m
     JOIN lab06.exam e ON ((m.exam = e.id)))
     JOIN lab06.discipline d ON ((e.discip = d.id)))
  ORDER BY m.exam, m.stud, e.ts DESC
  WITH NO DATA;


ALTER MATERIALIZED VIEW lab06.last_mark_mat OWNER TO postgres;

--
-- Name: final_marks; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.final_marks AS
 SELECT lm.discip,
    lm.stud,
    m.res AS result
   FROM (lab06.last_mark_mat lm
     JOIN lab06.mark m ON (((lm.discip = m.exam) AND (lm.stud = m.stud))))
  ORDER BY lm.discip, lm.stud, lm.exam_date DESC;


ALTER VIEW lab06.final_marks OWNER TO postgres;

--
-- Name: avg_marks; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.avg_marks AS
 SELECT stud,
    avg(result) AS average_mark
   FROM lab06.final_marks
  GROUP BY stud;


ALTER VIEW lab06.avg_marks OWNER TO postgres;

--
-- Name: final_marks_mat; Type: MATERIALIZED VIEW; Schema: lab06; Owner: postgres
--

CREATE MATERIALIZED VIEW lab06.final_marks_mat AS
 SELECT DISTINCT ON (lm.discip, lm.stud) lm.discip,
    lm.stud,
    m.res
   FROM (lab06.last_mark_mat lm
     JOIN lab06.mark m ON (((lm.discip = m.exam) AND (lm.stud = m.stud))))
  ORDER BY lm.discip, lm.stud, lm.exam_date DESC
  WITH NO DATA;


ALTER MATERIALIZED VIEW lab06.final_marks_mat OWNER TO postgres;

--
-- Name: avg_marks_alt; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.avg_marks_alt AS
 SELECT stud,
    avg(res) AS average_mark
   FROM lab06.final_marks_mat
  GROUP BY stud;


ALTER VIEW lab06.avg_marks_alt OWNER TO postgres;

--
-- Name: discip_id; Type: SEQUENCE; Schema: lab06; Owner: postgres
--

CREATE SEQUENCE lab06.discip_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE lab06.discip_id OWNER TO postgres;

--
-- Name: students; Type: TABLE; Schema: lab06; Owner: postgres
--

CREATE TABLE lab06.students (
    id integer NOT NULL,
    first character varying(50),
    last character varying(50),
    sex character(1)
);


ALTER TABLE lab06.students OWNER TO postgres;

--
-- Name: exam_count; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.exam_count AS
 SELECT students.first,
    students.last,
    count(mark.exam) AS exams
   FROM (lab06.students
     CROSS JOIN lab06.mark)
  WHERE (students.id = mark.stud)
  GROUP BY students.first, students.last;


ALTER VIEW lab06.exam_count OWNER TO postgres;

--
-- Name: exam_id; Type: SEQUENCE; Schema: lab06; Owner: postgres
--

CREATE SEQUENCE lab06.exam_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE lab06.exam_id OWNER TO postgres;

--
-- Name: exam_marks; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.exam_marks AS
 SELECT d.descr AS discipline,
    m.res AS mark,
    e.ts AS exam_date
   FROM ((lab06.mark m
     JOIN lab06.exam e ON ((m.exam = e.id)))
     JOIN lab06.discipline d ON ((e.discip = d.id)))
  WHERE (m.stud = ( SELECT students.id
           FROM lab06.students
          WHERE (((students.first)::text = 'ARMINDA'::text) AND ((students.last)::text = 'GROPP'::text))));


ALTER VIEW lab06.exam_marks OWNER TO postgres;

--
-- Name: firstfemalename; Type: FOREIGN TABLE; Schema: lab06; Owner: postgres
--

CREATE FOREIGN TABLE lab06.firstfemalename (
    femname character varying
)
SERVER file_server
OPTIONS (
    filename 'C:/lab06Files/name-first-female.csv',
    format 'csv'
);


ALTER FOREIGN TABLE lab06.firstfemalename OWNER TO postgres;

--
-- Name: firstmalename; Type: FOREIGN TABLE; Schema: lab06; Owner: postgres
--

CREATE FOREIGN TABLE lab06.firstmalename (
    malename character varying
)
SERVER file_server
OPTIONS (
    filename 'C:/lab06Files/name-first-male.csv',
    format 'csv'
);


ALTER FOREIGN TABLE lab06.firstmalename OWNER TO postgres;

--
-- Name: last_mark; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.last_mark AS
 SELECT DISTINCT ON (m.exam, m.stud) d.id AS discip,
    m.stud,
    e.ts AS exam_date
   FROM ((lab06.mark m
     JOIN lab06.exam e ON ((m.exam = e.id)))
     JOIN lab06.discipline d ON ((e.discip = d.id)))
  ORDER BY m.exam, m.stud, e.ts DESC;


ALTER VIEW lab06.last_mark OWNER TO postgres;

--
-- Name: lastnameall; Type: FOREIGN TABLE; Schema: lab06; Owner: postgres
--

CREATE FOREIGN TABLE lab06.lastnameall (
    lastall character varying
)
SERVER file_server
OPTIONS (
    filename 'C:/lab06Files/name-last-all.csv',
    format 'csv'
);


ALTER FOREIGN TABLE lab06.lastnameall OWNER TO postgres;

--
-- Name: mark_id; Type: SEQUENCE; Schema: lab06; Owner: postgres
--

CREATE SEQUENCE lab06.mark_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE lab06.mark_id OWNER TO postgres;

--
-- Name: stud_id; Type: SEQUENCE; Schema: lab06; Owner: postgres
--

CREATE SEQUENCE lab06.stud_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE lab06.stud_id OWNER TO postgres;

--
-- Name: stud_marks; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.stud_marks AS
 SELECT fm.stud,
    d.descr AS discipline,
    fm.result AS final_mark
   FROM (lab06.final_marks fm
     JOIN lab06.discipline d ON ((fm.discip = d.id)));


ALTER VIEW lab06.stud_marks OWNER TO postgres;

--
-- Name: stud_marks_alt; Type: VIEW; Schema: lab06; Owner: postgres
--

CREATE VIEW lab06.stud_marks_alt AS
 SELECT fmm.stud,
    d.descr AS discipline,
    fmm.res AS final_mark
   FROM (lab06.final_marks_mat fmm
     JOIN lab06.discipline d ON ((fmm.discip = d.id)));


ALTER VIEW lab06.stud_marks_alt OWNER TO postgres;

--
-- Data for Name: discipline; Type: TABLE DATA; Schema: lab06; Owner: postgres
--

COPY lab06.discipline (id, descr) FROM stdin;
1	Math
2	Physics
3	Computer Science
4	History
5	Foreign Language
\.


--
-- Data for Name: exam; Type: TABLE DATA; Schema: lab06; Owner: postgres
--

COPY lab06.exam (id, discip, ts) FROM stdin;
1	2	2021-08-03 16:02:12.011601
2	4	2021-07-10 09:33:55.718389
3	1	2021-07-23 07:24:09.554905
4	5	2021-08-03 08:09:45.122893
5	5	2021-07-15 17:33:50.960045
6	3	2021-08-25 05:20:28.618
7	2	2021-07-03 19:18:51.410356
8	5	2021-07-12 03:44:23.930936
9	5	2021-08-18 21:29:40.894498
10	5	2021-07-05 01:50:17.519564
11	3	2021-07-17 12:51:50.337544
12	4	2021-08-15 08:01:24.461402
13	3	2021-07-02 01:30:06.762619
14	1	2021-07-20 20:22:13.412249
15	4	2021-08-30 20:46:28.977689
16	5	2021-08-19 17:14:20.834795
17	2	2021-07-15 05:36:38.476716
18	3	2021-07-10 23:41:34.316564
19	3	2021-08-04 23:51:39.911564
20	1	2021-08-02 06:35:29.985807
\.


--
-- Data for Name: mark; Type: TABLE DATA; Schema: lab06; Owner: postgres
--

COPY lab06.mark (id, exam, stud, res) FROM stdin;
1	1	22	3
2	1	25	4
3	1	38	3
4	1	47	4
5	1	48	3
6	1	58	4
7	1	60	5
8	1	62	2
9	1	79	3
10	1	91	3
11	1	95	4
12	2	1	2
13	2	25	2
14	2	33	3
15	2	37	2
16	2	41	2
17	2	46	5
18	2	52	5
19	2	54	3
20	2	77	3
21	2	83	2
22	2	89	4
23	2	95	5
24	3	1	3
25	3	6	3
26	3	29	2
27	3	30	5
28	3	34	3
29	3	61	3
30	3	70	3
31	3	93	4
32	3	96	3
33	4	1	4
34	4	3	2
35	4	14	4
36	4	48	4
37	4	53	2
38	4	64	3
39	4	65	5
40	4	67	3
41	4	83	3
42	4	86	4
43	4	88	5
44	4	91	3
45	5	14	5
46	5	44	3
47	5	46	5
48	5	50	4
49	5	58	4
50	5	59	4
51	5	62	2
52	5	93	5
53	5	100	3
54	6	1	4
55	6	16	3
56	6	54	4
57	6	64	5
58	6	71	4
59	6	81	4
60	6	86	4
61	6	87	2
62	6	90	4
63	6	92	4
64	6	98	2
65	7	6	4
66	7	9	4
67	7	12	4
68	7	17	4
69	7	21	3
70	7	34	5
71	7	41	2
72	7	49	4
73	7	59	4
74	7	66	5
75	7	70	4
76	7	87	3
77	8	2	4
78	8	9	2
79	8	17	5
80	8	26	3
81	8	28	2
82	8	50	4
83	8	70	5
84	8	74	4
85	8	76	3
86	8	90	3
87	8	94	5
88	9	3	4
89	9	18	4
90	9	28	2
91	9	70	3
92	9	87	5
93	9	95	4
94	9	96	3
95	10	3	4
96	10	25	5
97	10	34	4
98	10	45	4
99	10	53	3
100	10	61	3
101	10	63	4
102	10	84	3
103	11	8	3
104	11	20	2
105	11	30	5
106	11	48	3
107	11	61	3
108	11	68	5
109	11	78	2
110	12	6	5
111	12	29	5
112	12	31	3
113	12	43	5
114	12	44	4
115	12	64	4
116	12	68	2
117	12	77	3
118	12	98	3
119	13	14	2
120	13	23	3
121	13	28	2
122	13	40	4
123	13	60	4
124	13	84	4
125	13	86	3
126	13	97	3
127	14	2	4
128	14	10	4
129	14	12	5
130	14	23	5
131	14	44	4
132	14	51	4
133	14	53	3
134	14	87	3
135	14	94	2
136	15	5	2
137	15	8	4
138	15	16	3
139	15	43	2
140	15	47	3
141	15	54	5
142	15	59	4
143	15	61	5
144	15	73	3
145	15	78	2
146	15	80	3
147	15	85	4
148	15	88	3
149	16	12	5
150	16	16	2
151	16	34	2
152	16	38	4
153	16	40	3
154	16	68	3
155	16	69	4
156	16	81	5
157	16	89	5
158	17	18	5
159	17	41	2
160	17	45	3
161	17	56	4
162	17	71	4
163	17	78	2
164	17	81	2
165	18	1	4
166	18	2	3
167	18	5	4
168	18	14	4
169	18	45	3
170	18	46	3
171	18	48	3
172	18	52	2
173	18	53	4
174	18	64	2
175	18	83	4
176	18	94	3
177	19	37	4
178	19	62	5
179	19	66	3
180	19	67	4
181	19	82	5
182	19	84	3
183	19	90	3
184	20	21	5
185	20	36	4
186	20	44	4
187	20	87	4
188	20	90	3
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: lab06; Owner: postgres
--

COPY lab06.students (id, first, last, sex) FROM stdin;
1	JEWEL	HOOSOCK	M
2	TRISTAN	DUGAT	F
3	SHEILAH	FLOREZ	F
4	CICELY	ACKROYD	F
5	KARENA	MAACK	F
6	DELAINE	SHENEFIELD	F
7	MARIO	LOVELESS	M
8	MARCIE	DAMBRA	F
9	CLEMENTE	NERREN	M
10	BUFORD	BLOISE	M
11	ADAN	KAIZER	M
12	BRITT	VIEW	M
13	DAMIEN	HABLE	M
14	CARA	BEHANNA	F
15	ARTURO	MOONEYHAN	M
16	STEPHNIE	LIPOMA	F
17	KALI	DEMAINE	F
18	LAZARO	WHITON	M
19	GALE	OHLSSON	M
20	LANCE	SCHUTTLER	M
21	DALTON	PHILIPPE	M
22	GLENNIS	STOCKON	F
23	ROBT	CURIEL	M
24	FRANKLYN	SVEUM	M
25	TEDDY	AHYET	M
26	LON	MUFFOLETTO	M
27	RUSTY	BUCCIERI	M
28	YOLONDA	MONETTI	F
29	COLETTA	HAWKE	F
30	BRAD	DEMIK	M
31	THEO	GALASSO	M
32	GUILLERMO	HAEHN	M
33	WENDELL	MCCLANEY	M
34	LATISHA	MANGLE	F
35	KENT	PRESTIA	M
36	TERENCE	ESPARAZA	M
37	BARRETT	TITLER	M
38	CLAY	KALVIG	M
39	ELLIOTT	BONFIGLIO	M
40	ISSAC	SCOBIE	M
41	PAT	ZIEBOLD	M
42	NGUYET	CHERNOSKY	F
43	CHESTER	BELTRE	M
44	TAISHA	WOLSKE	F
45	FEDERICO	PELCHER	M
46	JEFFEREY	DELAURIE	M
47	CLIFF	ZOLLMAN	M
48	MARILOU	OLDERSHAW	F
49	SYLVIA	DETERMAN	F
50	HEDY	SODERVICK	F
51	JERROLD	HANSROTE	M
52	ADAN	ARENALES	M
53	ARDITH	RAMSIER	F
54	AI	NAMM	F
55	LARRY	GROSHONG	M
56	SHAKIA	SPADA	F
57	ELLIOTT	PURCE	M
58	SUSANNAH	STEINBRINK	F
59	BRYCE	PACINI	M
60	GERTRUDIS	MARKSTROM	F
61	CHIEKO	CUMMINS	F
62	LANNY	IMBRENDA	M
63	LENNY	GRELL	M
64	GAY	YONEDA	F
65	ANDRE	MAYFIELD	F
66	MARCEL	HALLIO	M
67	KRISTOPHER	VUCKOVICH	M
68	KURTIS	POUPARD	M
69	CHUCK	LAMBERTON	M
70	EARNESTINE	DRUCKMAN	F
71	BETTYE	GUADALUPE	F
72	FRANKLYN	JOSLYN	M
73	WILFORD	ALMADA	M
74	EMORY	DOSSIE	M
75	DOMINGO	FAVIERI	M
76	ANGEL	FOXHOVEN	M
77	RETHA	ARCIZO	F
78	DARLENE	CALDERON	F
79	TERESE	DEWALL	F
80	MARLEN	WOOLLARD	F
81	CATHRYN	MIRA	F
82	WILBER	SUREN	M
83	REINALDO	TUNBY	M
84	VELVA	YONO	F
85	BRUNO	ELLEFSON	M
86	YONG	VOGTLIN	M
87	LISBETH	TRUGLIA	F
88	CHRISTINE	HOYING	F
89	EMIL	SEARCEY	M
90	MAUDE	ZELENKO	F
91	KARINA	CLARKSTON	F
92	SIMONNE	RAPPLEY	F
93	JON	DIMARE	F
94	LANNY	TOFT	M
95	JAIME	SKEETERS	M
96	TYLER	GOLIAS	M
97	KIMBERLY	RIGAZIO	F
98	TANIKA	COBDEN	F
99	HARRIETT	REYE	F
100	MIKE	PANAGOS	M
\.


--
-- Name: discip_id; Type: SEQUENCE SET; Schema: lab06; Owner: postgres
--

SELECT pg_catalog.setval('lab06.discip_id', 5, true);


--
-- Name: exam_id; Type: SEQUENCE SET; Schema: lab06; Owner: postgres
--

SELECT pg_catalog.setval('lab06.exam_id', 20, true);


--
-- Name: mark_id; Type: SEQUENCE SET; Schema: lab06; Owner: postgres
--

SELECT pg_catalog.setval('lab06.mark_id', 188, true);


--
-- Name: stud_id; Type: SEQUENCE SET; Schema: lab06; Owner: postgres
--

SELECT pg_catalog.setval('lab06.stud_id', 100, true);


--
-- Name: discipline discipline_pkey; Type: CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.discipline
    ADD CONSTRAINT discipline_pkey PRIMARY KEY (id);


--
-- Name: exam exam_pkey; Type: CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.exam
    ADD CONSTRAINT exam_pkey PRIMARY KEY (id);


--
-- Name: mark mark_pkey; Type: CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.mark
    ADD CONSTRAINT mark_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: exam exam_discip_fkey; Type: FK CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.exam
    ADD CONSTRAINT exam_discip_fkey FOREIGN KEY (discip) REFERENCES lab06.discipline(id);


--
-- Name: mark mark_exam_fkey; Type: FK CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.mark
    ADD CONSTRAINT mark_exam_fkey FOREIGN KEY (exam) REFERENCES lab06.exam(id);


--
-- Name: mark mark_stud_fkey; Type: FK CONSTRAINT; Schema: lab06; Owner: postgres
--

ALTER TABLE ONLY lab06.mark
    ADD CONSTRAINT mark_stud_fkey FOREIGN KEY (stud) REFERENCES lab06.students(id);


--
-- Name: last_mark_mat; Type: MATERIALIZED VIEW DATA; Schema: lab06; Owner: postgres
--

REFRESH MATERIALIZED VIEW lab06.last_mark_mat;


--
-- Name: final_marks_mat; Type: MATERIALIZED VIEW DATA; Schema: lab06; Owner: postgres
--

REFRESH MATERIALIZED VIEW lab06.final_marks_mat;


--
-- PostgreSQL database dump complete
--

