/*
   For the specified table, output the following information for each column:

   ColumnName
   DataType
   IsNullable (YES if nullable, blank otherwise)
   Constraints (e.g. Primary key, foreign key, unique)
   ReferencesColumn (if the column is a foreign key, the table and column it references)

   The example @Schema and @TableName parameters will return information for
   the 22 columns in the SalesLT.SalesOrderHeader from the AdventureWorksLT2010 database

   Author: Mike Smith
   Date:   7/15/2020
*/

DECLARE @Schema VARCHAR(100), @TableName VARCHAR(100)

Select @Schema  = 'SalesLT'
, @TableName = 'SalesOrderHeader'


DECLARE @TableDefinition TABLE
(
    TableName VARCHAR(100) NOT NULL
  , ColumnName VARCHAR(100) NOT NULL
  , DataType VARCHAR(100) NOT NULL
  , Size INT NULL
  , IsNullable VARCHAR(10) NOT NULL
  , Constraints VARCHAR(100) NULL
  , ReferencesColumn VARCHAR(100) NULL
  , Position INT NOT NULL
)

INSERT @TableDefinition
(
    TableName
  , ColumnName
  , DataType
  , Size
  , IsNullable
  , Constraints
  , ReferencesColumn
  , Position
)
SELECT @TableName
     , COLUMN_NAME
     , UPPER(DATA_TYPE) AS DataType
     , CHARACTER_MAXIMUM_LENGTH
     , CASE IS_NULLABLE
           WHEN 'YES' THEN
               'YES'
           ELSE
               ''
       END AS IsNullable
     , '' AS Constraints
     , '' AS ReferencesColumn
     , ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = @Schema
      AND TABLE_NAME = @TableName
ORDER BY ORDINAL_POSITION


UPDATE @TableDefinition
SET DataType = CASE Size
                   WHEN -1 THEN
                       DataType + ' (MAX)'
                   ELSE
                       DataType + ' (' + LTRIM(STR(Size)) + ')'
               END
WHERE Size IS NOT NULL


UPDATE td
SET td.Constraints = tc.CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
                                                    AND tc.TABLE_CATALOG = kcu.TABLE_CATALOG
                                                    AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                                                    AND tc.TABLE_NAME = kcu.TABLE_NAME
    JOIN @TableDefinition td ON td.ColumnName = kcu.COLUMN_NAME
WHERE tc.TABLE_SCHEMA = @Schema
      AND tc.TABLE_NAME = @TableName


UPDATE td
SET td.ReferencesColumn = SCHEMA_NAME(ref_tab.schema_id) + '.' + ref_tab.name + '.' + ref_col.name
FROM sys.tables t 
    JOIN sys.columns col ON col.object_id = t.object_id
    JOIN @TableDefinition td ON t.name = td.TableName
                                AND col.name = td.ColumnName
    LEFT JOIN sys.foreign_key_columns fk_cols ON fk_cols.parent_object_id = t.object_id
                                                 AND fk_cols.parent_column_id = col.column_id
    LEFT JOIN sys.foreign_keys fk ON fk.object_id = fk_cols.constraint_object_id
    LEFT JOIN sys.tables ref_tab ON ref_tab.object_id = fk_cols.referenced_object_id
    LEFT JOIN sys.columns ref_col ON ref_col.column_id = fk_cols.referenced_column_id
                                    AND ref_col.object_id = fk_cols.referenced_object_id
WHERE t.name = @TableName


SELECT ColumnName
     , DataType
     , IsNullable
     , Constraints
     , COALESCE(ReferencesColumn, '') AS ReferencesColumn
FROM @TableDefinition

