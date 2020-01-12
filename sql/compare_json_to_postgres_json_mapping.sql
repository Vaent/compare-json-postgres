--CREATE FUNCTION my_schema.compare_json_to_postgres(
CREATE FUNCTION compare_json_to_postgres(
  par_json_type text,
  par_json json,
  par_mapping_details json
)
RETURNS void
LANGUAGE plpgsql
AS $PROC$
DECLARE
  var_match_count int;
  var_message text;
  var_query text;
  var_schema_name text;
  var_table_name text;
  var_table_ref text;
BEGIN
  IF par_mapping_details::text NOT LIKE '[%]' THEN
    RAISE WARNING 'par_mapping_details argument must be a JSON array but was supplied as %', par_mapping_details;
  END IF;

  <<each_schema>>
  FOR var_schema_name IN
    SELECT DISTINCT value::json->>'db_schema'
      FROM json_array_elements(par_mapping_details)
      WHERE value::json->>'json_type' = par_json_type
  LOOP
    RAISE DEBUG 'schema: %', var_schema_name;

    <<each_table_in_schema>>
    FOR var_table_name IN
      SELECT DISTINCT value::json->>'db_table'
        FROM json_array_elements(par_mapping_details)
        WHERE value::json->>'json_type' = par_json_type
        AND CASE
          WHEN var_schema_name IS NULL THEN value::json->>'db_schema' IS NULL
          ELSE value::json->>'db_schema' = var_schema_name
          END
    LOOP
      RAISE DEBUG 'table: %', var_table_name;
      var_table_ref := CASE
        WHEN var_schema_name IS NULL THEN var_table_name
        ELSE var_schema_name || '.' || var_table_name
        END;
      IF to_regclass(var_table_ref) IS NULL THEN
        RAISE DEBUG 'Table % does not exist - skipping', var_table_ref;
        CONTINUE each_table_in_schema;
      END IF;

      --SELECT my_schema.determine_query_conditions(
      SELECT determine_query_conditions(
        par_json,
        (SELECT array_agg(ARRAY[value::json->>'json_path', value::json->>'db_column'])
          FROM json_array_elements(par_mapping_details)
          WHERE value::json->>'json_type' = par_json_type
          AND CASE
            WHEN var_schema_name IS NULL THEN value::json->>'db_schema' IS NULL
            ELSE value::json->>'db_schema' = var_schema_name
            END
          AND value::json->>'db_table' = var_table_name)
      ) INTO var_query;

      IF var_query = '' THEN
        RAISE NOTICE 'The JSON contains no fields associated with the "%" table', var_table_ref;
      ELSE
        var_query := 'SELECT COUNT(*) FROM ' || var_table_ref || ' WHERE ' || var_query;
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
    END LOOP each_table_in_schema;
  END LOOP each_schema;
END;
$PROC$;



--CREATE FUNCTION my_schema.determine_query_conditions
CREATE FUNCTION determine_query_conditions(
  par_json json,
  par_paths_with_columns text[][2]
)
RETURNS text
LANGUAGE plpgsql
AS $PROC$
DECLARE
  var_field_exists_in_json bool;
  var_path text[];
  var_path_children text[][2];
  var_path_parent text;
  var_path_with_column text[];
  var_query_statements text[];
  var_query_statements_for_array text[];
  var_value json;
  var_value_sub json;
BEGIN
  var_query_statements := '{}';
  var_field_exists_in_json := false;
  FOR n IN 1..array_length(par_paths_with_columns, 1)
  LOOP
    var_path := string_to_array(par_paths_with_columns[n][1], ',');
    var_value := par_json;
    <<get_json_value>>
    FOR x IN 1..array_length(var_path, 1)
    LOOP
      var_value := var_value #> ARRAY[var_path[x]];
      IF var_value::text LIKE '[%]' THEN
        var_path_parent := array_to_string(var_path[:x], ',') || ',';
        var_path := var_path[(x+1):];
        EXIT get_json_value;
      END IF;
    END LOOP get_json_value;

    IF var_value::text LIKE '[%]' THEN
      -- array handling
      var_path_children = ARRAY[ARRAY[]]::text[];
      <<each_path_column_pair>>
      FOREACH var_path_with_column SLICE 1 IN ARRAY par_paths_with_columns
      LOOP
        IF var_path_with_column[1] LIKE (var_path_parent || '%') THEN
          var_path_children := array_cat(
            var_path_children,
            ARRAY[ARRAY[REPLACE(var_path_with_column[1], var_path_parent, ''), var_path_with_column[2]]]
          );
        END IF;
      END LOOP each_path_column_pair;
      var_query_statements_for_array := '{}';
      <<prepare_array_statement>>
      FOREACH var_value_sub IN ARRAY ARRAY(SELECT json_array_elements(var_value))
      LOOP
        var_query_statements_for_array := array_append(
          var_query_statements_for_array,
          --(SELECT my_schema.determine_query_conditions(var_value_sub, var_path_children))
          (SELECT determine_query_conditions(var_value_sub, var_path_children))
        );
        var_query_statements_for_array := array_remove(var_query_statements_for_array, '');
      END LOOP prepare_array_statement;
      IF array_length(var_query_statements_for_array, 1) > 0 THEN
        var_field_exists_in_json := true;
        var_query_statements := array_append(
          var_query_statements,
          '((' || array_to_string(var_query_statements_for_array, ') OR (') || '))'
        );
      END IF;
      -- end array handling
    ELSE
      IF var_value IS NOT NULL THEN
        var_field_exists_in_json := true;
      END IF;
      var_query_statements := array_append(
        var_query_statements,
        par_paths_with_columns[n][2] || CASE
          WHEN (var_value IS NULL OR var_value::text = 'null') THEN ' IS NULL'
          WHEN var_value::text LIKE '"%"' THEN ' = $str$' || TRIM('"' FROM var_value::text) || '$str$'
          ELSE ' = ' || var_value
          END
      );
    END IF;
  END LOOP;
  IF var_field_exists_in_json THEN
    RETURN (array_to_string(var_query_statements, ' AND '));
  ELSE
    RETURN '';
  END IF;
END;
$PROC$;
