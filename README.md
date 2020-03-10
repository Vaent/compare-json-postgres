# Compare JSON data against records in a PostgreSQL database

Developing a method to identify whether values in a JSON object have been stored in a database.

This work is intended for testing code which writes records to a Postgres database, to save time where the alternative would be a manual check of potentially hundreds of values across multiple tables. It requires fields in the input JSON to be mapped to specific database columns, so is most useful when this information is already available or when testing is frequent enough to justify creating and maintaining the mapping data.

Three options are provided:

- `compare_json_to_postgres.sql`, a stored function which gets JSON-database mapping details from a reference table in the database; recommended if the set of mapping details is large, or the function is likely to be used frequently.
- `compare_json_to_postgres_json_mapping.sql`, a similar stored function which takes the mapping details as a JSON parameter; recommended if it is undesirable to maintain mapping details in a database table, may be useful where the collection of mapping details is small or changes frequently.
- `compare_json_to_postgres_standalone.sql`, a "DO block" which can be executed without storing anything in the database (besides the data being tested); this is provided as an alternative to creating stored functions, but the other options should generally be preferred due to their lower complexity.

All of these check the input JSON for fields which are mapped to database columns, use those values to build SQL queries, then execute the queries and print the number of records in each table which match the JSON.

## Setup

*Note: most scripts include alternative lines (commented out) for defining and using a custom schema if the default schema is not appropriate. These are intended to replace, not supplement, the lines which immediately follow them. Users must ensure the relevant lines are updated in all locations, in all scripts if not using the default schema.*

### Sample data

This is provided for demonstrating/testing the functions (it is not required for normal usage).

Executing the [db_setup.sql](./sql/db_setup.sql) script will create sample tables based on [sample.json](./resources/sample.json) containing some records which match sample.json, and some which don't match due to values not being in the JSON, values being incorrectly associated in the database, and JSON fields not being mapped. The following outcomes are expected when the comparison function is run:

- "sample" table contains one matching record
- "sample_2" table contains two matching records
- "sample_3" table contains two matching records

### Mapping details

- `json_type` is used to distinguish different payload types e.g. "customer", "account", "transaction".
- `json_path` locates the value in the payload.
- `db_schema`, `db_table`, `db_column` reference the database field where the value should be stored.

#### Database table for mapping details

Executing the [mapping_details.sql](./sql/mapping_details.sql) script creates the reference table, populated for the sample structures plus an unused mapping for negative testing. The table created will look like this:

json_type   | json_path      | db_schema     | db_table    | db_column  
:-----------|:---------------|:--------------|:------------|:-----------
sample_json | text           | [null]        | sample      | pg_text    
sample_json | numeric        | [null]        | sample      | pg_numeric
sample_json | object,boolean | [null]        | sample      | pg_boolean
sample_json | object,null    | [null]        | sample      | pg_empty
sample_json | array,int      | [null]        | sample_2    | pg_int
sample_json | array,char     | [null]        | sample_2    | pg_char
sample_json | altObject,int  | alt_schema    | alt_table   | pg_int

This pattern can be repurposed for inserting real mapping details.

#### JSON format for mapping details

See [mappingDetails.json](./resources/mappingDetails.json) for the JSON equivalent of the above.

`test_stored_function_json_mapping.sql` includes the JSON-format mapping details as an argument in the function call.

`compare_json_to_postgres_standalone.sql` assigns the mapping JSON directly to a variable in the code block (with whitespace removed for ease of reading the code).

### Stored functions

Executing the [compare_json_to_postgres.sql](./sql/compare_json_to_postgres.sql) script will add the stored procedure `compare_json_to_postgres(par_json_type text, par_json json)` to the database. This procedure looks for mapping details in a database table.

Executing the [compare_json_to_postgres_json_mapping.sql](./sql/compare_json_to_postgres_json_mapping.sql) script will add the stored procedure `compare_json_to_postgres(par_json_type text, par_json json, par_mapping_details json)` to the database. This procedure requires mapping details to be supplied in JSON format.

When either of the above scripts is executed, a second function, `determine_query_conditions(par_json json, par_paths_with_columns text[][2])` is also created; this function may be called recursively if an array is encountered in the JSON. This helper function is identical for both variants of the main procedure.

*Note: both scripts use `CREATE FUNCTION` statements rather than `CREATE OR REPLACE FUNCTION`, to avoid accidentally overwriting existing functions. If both versions of the main procedure are required, the declaration for the helper function should be omitted when executing the second script.*

## Running the code

The `compare_json_to_postgres` stored procedure can be invoked as demonstrated in [test_stored_function.sql](./sql/test_stored_function.sql) or [test_stored_function_json_mapping.sql](./sql/test_stored_function_json_mapping.sql), for the sample data.

The `compare_json_to_postgres_standalone` DO block can be run as is. Values passed as arguments to the stored functions are assigned directly to variables in this version.

Results are output as `RAISE NOTICE` statements. In pgAdmin these are displayed on a separate tab in the Data Output panel:

![Where to find notices in pgAdmin interface](./resources/messages_in_pgadmin.png)

Additional information is available from `RAISE DEBUG` statements; by default these messages are not displayed but if required they can be viewed by changing the logging level (or changing the code to raise them at NOTICE level).

## Implementation notes

### Arrays

See [divergent_paths.md](./divergent_paths.md) for a breakdown of how associations in the JSON are maintained, including array handling.

Note: the query construction logic of `compare_json_to_postgres_standalone` differs from the stored functions, which rely on recursively calling a second stored function to easily process arrays. [recursion_algorithm.md](recursion_algorithm.md) describes the approach taken to create the standalone DO block.

All arrays are treated as unordered containers of objects. Arrays of simple values (like `[1, 2, 3]`) cannot currently be processed, and there is no handling of references to specific indices in an array:

    "arr" : [ {"a":"foo"} , {"a":"bar"} ]

-> path "arr,a" matches "foo" or "bar"; paths "arr,1" and "arr,1,a" match nothing.

Since `"1"` is a valid JSON key, the digit in "arr,1" could refer to either an array index or a field name, so significant changes would be needed to accommodate ordered arrays as well as generic arrays.

### Null values

If a mapped field is not present in the input JSON, it is expected to be `NULL` in the database. Caveat: for a given table, if all mapped fields are not present in the JSON, the comparison function will not match records where all mapped columns contain `NULL` - the record must include at least one value which is present in the JSON.

If a field exists in the JSON with value `null`, it is expected to be `NULL` in the database. This may allow the comparison function to match records where all mapped columns contain `NULL`, since at least one of those is a real match to the JSON (not inferred from an absent field). **IMPORTANT**: the standalone version may fail to match valid all-null records in some circumstances so should not be relied on if that scenario is likely.
