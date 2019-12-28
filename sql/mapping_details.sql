--CREATE TABLE my_schema.mapping_details
CREATE TABLE mapping_details
(
  json_type text,
  json_path text,
  db_schema text,
  db_table text,
  db_column text
);

--INSERT INTO my_schema.mapping_details
INSERT INTO mapping_details
(
  json_type,
  json_path,
  db_schema,
  db_table,
  db_column
)
VALUES (
  'sample_json',
  'text',
--  'my_schema',
  null,
  'sample',
  'pg_text'
), (
  'sample_json',
  'numeric',
--  'my_schema',
  null,
  'sample',
  'pg_numeric'
), (
  'sample_json',
  'object,boolean',
--  'my_schema',
  null,
  'sample',
  'pg_boolean'
), (
  'sample_json',
  'object,null',
--  'my_schema',
  null,
  'sample',
  'pg_empty'
), (
  'sample_json',
  'altObject,int',
  'alt_schema',
  'alt_table',
  'pg_int'
);

--SELECT * FROM my_schema.mapping_details;
SELECT * FROM mapping_details;
