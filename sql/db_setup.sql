--CREATE SCHEMA my_schema;
--CREATE TABLE my_schema.sample
CREATE TABLE sample
(
  pg_text text,
  pg_numeric numeric,
  pg_boolean bool,
  pg_empty text
);

--INSERT INTO my_schema.sample
INSERT INTO sample
(
  pg_text,
  pg_numeric,
  pg_boolean
)
VALUES (
  'A string of characters',
  123.456,
  true
);

--INSERT INTO my_schema.sample
INSERT INTO sample
(
  pg_text,
  pg_numeric,
  pg_boolean,
  pg_empty
)
VALUES (
  'different text',
  7.89,
  false,
  'not null'
);

--SELECT * FROM my_schema.sample;
SELECT * FROM sample;
