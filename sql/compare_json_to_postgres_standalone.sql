DO $PROC$
DECLARE
  par_json_type text;
  par_json json;
  par_mapping_details json;

  var_index int;
  var_match_count int;
  var_message text;
  var_path text[];
  var_path_children jsonb[];
  var_path_parent text;
  var_query text;
  -- var_query_statements text[];
  -- var_query_statements_for_array text[];
  var_grp_array_element int;
  var_grp_full_ref jsonb;
  var_resolution_table jsonb[];
  var_row jsonb;
  var_rows_left_to_inspect int;
  var_schema_name text;
  var_table_name text;
  var_table_ref text;
  var_value jsonb;
  var_value_sub jsonb;
BEGIN
  par_json_type = 'sample_json';
  par_json = '{"text":"A string of characters","numeric":123.456,"object":{"boolean":true,"null":null},"array":[{"int":1234,"char":"a"},{"fake":67,"faker":"j"},{"int":9,"char":"z"}]}';
  par_mapping_details  = '[{"json_type":"sample_json","json_path":"text","db_schema":null,"db_table":"sample","db_column":"pg_text"},{"json_type":"sample_json","json_path":"numeric","db_schema":null,"db_table":"sample","db_column":"pg_numeric"},{"json_type":"sample_json","json_path":"object,boolean","db_schema":null,"db_table":"sample","db_column":"pg_boolean"},{"json_type":"sample_json","json_path":"object,null","db_schema":null,"db_table":"sample","db_column":"pg_empty"},{"json_type":"sample_json","json_path":"array,int","db_schema":null,"db_table":"sample_2","db_column":"pg_int"},{"json_type":"sample_json","json_path":"array,char","db_schema":null,"db_table":"sample_2","db_column":"pg_char"},{"json_type":"sample_json","json_path":"altObject,int","db_schema":"alt_schema","db_table":"alt_table","db_column":"pg_int"}]';

  IF json_typeof(par_mapping_details) != 'array' THEN
    RAISE WARNING 'par_mapping_details argument must be a JSON array but was supplied as %', par_mapping_details;
  END IF;

  <<each_schema>>
  FOR var_schema_name IN
    SELECT DISTINCT value::json ->> 'db_schema'
      FROM json_array_elements(par_mapping_details)
      WHERE value::json ->> 'json_type' = par_json_type
  LOOP
    RAISE DEBUG 'schema: %', var_schema_name;

    <<each_table_in_schema>>
    FOR var_table_name IN
      SELECT DISTINCT value::json ->> 'db_table'
        FROM json_array_elements(par_mapping_details)
        WHERE value::json ->> 'json_type' = par_json_type
        AND CASE
          WHEN var_schema_name IS NULL THEN value::json ->> 'db_schema' IS NULL
          ELSE value::json ->> 'db_schema' = var_schema_name
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

      -- prepare initial 'path resolution table'
      SELECT array_agg(jsonb_build_object(
          'json_path', value::json ->> 'json_path',
          'db_column', value::json ->> 'db_column',
          'group', ARRAY['0-0'],
          'root_json', par_json,
          'resolved', false))
        FROM json_array_elements(par_mapping_details)
        WHERE value::json ->> 'json_type' = par_json_type
        AND CASE
          WHEN var_schema_name IS NULL THEN value::json ->> 'db_schema' IS NULL
          ELSE value::json ->> 'db_schema' = var_schema_name
          END
        AND value::json ->> 'db_table' = var_table_name
      INTO var_resolution_table;

      <<get_values_from_json>>
      LOOP
        SELECT unnest FROM unnest(var_resolution_table)
          WHERE NOT (unnest ->> 'resolved')::bool
          LIMIT 1
          INTO var_row;
        IF var_row IS NULL THEN
          EXIT get_values_from_json;
        END IF;

        var_path := string_to_array(var_row ->> 'json_path', ',');
        var_value := var_row ->> 'root_json';
        <<get_json_value>>
        FOR x IN 1..array_length(var_path, 1)
        LOOP
          var_value := var_value #> ARRAY[var_path[x]];
          IF jsonb_typeof(var_value) = 'array' THEN
            var_path_parent := array_to_string(var_path[:x], ',') || ',';
            EXIT get_json_value;
          END IF;
        END LOOP get_json_value;

        IF jsonb_typeof(var_value) = 'array' THEN
          -- array handling
          var_path_children := ARRAY[]::text[];
          var_index = 1;
          var_rows_left_to_inspect = array_length(var_resolution_table, 1);
          <<get_array_descendants>>
          LOOP
            IF var_index > var_rows_left_to_inspect THEN
              EXIT get_array_descendants;
            END IF;
            IF (var_resolution_table[var_index] ->> 'json_path') LIKE (var_path_parent || '%') THEN
              var_path_children := var_path_children ||
                jsonb_build_object(
                  'json_path', REPLACE(var_resolution_table[var_index] ->> 'json_path', var_path_parent, ''),
                  'db_column', var_resolution_table[var_index] ->> 'db_column',
                  'group', (var_resolution_table[var_index] -> 'group'),
                  'resolved', false
                );
              var_resolution_table := var_resolution_table[:var_index - 1] || var_resolution_table[var_index + 1:];
              var_rows_left_to_inspect := var_rows_left_to_inspect - 1;
            ELSE
              var_index := var_index + 1;
            END IF;
          END LOOP get_array_descendants;

          IF array_length(var_path_children, 1) > 0 THEN
            var_grp_array_element = 0;
            <<each_array_element>>
            FOREACH var_value_sub IN ARRAY ARRAY(SELECT jsonb_array_elements(var_value))
            LOOP
              var_grp_full_ref = to_jsonb(0 || '-' || var_grp_array_element);
              FOREACH var_row IN ARRAY var_path_children
              LOOP
                var_row := jsonb_set(var_row, ARRAY['group'], var_row -> 'group' || var_grp_full_ref);
                var_row := jsonb_set(var_row, ARRAY['root_json'], var_value_sub);
                var_resolution_table := var_resolution_table || var_row;
              END LOOP ;
              var_grp_array_element := var_grp_array_element + 1;
            END LOOP each_array_element;
          END IF;
          -- var_query_statements_for_array := '{}';
          -- <<prepare_array_statement>>
          -- FOREACH var_value_sub IN ARRAY ARRAY(SELECT json_array_elements(var_value))
          -- LOOP
          --   var_query_statements_for_array := array_append(
          --     var_query_statements_for_array,
          --     (SELECT determine_query_conditions(var_value_sub, var_path_child_rows))
          --   );
          --   var_query_statements_for_array := array_remove(var_query_statements_for_array, '');
          -- END LOOP prepare_array_statement;
          -- IF array_length(var_query_statements_for_array, 1) > 0 THEN
          --   var_query_statements := array_append(
          --     var_query_statements,
          --     '((' || array_to_string(var_query_statements_for_array, ') OR (') || '))'
          --   );
          -- END IF;
          -- end array handling
        ELSE
          var_resolution_table := array_remove(var_resolution_table, var_row);
          IF var_value IS NULL THEN
            var_row := jsonb_set(var_row, '{value}', 'null');
          ELSE
            var_row := jsonb_set(var_row, '{value}', var_value);
          END IF;
          var_row := jsonb_set(var_row, '{resolved}', 'true'::jsonb);
          var_resolution_table := var_resolution_table || var_row;
        END IF;
      END LOOP get_values_from_json;

      RAISE DEBUG 'Resolved values for table %: %', var_table_ref, jsonb_pretty(to_jsonb(var_resolution_table));




      -- var_query_statements := array_append(
      --   var_query_statements,
      --   var_row ->> 'db_column' || CASE
      --     WHEN (var_value IS NULL OR var_value::text = 'null') THEN ' IS NULL'
      --     WHEN var_value::text LIKE '"%"' THEN ' = $str$' || TRIM('"' FROM var_value::text) || '$str$'
      --     ELSE ' = ' || var_value
      --     END
      -- );



      -- IF var_query = '' THEN
      --   RAISE NOTICE 'The JSON contains no fields associated with the "%" table', var_table_ref;
      -- ELSE
      --   var_query := 'SELECT COUNT(*) FROM ' || var_table_ref || ' WHERE ' || var_query;
      --   RAISE DEBUG 'Executing query: %', var_query;
      --   EXECUTE var_query INTO var_match_count;
      --   var_message := '"' || var_table_ref || '" table contains ' || var_match_count
      --     || CASE
      --       WHEN var_match_count = 1 THEN ' record'
      --       ELSE ' records'
      --       END
      --     || ' matching the JSON';
      --   RAISE NOTICE '%', var_message;
      -- END IF;
    END LOOP each_table_in_schema;
  END LOOP each_schema;
END;
$PROC$;
