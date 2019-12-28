--CREATE FUNCTION my_schema.compare_json_to_postgres(
CREATE FUNCTION compare_json_to_postgres(
  par_json_type text,
  par_json json
)
RETURNS void
LANGUAGE plpgsql
AS $PROC$
DECLARE
  var_count_present_in_json int;
  var_db_values text[];
  var_first_condition bool;
  var_json_value json;
  --var_mapping my_schema.mapping_details%ROWTYPE;
  var_mapping mapping_details%ROWTYPE;
  var_match_count int;
  var_message text;
  var_query text;
  var_schema_name text;
  var_table_name text;
  var_table_ref text;
BEGIN
  FOR var_schema_name IN
    SELECT DISTINCT db_schema
      --FROM my_schema.mapping_details
      FROM mapping_details
      WHERE json_type = par_json_type
  LOOP
    RAISE DEBUG 'schema: %', var_schema_name;
    FOR var_table_name IN
      SELECT DISTINCT db_table
        --FROM my_schema.mapping_details
        FROM mapping_details
        WHERE json_type = par_json_type
        AND CASE
          WHEN var_schema_name IS NULL THEN db_schema IS NULL
          ELSE db_schema = var_schema_name
          END
    LOOP
      RAISE DEBUG 'table: %', var_table_name;
      var_table_ref := CASE
        WHEN var_schema_name IS NULL THEN var_table_name
        ELSE var_schema_name || '.' || var_table_name
        END;
      var_query := 'SELECT COUNT(*) FROM ' || var_table_ref;
      var_first_condition := true;
      var_count_present_in_json := 0;
      FOR var_mapping IN
        SELECT *
          --FROM my_schema.mapping_details
          FROM mapping_details
          WHERE json_type = par_json_type
          AND CASE
            WHEN var_schema_name IS NULL THEN db_schema IS NULL
            ELSE db_schema = var_schema_name
            END
          AND db_table = var_table_name
      LOOP
        var_json_value := par_json #> string_to_array((var_mapping).json_path, ',');
        IF var_json_value IS NOT NULL THEN 
          var_count_present_in_json := var_count_present_in_json + 1;
        END IF;
        RAISE DEBUG 'path "%" -> value "%"', (var_mapping).json_path, var_json_value;
        var_query := var_query || CASE
          WHEN var_first_condition = true THEN ' WHERE '
          ELSE ' AND '
          END;
        var_first_condition := false;
        var_query := var_query || (var_mapping).db_column;
        var_query := var_query || CASE
          WHEN (var_json_value IS NULL OR var_json_value::text = 'null') THEN ' IS NULL'
          WHEN var_json_value::text LIKE '"%"' THEN ' = ' || '$str$' || TRIM('"' FROM var_json_value::text) || '$str$'
          ELSE ' = ' || var_json_value
          END;
      END LOOP;
      IF var_count_present_in_json = 0 THEN
        RAISE NOTICE 'The JSON contains no fields associated with the "%" table', var_table_ref;
      ELSE
        RAISE DEBUG 'Executing query: %', var_query;
        EXECUTE var_query INTO var_match_count;
        var_message := '"' || var_table_ref || '" table contains ' || var_match_count
          || CASE
            WHEN var_match_count = 1 THEN ' record'
            ELSE ' records'
            END
          || ' matching the JSON';
        RAISE NOTICE '%', var_message;
      END IF;
    END LOOP;
  END LOOP;
END;
$PROC$;
