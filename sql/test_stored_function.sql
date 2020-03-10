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
  }'
)
