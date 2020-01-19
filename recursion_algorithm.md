# Algorithm for a loop to replace the recursive function calls

This change is to allow development of code which can be run without creating any functions, thereby retaining the benefits of the reusable code block without requiring any modifications to the database.

It will not be possible to resolve every JSON path fully when first inspected, as any arrays on the path require the path resolution logic to be applied to every subpath, for every element in the array, to compose the appropriate SELECT statement (see [divergent_paths.md](./divergent_paths.md) for details).

Instead, a mock table (array of JSON objects) will be used to track path resolution and associations derived from array structures. This is an extension of the 2D array previously passed to the helper function, adding fields as follows:

json_path | db_column | *group* | *root_json* | *value* | *resolved*

Each 'row' is represented by a JSON object rather than a nested array, as early POC work for the standalone function indicated this would be easier to manage, in particular with regard to adding rows to the table.

- `group` contains details of associations between values.
- `root_json` is equivalent to the helper function's `par_json` parameter.
- When an array is encountered, instead of calling the helper function for each subpath for each array element, rows are added to the table representing those function calls, with updated `json_path`, `group` and `root_json` entries. The rows representing the parent paths are removed as the subpath rows replace them.
- `value` and `resolved` are populated when each path is fully resolved.

A loop can then be created to cycle through rows in the table until all are marked as resolved. Resolution is not inferred from the presence of a value as fields in the JSON could contain null values, or the text values "NULL"/"<NULL>" etc.

## Logic

Existing logic can be repurposed to identify array subpaths and associate them with parent JSON fragments.

`group` is to be constructed as follows:
- the identifier for the base JSON object is `0-0`
- while following a path or subpath, whenever an array is encountered, an additional identifier is appended
- the first part of the identifier uniquely identifies the JSON array/path; it is obtained by checking the table for rows with the same parent group, identifying the highest value currently in use at the same level, and incrementing)
- the second part of the identifier uniquely identifies each element in the array

group         | description
:-------------|:------------
{0-0}         | any direct path from the root object
{0-0,0-0}     | subpaths of first array field under root object, first object in array
{0-0,0-1}     | subpaths of first array field under root object, second object in array
{0-0,0-0,0-0} | subpaths of first nested array field (under first object in first array field), first object in array
{0-0,0-1,0-0} | subpaths of first nested array field (under second object in first array field), first object in array
{0-0,1-0}     | subpaths of second array field under root object, first object in array
{0-0,1-1}     | subpaths of second array field under root object, second object in array

This maintains the associations which form the basis of AND/OR logic in the eventual SELECT statement:
```
{0-0}.x AND {0-0}.y
AND
(
  (
    {0-0,0-0}.f
    AND
    (
      (
        {0-0,0-0,0-0}.g AND {0-0,0-0,0-0}.h
      )
      OR
      (
        {0-0,0-0,0-1}.g AND {0-0,0-0,0-1}.h
      )
    )
  )
  OR
  (
    {0-0,0-1}.f
    AND...
  )
AND
(
  (
    {0-0,1-0}...
```
As seen in the example, fields with identical `group` are joined by AND clauses, then OR clauses are used where only the second part of the identifier differs (different elements in the same array), beginning with the deepest nested groups and working up the hierarchy.
