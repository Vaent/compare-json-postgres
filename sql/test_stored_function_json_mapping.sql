--SELECT my_schema.compare_json_to_postgres(
SELECT compare_json_to_postgres(
  'sample_json',
  '{
    "text" : "A string of characters",
    "numeric" : 123.456,
    "object" : {
      "boolean" : true,
      "null" : null
    },
    "array" : [
      {
        "int" : 1234,
        "char" : "a"
      },
      {
        "fake" : 67,
        "faker" : "j"
      },
      {
        "int" : 9,
        "char" : "z"
      }
    ],
    "array2" : [
      {
        "bool" : true,
        "array3" : [
          {
            "string" : "a2-0-a3-0",
            "int" : 0
          },
          {
            "string" : "a2-0-a3-1",
            "int" : 1
          }
        ],
        "array4" : [
          {
            "a" : "04a",
            "b" : "04b"
          }
        ]
      },
      {
        "bool" : false,
        "array3" : [
          {
            "string" : "a2-1-a3-0",
            "int" : 10
          },
          {
            "string" : "a2-1-a3-1",
            "int" : 11
          }
        ],
        "array4" : [
          {
            "a" : "14a",
            "b" : "14b"
          },
          {
            "a" : "24a",
            "b" : "24b"
          }
        ]
      }
    ]
  }',
  '[
    {
      "json_type" : "sample_json",
      "json_path" : "text",
      "db_schema" : null,
      "db_table" : "sample",
      "db_column" : "pg_text"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "numeric",
      "db_schema" : null,
      "db_table" : "sample",
      "db_column" : "pg_numeric"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "object,boolean",
      "db_schema" : null,
      "db_table" : "sample",
      "db_column" : "pg_boolean"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "object,null",
      "db_schema" : null,
      "db_table" : "sample",
      "db_column" : "pg_empty"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array,int",
      "db_schema" : null,
      "db_table" : "sample_2",
      "db_column" : "pg_int"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array,char",
      "db_schema" : null,
      "db_table" : "sample_2",
      "db_column" : "pg_char"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "altObject,int",
      "db_schema" : "alt_schema",
      "db_table" : "alt_table",
      "db_column" : "pg_int"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array2,bool",
      "db_schema" : null,
      "db_table" : "sample_3",
      "db_column" : "pg_arr2_bool"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array2,array3,string",
      "db_schema" : null,
      "db_table" : "sample_3",
      "db_column" : "pg_arr3_string"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array2,array3,int",
      "db_schema" : null,
      "db_table" : "sample_3",
      "db_column" : "pg_arr3_int"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array2,array4,a",
      "db_schema" : null,
      "db_table" : "sample_3",
      "db_column" : "pg_arr4_a"
    },
    {
      "json_type" : "sample_json",
      "json_path" : "array2,array4,b",
      "db_schema" : null,
      "db_table" : "sample_3",
      "db_column" : "pg_arr4_b"
    }
  ]'
)
