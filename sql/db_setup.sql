--CREATE SCHEMA my_schema;
--CREATE TABLE my_schema.sample
CREATE TABLE sample (
  pg_text text,
  pg_numeric numeric,
  pg_boolean bool,
  pg_empty text
);
--CREATE TABLE my_schema.sample_2
CREATE TABLE sample_2 (
  pg_int int,
  pg_char char
);
--CREATE TABLE my_schema.sample_3
CREATE TABLE sample_3 (
  pg_arr2_bool bool,
  pg_arr3_string text,
  pg_arr3_int int,
  pg_arr4_a text,
  pg_arr4_b text
);

--INSERT INTO my_schema.sample
INSERT INTO sample (
  pg_text,
  pg_numeric,
  pg_boolean,
  pg_empty
) VALUES (
-- matches sample.json
  'A string of characters',
  123.456,
  true,
  null
), (
-- doesn't match sample.json
  'different text',
  7.89,
  false,
  'not null'
);
--INSERT INTO my_schema.sample_2
INSERT INTO sample_2 (
  pg_int,
  pg_char
) VALUES (
-- matches sample.json
  1234,
  'a'
), (
-- doesn't match sample.json
  67,
  'j'
), (
-- matches sample.json
  9,
  'z'
), (
-- doesn't match sample.json
  9,
  'a'
);
--INSERT INTO my_schema.sample_3
INSERT INTO sample_3 (
  pg_arr2_bool,
  pg_arr3_string,
  pg_arr3_int,
  pg_arr4_a,
  pg_arr4_b
) VALUES (
-- matches sample.json
  true,
  'a2-0-a3-0',
  0,
  '04a',
  '04b'
), (
-- doesn't match sample.json
  true,
  'a2-0-a3-0',
  1,
  '04a',
  '04b'
), (
-- matches sample.json
  false,
  'a2-1-a3-0',
  10,
  '24a',
  '24b'
), (
-- doesn't match sample.json
  false,
  'a2-1-a3-0',
  0,
  '14a',
  '14b'
), (
-- doesn't match sample.json
  true,
  'a2-1-a3-1',
  11,
  '14a',
  '14b'
), (
-- doesn't match sample.json
  false,
  'a2-1-a3-0',
  10,
  '14a',
  '24b'
);


--SELECT (SELECT COUNT(*) record_count_sample_table FROM my_schema.sample), (SELECT COUNT(*) record_count_sample_2_table FROM my_schema.sample_2), (SELECT COUNT(*) record_count_sample_3_table FROM my_schema.sample_3)
SELECT (SELECT COUNT(*) record_count_sample_table FROM sample), (SELECT COUNT(*) record_count_sample_2_table FROM sample_2), (SELECT COUNT(*) record_count_sample_3_table FROM sample_3)
