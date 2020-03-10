# Resolving JSON paths

The function has been developed based on an assumption that each column in the database will store a single simple value, not a collection (array, composite type...)

In the simplest case, each JSON path references a single value:
```
{
  "first" : {
    "second" : {
      "third" : 3
    },
    "extra" : 0
  }
}
```
-> path "first,second,third" = 3, path "first,extra" = 0

If arrays are present anywhere on a path, that path may reference multiple values:
```
{
  "first" : {
    "second" : [
      { "third" : 31 },
      { "third" : 32 }
    ],
    "extra" : [0, 1]
  }
}
```
-> path "first,second,third" = (31 OR 32), path "first,extra" = (0 OR 1)

A further assumption is made that associations in the JSON should be maintained in the database:
```
{
  "first" : {
    "second" : [
      {
        "third" : 31,
        "fourth" : 41
      },
      {
        "third" : 32,
        "fourth" : 42
      }
    ]
  }
}
```
-> records matching ("first,second,third" = 31 AND "first,second,fourth" = 41) OR ("first,second,third" = 32 AND "first,second,fourth" = 42) are valid representations of the JSON data; any other combination, e.g. 31 with 42, is not valid.

## Summary

Each distinct path produces 'AND-style' conditions in the SQL; each array 'node' in the JSON produces 'OR-style' conditions in the SQL; conditions for subpaths below an array node must be located under the array condition rather than at the top level.

    {
      "array1" : [
        {
          "one" : 11,
          "two" : 21
        },
        {
          "one" : 12,
          "two" : 22
        }
      ],
      "array2" : [
        { "three" : 31 },
        { "three" : 32 },
        { "three" : 33 }
      ],
      "four" : 4
    }

    SELECT * FROM records WHERE
      (
        (one = 11 AND two = 21)
        OR
        (one = 12 AND two = 22)
      )
      AND
      (three = 31 OR three = 32 OR three = 33)
      AND
      four = 4;

Note: a separate query is produced for each table, so if the contents of "array1" and "array2" were stored in different tables there would be two queries with fewer valid combinations than the above example.
