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

--INSERT INTO my_schema.sample
INSERT INTO sample (
  pg_text,
  pg_numeric,
  pg_boolean,
  pg_empty
) VALUES (
  'A string of characters',
  123.456,
  true,
  null
), (
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
  1234,
  'a'
), (
  67,
  'j'
), (
  9,
  'z'
);

--SELECT * FROM my_schema.sample;
SELECT * FROM sample;
