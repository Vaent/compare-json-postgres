# Compare JSON data against records in a PostgreSQL database

Developing a method to identify whether a JSON object has been stored in a database, provided each field in the JSON is directly associated with a column (or multiple columns) in the database.

**This solution looks up JSON-database mapping details from a reference table in the database.**

## Setup

*Note: all scripts include alternative lines (commented out) for defining and using a custom schema if the default 'public' schema is not appropriate. In all cases these are intended to replace the line which immediately follows them. Users must ensure the relevant lines are updated in all locations, in all scripts if not using the default schema.*

### Demo

This section describes how to set up sample data for testing the function. If the code is to be deployed in an existing database, the sample table is not required but there must be a reference table like the one created by [mapping_details.sql](./sql/mapping_details.sql); any deviations from the format/names defined in that script must be reflected in [compare_json_to_postgres.sql](./sql/compare_json_to_postgres.sql).

Executing the queries in [db_setup.sql](./sql/db_setup.sql) will create sample tables designed to store the data from a JSON payload represented by [sample.json](./resources/sample.json). The table will be populated with one record matching the contents of [sample.json](./resources/sample.json) and one non-matching record. The array in [sample.json](./resources/sample.json) includes a pair of fields ("fake"/"faker") which are not mapped to the matching values in the database so do not produce a match from the comparison function.

Executing the queries in [mapping_details.sql](./sql/mapping_details.sql) creates the reference table, populated for the sample structures plus an unused mapping for negative testing. The table created will look like this:

json_type   | json_path      | db_schema     | db_table    | db_column  
:-----------|:---------------|:--------------|:------------|:-----------
sample_json | text           | [null]        | sample      | pg_text    
sample_json | numeric        | [null]        | sample      | pg_numeric
sample_json | object,boolean | [null]        | sample      | pg_boolean
sample_json | object,null    | [null]        | sample      | pg_empty
sample_json | array,int      | [null]        | sample_2    | pg_int
sample_json | array,char     | [null]        | sample_2    | pg_char
sample_json | altObject,int  | alt_schema    | alt_table   | pg_int

- `json_type` is used to distinguish different payload types e.g. "customer", "account", "transaction".
- `json_path` locates the value in the payload.
- `db_schema`, `db_table`, `db_column` reference the database field where the value should be stored.

### Function

Executing the [compare_json_to_postgres.sql](./sql/compare_json_to_postgres.sql) script will add the stored procedure `compare_json_to_postgres(par_json_type text, par_json json)` to the database. This script makes reference to the "mapping_details" table which must be present in the database for the function to be created.

The stored procedure can then be invoked as demonstrated in [test_stored_function.sql](./sql/test_stored_function.sql) for the sample data.

Results are output as `RAISE NOTICE` statements. In pgAdmin these are displayed on a separate tab in the Data Output panel:

![Where to find notices in pgAdmin interface](./resources/messages_in_pgadmin.png)

Additional information is available from `RAISE DEBUG` statements; by default these messages are not displayed but if required they can be viewed by changing the logging level (or changing the code to raise them at NOTICE level).

## Limitations

Arrays encountered in a JSON path are handled by aggregating values, without regard to any association that could be inferred from the structure:
```
"arr" : [
  { "int" : 1, "text" : "a"},
  { "int" : 2, "text" : "b"}
]
```
-> path "arr,int" matches 1 or 2; path "arr,text" matches "a" or "b"; records with one of the combinations (1 & "a"), (1 & "b"), (2 & "a"), (2 & "b") are all treated as matching the JSON.

There is no handling of references to specific indices in an array:
```
"arr" : ["a", "b", "c"]
```
-> path "arr" matches "a" or "b" or "c"; path "arr,1" matches nothing.
