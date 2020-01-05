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
```
{
  "one" : [
    {
      "two" : 21,
      "three" : 31
    },
    {
      "two" : 22,
      "three" : 32
    }
  ],
  "four" : [41, 42, 43],
  "five" : 5
}
```
```
SELECT * FROM records WHERE
  (
    (two = 21 AND three = 31)
    OR
    (two = 22 AND three = 32)
  )
  AND
  (four = 41 OR four = 42 OR four = 43)
  AND
  five = 5;
```
Note: a separate query is produced for each table, so if the contents of "one" and "four" were stored in different tables there would be two queries with fewer valid combinations than the above example.
