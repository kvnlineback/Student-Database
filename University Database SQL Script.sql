CREATE TABLE DEPARTMENTS (
  DEPT_ID NUMBER,
  dept_name VARCHAR2(60) NOT NULL,
  college VARCHAR2(60) NOT NULL,
  PRIMARY KEY (DEPT_ID)
);

CREATE TABLE COURSES (
  CNO NUMBER,
  ctitle VARCHAR2(50) NOT NULL,
  hours NUMBER(1) NOT NULL,
  dept_id NUMBER NOT NULL,
  CONSTRAINT courses_pk
    PRIMARY KEY (CNO),
  CONSTRAINT courses_fk
    FOREIGN KEY (dept_id) REFERENCES
    DEPARTMENTS (DEPT_ID)
);

CREATE TABLE INSTRUCTORS (
  LAST_NAME VARCHAR2(30),
  FIRST_NAME VARCHAR2(30),
  dept_id NUMBER NOT NULL,
  office VARCHAR2(30) NOT NULL,
  phone CHAR(12) NOT NULL,
  email VARCHAR2(50) NOT NULL CHECK(REGEXP_COUNT(email,'@') = 1),
  CONSTRAINT instructors_pk
  PRIMARY KEY (LAST_NAME, FIRST_NAME),
  CONSTRAINT instructors_fk
  FOREIGN KEY (dept_id) REFERENCES
  departments (DEPT_ID)
);

CREATE TABLE SECTIONS (
  TERM VARCHAR2(7),
  SECTNO NUMBER,
  cno NUMBER NOT NULL,
  instr_lname VARCHAR2(30),
  instr_fname VARCHAR2(30),
  room NUMBER NOT NULL,
  days VARCHAR2(30) NOT NULL,
  start_time NUMBER(4) NOT NULL,
  end_time NUMBER(4) NOT NULL,
  capacity NUMBER NOT NULL,
  CONSTRAINT sections_pk
  PRIMARY KEY (TERM, SECTNO),
  CONSTRAINT sections_fk
  FOREIGN KEY (cno) REFERENCES
  courses (CNO)
);

CREATE TABLE STUDENTS (
  SID NUMBER,
  last_name VARCHAR2(100) NOT NULL,
  first_name VARCHAR2(100) NOT NULL,
  class NUMBER(4) NOT NULL,
  phone CHAR(12) NOT NULL,
  street VARCHAR2(60) NOT NULL,
  city VARCHAR2(30) NOT NULL,
  state CHAR(2) NOT NULL,
  zip NUMBER(5) NOT NULL,
  degree VARCHAR2(60) NOT NULL,
  dept_id NUMBER NOT NULL,
  hours NUMBER(3) NOT NULL,
  gpa NUMBER NOT NULL,
  CONSTRAINT students_pk
  PRIMARY KEY (SID),
  CONSTRAINT students_fk
  FOREIGN KEY (dept_id)
  REFERENCES DEPARTMENTS (DEPT_ID)
);

CREATE TABLE ENROLLMENT (
  SID NUMBER,
  TERM VARCHAR2(25) NOT NULL,
  SECTNO NUMBER NOT NULL,
  grade NUMBER NOT NULL,
  CONSTRAINT enrollment_pk
  PRIMARY KEY (SID,TERM,SECTNO),
  CONSTRAINT enrollment_fk
  FOREIGN KEY (SID) REFERENCES 
  students (SID),
  FOREIGN KEY (TERM, SECTNO) REFERENCES
  sections (TERM, SECTNO)  
);

CREATE TABLE STUDENTACCOUNTS (
    SID NUMBER,
    balance FLOAT NOT NULL,
    CONSTRAINT stdaccts_pk
    PRIMARY KEY (SID),
    FOREIGN KEY (SID) REFERENCES
    students (SID)
);

CREATE OR REPLACE TRIGGER add_to_accounts --adds student to studentaccounts when student is added
AFTER
INSERT 
ON students
FOR EACH ROW
BEGIN
INSERT INTO studentaccounts VALUES(:NEW.SID, 0.0);
END;

CREATE OR REPLACE TRIGGER check_capacity --checks to make sure there is room in the course before enrollment is made
BEFORE
INSERT
ON enrollment
FOR EACH ROW
DECLARE
current_size sections.capacity%TYPE;
BEGIN
  SELECT capacity into current_size from sections where sections.sectno = :NEW.sectno AND sections.term = :NEW.term;
    IF current_size < 1 THEN
        raise_application_error(-20000
                , 'Class is full. Cannot add more students');
    END IF;
END;

CREATE OR REPLACE TRIGGER update_accounts_and_class_size_add --keeps students acccount's balance accurate based on their number of enrolled courses based on adds
AFTER
INSERT
ON enrollment
FOR EACH ROW
DECLARE
 current_balance studentaccounts.balance%TYPE;
 current_size sections.capacity%TYPE;
BEGIN
  SELECT balance INTO current_balance from studentaccounts where studentaccounts.SID = :NEW.SID; 
  UPDATE studentaccounts SET balance = current_balance + 500.00 WHERE SID = :NEW.SID;
  SELECT capacity into current_size from sections where sections.sectno = :NEW.sectno AND sections.term = :NEW.term;
  UPDATE sections SET capacity = current_size - 1 where sections.sectno = :NEW.sectno AND sections.term = :NEW.term;
END;

CREATE OR REPLACE TRIGGER update_accounts_and_class_size_drop --keeps students acccount's balance accurate based on their number of enrolled courses based on drops
BEFORE
DELETE
ON enrollment
FOR EACH ROW
DECLARE
 current_balance studentaccounts.balance%TYPE;
 current_size sections.capacity%TYPE;
BEGIN
  SELECT balance INTO current_balance from studentaccounts where studentaccounts.SID = :OLD.SID; 
  UPDATE studentaccounts SET balance = current_balance - 500.00 WHERE SID = :OLD.SID;
  SELECT capacity into current_size from sections where sections.sectno = :OLD.sectno AND sections.term = :OLD.term;
  UPDATE sections SET capacity = current_size + 1 where sections.sectno = :OLD.sectno AND sections.term = :OLD.term;
END;

CREATE OR REPLACE TRIGGER update_gpa_hours_add --keeps students gpa and total hours accurate based on their enrollment when a course is added
FOR INSERT  ON enrollment
COMPOUND TRIGGER
TYPE enrollment_record IS RECORD (
SID enrollment.SID%TYPE,
term enrollment.term%TYPE,
sectno enrollment.sectno%TYPE,
grade enrollment.grade%TYPE
);   
TYPE row_level_info_t IS TABLE OF enrollment_record INDEX BY PLS_INTEGER;
g_row_level_info   row_level_info_t; 
AFTER EACH ROW IS 
   BEGIN 
      g_row_level_info (g_row_level_info.COUNT +1).SID := :new.SID; 
      g_row_level_info (g_row_level_info.COUNT).grade := :new.grade;
      g_row_level_info (g_row_level_info.COUNT).term := :new.term;  
      g_row_level_info (g_row_level_info.COUNT).sectno := :new.sectno;  
   END AFTER EACH ROW; 
AFTER STATEMENT IS 
new_gpa students.gpa%TYPE; 
old_hours students.hours%TYPE;
new_hours students.hours%TYPE;
   BEGIN 
      FOR indx IN 1 .. g_row_level_info.COUNT 
      LOOP 
        SELECT ROUND(AVG(grade),2) into new_gpa from enrollment where SID = g_row_level_info (indx).SID; 
        UPDATE students SET gpa = new_gpa where SID = g_row_level_info (indx).SID;
        SELECT hours into old_hours from students where SID = g_row_level_info (indx).SID;
        SELECT hours into new_hours from courses c join sections s on c.cno = s.cno inner join enrollment e on s.sectno = e.sectno and s.term = e.term where e.SID = g_row_level_info (indx).SID 
        AND e.sectno = g_row_level_info (indx).sectno; 
        UPDATE students SET hours = old_hours + new_hours WHERE SID = g_row_level_info (indx).SID;      
      END LOOP; 
   END AFTER STATEMENT; 
END;

CREATE OR REPLACE TRIGGER student_integrity --removes student from classes when dropped from the university and deletes their student account
BEFORE DELETE
ON students
FOR EACH ROW
BEGIN
DELETE from studentaccounts WHERE studentaccounts.SID = :OLD.SID;
DELETE from enrollment WHERE enrollment.SID = :OLD.SID;
END;

CREATE OR REPLACE TRIGGER instructor_integrity_delete --deletes the sections that the professor was teaching and removes students from being enrolled in those sections
BEFORE DELETE
ON instructors
FOR EACH ROW
BEGIN
DELETE FROM enrollment where sectno in (select e.sectno from enrollment e inner join sections s on e.sectno = s.sectno where s.instr_fname = :OLD.first_name AND s.instr_lname = :OLD.last_name);
DELETE FROM sections s WHERE s.instr_fname = :OLD.first_name AND s.instr_lname = :OLD.last_name;
END;

INSERT INTO departments(dept_id, dept_name, college) VALUES(100, 'Computer Science', 'College of Science/Engineering');
INSERT INTO departments(dept_id, dept_name, college) VALUES(101, 'Mathematics', 'College of Math');
INSERT INTO departments(dept_id, dept_name, college) VALUES(102, 'English', 'College of Liberal Arts');
INSERT INTO departments(dept_id, dept_name, college) VALUES(103, 'Languages', 'College of Liberal Arts');
INSERT INTO departments(dept_id, dept_name, college) VALUES(104, 'Theater', 'College of Performing Arts');
INSERT INTO departments(dept_id, dept_name, college) VALUES(105, 'Music', 'College of Performing Arts');
INSERT INTO departments(dept_id, dept_name, college) VALUES(106, 'Engineering', 'College of Science/Engineering');
INSERT INTO departments(dept_id, dept_name, college) VALUES(107, 'Biology', 'College of Science/Engineering');
INSERT INTO departments(dept_id, dept_name, college) VALUES(108, 'Physics', 'College of Science/Engineering');
INSERT INTO departments(dept_id, dept_name, college) VALUES(109, 'History/Anthropology/Psychology', 'College of Liberal Arts');
INSERT INTO departments(dept_id, dept_name, college) VALUES(110, 'Business', 'College of Liberal Arts');

INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1000, 'Intro to Computer Science', 4, 100);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1001, 'Freshman English', 3, 102);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1002, 'Algebra', 4, 101);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1003, 'Algorithms', 4, 100);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1004, 'Spanish', 3, 103);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1005, 'Freshman English', 3, 102);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1006, 'Physics', 4, 108);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1007, 'Java Programming', 4, 100);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1008, 'Anthropology', 2, 109);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1009, 'World History', 2, 109);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1010, 'Geometry', 4, 101);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1011, 'Nuclear Science', 4, 108);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1012, 'Anthropology I', 2, 109);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1013, 'Anthropology II', 2, 109);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1014, 'German Studies', 3, 103);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1015, 'Intro to Film', 2, 104);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1016, 'Psychology III',3, 109);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1017, 'Quantum Mechanics', 4, 106);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1018, 'Business Management II', 3, 110);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1019, 'Entrepreneurship', 3, 110);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1020, 'Marketing', 3, 110);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1021, 'Accounting', 3, 110);
INSERT INTO courses(cno, ctitle, hours, dept_id) VALUES(1022, 'Supply Chain Management', 3, 110);

INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Pop', 'Greg', 100, 'Office #512', '312-352-1255', 'gpop@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Smith', 'John', 100, 'Office #512', '312-112-3453', 'jsmith@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Line', 'Bob', 101, 'Office #112', '312-123-6323', 'bline@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Rose', 'Axel', 101, 'Office #112', '312-812-3123', 'arose@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Rodriguez', 'Alex', 102, 'Office #534', '312-223-3121', 'arodriguez@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Ball', 'Paul', 103, 'Office #881', '312-523-8976', 'pball@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Yow', 'Dillon', 104, 'Office #743', '312-474-6784', 'dillonyow@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Gray', 'Tita', 105, 'Office #424', '312-234-8323', 'tgray@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Gil', 'Alex', 106, 'Office #763', '312-856-2351', 'agil@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Perk', 'Ken', 107, 'Office #235', '312-722-6321', 'kperk@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Beal', 'John', 107, 'Office #235', '312-235-6124', 'jbeal@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('LaPaz', 'Brian', 108, 'Office #821', '312-235-2324', 'blapaz@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Gob', 'Rudy', 109, 'Office #998', '312-123-8218', 'rgob@kevinsproject.com');
INSERT INTO instructors(last_name, first_name, dept_id, office, phone, email) VALUES('Smith', 'William', 110, 'Office #887', '312-234-9087', 'wsmith@kevinsproject.com');

INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 500, 1000, 'Pop', 'Greg', 111, 'M/W/F', 0800, 1000,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 501, 1000, 'Smith', 'John', 222, 'M/W', 0900, 1100,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 502, 1002, 'Line', 'Bob', 250, 'M/F', 0700, 1000,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 503, 1002, 'Rose', 'Axel', 250, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 504, 1001, 'Rodriguez', 'Alex', 250, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 505, 1003, 'Smith', 'John', 450, 'T/TH', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 506, 1004, 'Ball', 'Paul', 350, 'M/T/W', 1400, 1700,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 507, 1005, 'Rodriguez', 'Alex', 250, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 508, 1006, 'LaPaz', 'Brian', 350, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 509, 1007, 'Pop', 'Greg', 250, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 510, 1008, 'Gob', 'Rudy', 250, 'T/TH', 1200, 1500,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 511, 1009, 'Gob', 'Rudy', 950, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 512, 1010, 'Rose', 'Axel', 350, 'M/F', 1100, 1300,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 513, 1011, 'LaPaz', 'Brian', 650, 'M/W/TH', 1200, 1400,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 514, 1012, 'Gob', 'Rudy', 450, 'T/TH', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 515, 1013, 'Gob', 'Rudy', 250, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 516, 1014, 'Ball', 'Paul', 350, 'M/T/TH', 1400, 1700,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 517, 1015, 'Yow', 'Dillon', 850, 'M/T/W', 1500, 1800,20);
INSERT INTO sections(term, sectno, cno, instr_lname, instr_fname, room, days, start_time, end_time, capacity) VALUES('Autumn', 518, 1016, 'Gob', 'Rudy', 150, 'T/TH', 1500, 1800,20);

INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10000, 'Hal', 'John', 2022, '321-213-1245','125 Port Street', 'Chicago', 'IL', 60007, 'Mathematics', 101, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10001, 'Gomez', 'Harry', 2021, '321-521-3253','1255 Ocean Way', 'Chicago', 'IL', 60007, 'Computer Science', 100, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10002, 'Ross', 'Jim', 2024, '321-235-2352','1777 Main St', 'Chicago', 'IL', 60007, 'Computer Science', 100, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10003, 'Anama', 'Baxter', 2021, '321-111-2352','9191 B Street', 'Chicago', 'IL', 60007, 'English', 102, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10004, 'Brown', 'Gary', 2023, '321-181-4544','111 C Street', 'Chicago', 'IL', 60007, 'Anthropology', 109, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10005, 'Kendra', 'Ana', 2021, '321-233-1352','6777 A Street', 'Chicago', 'IL', 60007, 'Theater', 104, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10006, 'Shmidt', 'Brianna', 2024, '321-777-2382','1233 Ivy Lane', 'Chicago', 'IL', 60007, 'Business', 110, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10007, 'Lopez', 'Mario', 2022, '321-121-9352','777 C Street', 'Chicago', 'IL', 60007, 'Physics', 108, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10008, 'Lebon', 'Kevin', 2021, '321-177-3352','661 Ocean Way', 'Chicago', 'IL', 60007, 'Physics', 108, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10009, 'Pine', 'Chris', 2020, '321-111-2552','444 Broadway St', 'Chicago', 'IL', 60007, 'Music', 105, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10010, 'Maxwell', 'Fred', 2024, '321-221-9352','111 Port Street', 'Chicago', 'IL', 60007, 'Biology', 107, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10011, 'Hedwig', 'Josh', 2022, '321-211-2442','8222 B Street', 'Chicago', 'IL', 60007, 'Engineering', 106, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10012, 'Brown', 'Paul', 2022, '321-444-2152','6262 J Street', 'Chicago', 'IL', 60007, 'Languages', 103, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10013, 'Macron', 'Emmanuel', 2021, '321-124-7897','3463 Ocean Way', 'Chicago', 'IL', 60007, 'History', 109, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10014, 'Safwan', 'Laura', 2024, '321-161-7752','634 Broadway', 'Chicago', 'IL', 60007, 'Theater', 104, 0, 0.00);
INSERT INTO students(SID, last_name, first_name, class, phone, street, city, state, zip, degree, dept_id, hours, gpa) VALUES(10015, 'Katus', 'Brian', 2022, '321-211-2852','8181 Ivy Lane', 'Chicago', 'IL', 60007, 'Math', 101, 0, 0.00);

INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10000, 'Autumn', 507, 3.31);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10000, 'Autumn', 503, 3.12);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10000, 'Autumn', 500, 4.00);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10000, 'Autumn', 506, 3.67);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10001, 'Autumn', 507, 2.44);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10001, 'Autumn', 516, 3.73);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10001, 'Autumn', 518, 3.91);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10001, 'Autumn', 511, 3.39);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10001, 'Autumn', 502, 2.96);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10003, 'Autumn', 507, 3.16);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10003, 'Autumn', 511, 3.94);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10003, 'Autumn', 514, 3.55);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10003, 'Autumn', 502, 3.44);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10004, 'Autumn', 510, 3.63);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10004, 'Autumn', 517, 3.27);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10004, 'Autumn', 511, 3.88);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10004, 'Autumn', 506, 3.65);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10004, 'Autumn', 512, 3.73);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10005, 'Autumn', 500, 3.48);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10005, 'Autumn', 502, 3.64);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10005, 'Autumn', 509, 3.24);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10005, 'Autumn', 516, 3.04);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10006, 'Autumn', 501, 3.88);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10006, 'Autumn', 518, 3.53);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10006, 'Autumn', 516, 3.27);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 503, 3.39);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 501, 3.97);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 500, 3.18);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 509, 4.00);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 512, 3.91);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10007, 'Autumn', 514, 2.71);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10008, 'Autumn', 501, 3.29);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10008, 'Autumn', 517, 3.64);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10008, 'Autumn', 507, 3.52);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10008, 'Autumn', 512, 3.41);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10009, 'Autumn', 500, 3.16);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10009, 'Autumn', 514, 3.88);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10009, 'Autumn', 511, 3.75);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 502, 3.63);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 517, 3.82);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 503, 3.31);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 505, 3.13);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 518, 3.82);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10010, 'Autumn', 512, 3.24);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10011, 'Autumn', 501, 3.86);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10011, 'Autumn', 510, 3.52);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10011, 'Autumn', 511, 2.91);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10012, 'Autumn', 500, 2.92);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10013, 'Autumn', 516, 3.85);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10013, 'Autumn', 506, 3.76);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10013, 'Autumn', 501, 3.85);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10014, 'Autumn', 514, 2.84);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10014, 'Autumn', 508, 4.00);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10015, 'Autumn', 502, 3.73);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10015, 'Autumn', 501, 4.00);
INSERT INTO enrollment(SID,term,sectno,grade) VALUES(10015, 'Autumn', 512, 2.93);
commit;






