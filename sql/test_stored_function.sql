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
    ]
  }'
)