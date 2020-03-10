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
  'array,int',
--  'my_schema',
  null,
  'sample_2',
  'pg_int'
), (
  'sample_json',
  'array,char',
--  'my_schema',
  null,
  'sample_2',
  'pg_char'
), (
  'sample_json',
  'altObject,int',
  'alt_schema',
  'alt_table',
  'pg_int'
), (
  'sample_json',
  'array2,bool',
--  'my_schema',
  null,
  'sample_3',
  'pg_arr2_bool'
), (
  'sample_json',
  'array2,array3,string',
--  'my_schema',
  null,
  'sample_3',
  'pg_arr3_string'
), (
  'sample_json',
  'array2,array3,int',
--  'my_schema',
  null,
  'sample_3',
  'pg_arr3_int'
), (
  'sample_json',
  'array2,array4,a',
--  'my_schema',
  null,
  'sample_3',
  'pg_arr4_a'
), (
  'sample_json',
  'array2,array4,b',
--  'my_schema',
  null,
  'sample_3',
  'pg_arr4_b'
);

--SELECT * FROM my_schema.mapping_details;
SELECT * FROM mapping_details;
