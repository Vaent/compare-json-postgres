DO $PROC$
DECLARE
  par_json_type text;
  par_json jsonb;
  par_mapping_details jsonb;

  var_group_array_element int;
  var_group_array_index int;
  var_group_combo jsonb;
  var_group_parent jsonb[];
  var_index int;
  var_match_count int;
  var_max_group_length int;
  var_message text;
  var_path text[];
  var_path_children jsonb[];
  var_path_parent text;
  var_query text;
  var_query_statements jsonb[];
  var_query_statements_temp jsonb[];
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
  par_json = '{"text":"A string of characters","numeric":123.456,"object":{"boolean":true,"null":null},"array":[{"int":1234,"char":"a"},{"fake":67,"faker":"j"},{"int":9,"char":"z"}],"array2":[{"bool":true,"array3":[{"string":"a2-0-a3-0","int":0},{"string":"a2-0-a3-1","int":1}],"array4":[{"a":"04a","b":"04b"}]},{"bool":false,"array3":[{"string":"a2-1-a3-0","int":10},{"string":"a2-1-a3-1","int":11}],"array4":[{"a":"14a","b":"14b"},{"a":"24a","b":"24b"}]}]}';
  par_mapping_details  = '[{"json_type":"sample_json","json_path":"text","db_schema":null,"db_table":"sample","db_column":"pg_text"},{"json_type":"sample_json","json_path":"numeric","db_schema":null,"db_table":"sample","db_column":"pg_numeric"},{"json_type":"sample_json","json_path":"object,boolean","db_schema":null,"db_table":"sample","db_column":"pg_boolean"},{"json_type":"sample_json","json_path":"object,null","db_schema":null,"db_table":"sample","db_column":"pg_empty"},{"json_type":"sample_json","json_path":"array,int","db_schema":null,"db_table":"sample_2","db_column":"pg_int"},{"json_type":"sample_json","json_path":"array,char","db_schema":null,"db_table":"sample_2","db_column":"pg_char"},{"json_type":"sample_json","json_path":"altObject,int","db_schema":"alt_schema","db_table":"alt_table","db_column":"pg_int"},{"json_type":"sample_json","json_path":"array2,bool","db_schema":null,"db_table":"sample_3","db_column":"pg_arr2_bool"},{"json_type":"sample_json","json_path":"array2,array3,string","db_schema":null,"db_table":"sample_3","db_column":"pg_arr3_string"},{"json_type":"sample_json","json_path":"array2,array3,int","db_schema":null,"db_table":"sample_3","db_column":"pg_arr3_int"},{"json_type":"sample_json","json_path":"array2,array4,a","db_schema":null,"db_table":"sample_3","db_column":"pg_arr4_a"},{"json_type":"sample_json","json_path":"array2,array4,b","db_schema":null,"db_table":"sample_3","db_column":"pg_arr4_b"}]';

  IF jsonb_typeof(par_mapping_details) != 'array' THEN
    RAISE WARNING 'par_mapping_details argument must be a JSON array but was supplied as %', par_mapping_details;
  END IF;

  <<each_schema>>
  FOR var_schema_name IN
    SELECT DISTINCT value::json ->> 'db_schema'
      FROM jsonb_array_elements(par_mapping_details)
      WHERE value::json ->> 'json_type' = par_json_type
  LOOP
    RAISE DEBUG 'schema: %', var_schema_name;

    <<each_table_in_schema>>
    FOR var_table_name IN
      SELECT DISTINCT value::json ->> 'db_table'
        FROM jsonb_array_elements(par_mapping_details)
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
        FROM jsonb_array_elements(par_mapping_details)
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
        <<get_json_parent>>
        FOR x IN 1..(array_length(var_path, 1) - 1)
        LOOP
          var_value := var_value #> ARRAY[var_path[x]];
          IF jsonb_typeof(var_value) = 'array' THEN
            var_path_parent := array_to_string(var_path[:x], ',') || ',';
            SELECT array_agg(jsonb_array_elements)
              FROM jsonb_array_elements(var_row -> 'group')
            INTO var_group_parent;
            EXIT get_json_parent;
          END IF;
        END LOOP get_json_parent;

        IF jsonb_typeof(var_value) = 'array' THEN
          -- array handling; a new unresolved row is added to var_resolution_table for each array entry
          var_path_children := ARRAY[]::text[];
          var_index = 1;
          var_rows_left_to_inspect = array_length(var_resolution_table, 1);
          <<get_array_descendants>>
          LOOP
            IF var_index > var_rows_left_to_inspect THEN
              EXIT get_array_descendants;
            END IF;
            IF (var_resolution_table[var_index] ->> 'json_path') LIKE (var_path_parent || '%')
            AND (SELECT array_agg(jsonb_array_elements) FROM jsonb_array_elements(var_resolution_table[var_index] -> 'group')) = var_group_parent
            THEN
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
            SELECT COALESCE(MAX((string_to_array(grp ->> array_length(var_group_parent, 1), '-'))[1]::int), -1) + 1
              FROM (SELECT unnest(var_resolution_table || var_path_children) -> 'group' AS grp) as g
              WHERE (SELECT array_agg(jsonb_array_elements) FROM jsonb_array_elements(grp))[:array_length(var_group_parent, 1)] = var_group_parent
            INTO var_group_array_index;
            var_group_array_element = 0;
            <<each_array_element>>
            FOREACH var_value_sub IN ARRAY ARRAY(SELECT jsonb_array_elements(var_value))
            LOOP
              var_group_combo = to_jsonb(var_group_array_index || '-' || var_group_array_element);
              FOREACH var_row IN ARRAY var_path_children
              LOOP
                var_row := jsonb_set(var_row, ARRAY['group'], var_row -> 'group' || var_group_combo);
                var_row := jsonb_set(var_row, ARRAY['root_json'], var_value_sub);
                var_resolution_table := var_resolution_table || var_row;
              END LOOP;
              var_group_array_element := var_group_array_element + 1;
            END LOOP each_array_element;
          END IF;
          -- end array handling
        ELSE
          var_resolution_table := array_remove(var_resolution_table, var_row);
          -- to finalise the row, the JSON value is captured as a comparator which will be used in a query
          -- the transformation is done at this stage to better distinguish between null values and absent fields
          IF var_value -> var_path[array_length(var_path, 1)] = 'null' THEN
            -- this captures null values in the JSON
            var_row := jsonb_set(var_row, '{value}', '"=null"'::jsonb);
          ELSIF var_value ->> var_path[array_length(var_path, 1)] IS NULL THEN
            -- this captures missing fields
            var_row := jsonb_set(var_row, '{value}', '" IS NULL"'::jsonb);
          ELSE
            -- for non-null fields, get the value as text and wrap in single quotes (this is necessary for JSON strings and is valid for other data types)
            var_row := jsonb_set(var_row, '{value}', ('"=''' || (var_value ->> var_path[array_length(var_path, 1)]) || '''"')::jsonb);
          END IF;
          var_row := jsonb_set(var_row, '{resolved}', 'true'::jsonb);
          var_resolution_table := var_resolution_table || var_row;
        END IF;
      END LOOP get_values_from_json;

      RAISE DEBUG 'Resolved values for table %: %', var_table_ref, jsonb_pretty(to_jsonb(var_resolution_table));


      SELECT MAX(jsonb_array_length(vrt -> 'group'))
        FROM unnest(var_resolution_table) vrt
      INTO var_max_group_length;
      var_query_statements := ARRAY[]::jsonb[];

      <<prepare_query_statements>>
      WHILE var_max_group_length > 0
      LOOP
        RAISE DEBUG 'Preparing query statements for nesting level %', var_max_group_length;

        -- for the current nesting level, get relevant rows from the initial 'resolution table'
        SELECT array_agg(jsonb_build_object(
            'group', vrt -> 'group',
            'subquery', (vrt ->> 'db_column') || (vrt ->> 'value')
          ))
          FROM unnest(var_resolution_table) vrt
          WHERE jsonb_array_length(vrt -> 'group') = var_max_group_length
        INTO var_query_statements_temp;

        -- if no further processing needed, skip to next loop iteration to reduce debug clutter
        IF var_query_statements_temp IS NULL OR array_length(var_query_statements_temp, 1) < 1 THEN
          var_max_group_length := var_max_group_length - 1;
          CONTINUE prepare_query_statements;
        END IF;

        -- combine the new rows with any statements prepared in the previous iteration of <<prepare_query_statements>>
        var_query_statements := var_query_statements || var_query_statements_temp;

        -- merge the conditions for rows with identical 'group' (different fields on a simple object)
        SELECT array_agg(jsonb_build_object(
            'group', grp,
            'subquery', concat_ws(
              ' AND ',
              VARIADIC (SELECT array_agg(vqs ->> 'subquery')
                FROM unnest(var_query_statements) vqs
                WHERE (vqs -> 'group') = grp)
            )))
          FROM (
            SELECT DISTINCT (vqs -> 'group') grp
              FROM unnest(var_query_statements) vqs
            ) groups
        INTO var_query_statements;

        var_query_statements_temp := ARRAY[]::jsonb[];
        var_index := 1;
        <<process_null_conditions>>
        WHILE var_index <= array_length(var_query_statements, 1)
        LOOP
          IF jsonb_array_length(var_query_statements[var_index] -> 'group') = var_max_group_length THEN
            var_row := var_query_statements[var_index];
            -- identify JSON null values and update those conditions
            IF (var_row ->> 'subquery') ~ '.*=null.*' THEN
              var_row := jsonb_set(var_row, '{subquery}', to_jsonb(regexp_replace(var_row ->> 'subquery', '=null', ' IS NULL', 'g')));
            -- delete statement if it relates only to fields which are not present in the JSON
            ELSIF NOT ((var_row ->> 'subquery') ~ '.*=.*') THEN
              var_row := NULL;
            END IF;
            IF var_row IS NOT NULL THEN
              var_query_statements_temp := var_query_statements_temp || var_row;
            END IF;
            var_query_statements := var_query_statements[:var_index - 1] || var_query_statements[var_index + 1:];
          ELSE
            var_index := var_index + 1;
          END IF;
        END LOOP process_null_conditions;

        var_query_statements := var_query_statements || var_query_statements_temp;

        RAISE notice 'First partial query statements (identical groups): %', jsonb_pretty(to_jsonb(var_query_statements));

        -- if no further processing needed, skip to next loop iteration to reduce debug clutter
        IF array_length(var_query_statements, 1) < 2 THEN
          var_max_group_length := var_max_group_length - 1;
          CONTINUE prepare_query_statements;
        END IF;

        -- combine statements for different elements in the same array
        -- at the same time, remove the last element of 'group' to indicate this nesting level is resolved
        SELECT array_agg(jsonb_build_object(
            'group', parent_grp,
            'subquery', '(' || concat_ws(
              ' OR ',
              VARIADIC (SELECT array_agg(vqs ->> 'subquery')
                FROM unnest(var_query_statements) vqs
                WHERE (string_to_array((vqs -> 'group') ->> (var_max_group_length - 1), '-'))[1] = array_id AND (vqs -> 'group') - (var_max_group_length - 1) = parent_grp)
            ) || ')'
          ))
          FROM (
            SELECT DISTINCT
                (vqs -> 'group') - (var_max_group_length - 1) parent_grp,
                (string_to_array((vqs -> 'group') ->> (var_max_group_length - 1), '-'))[1] array_id
              FROM unnest(var_query_statements) vqs
            ) groups
        INTO var_query_statements;

        -- var_query_statements := var_query_statements || var_query_statements_temp;

        RAISE notice 'Second partial query statements (different elements in same array): %', jsonb_pretty(to_jsonb(var_query_statements));

        var_max_group_length := var_max_group_length - 1;
      END LOOP prepare_query_statements;

      IF array_length(var_query_statements, 1) <> 1 THEN
        RAISE EXCEPTION E'A problem occurred while preparing the query for table "%".\nPartial statements produced were: %', var_table_ref, var_query_statements;
        -- RAISE NOTICE 'The JSON contains no fields associated with the "%" table', var_table_ref;
      ELSE
        var_query := 'SELECT COUNT(*) FROM ' || var_table_ref || ' WHERE ' || (var_query_statements[1] ->> 'subquery');
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
