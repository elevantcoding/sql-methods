' =======================================================================================
' this script performs as safe, dynamic, differential data synchronization between a local
' SQL Server database and an Azure SQL database (via linked server).  It updates a local table by inserting
' only the missing rows found in Azure without hardcoding column names and allowing identity insert for
' identity columns only
=========================================================================================

IF @@SERVERNAME LIKE '%LOCALSERVERNAME%'
    USE DATABASENAME
    GO

    DECLARE @devrowcount int;
    DECLARE @azurerowcount int;
    DECLARE @schema sysname;
    DECLARE @table sysname;
    DECLARE @local nvarchar(max);
    DECLARE @azuresql nvarchar(max);
    DECLARE @sql nvarchar(max);
    DECLARE @cols nvarchar(max);
    DECLARE @colsalias nvarchar(max);
    DECLARE @keycol sysname;
    DECLARE @isidentity bit;
    DECLARE @rowsinserted int;
    DECLARE @getrowcount int;
    
    -- specify table name to update, use for sys tables and function calls
    SET @schema = 'SchemaName'
    SET @table = 'TableName'

    -- get table recordcounts from local and Azure / uses Azure as linked server
    SET @local = N'SELECT @recordcount = COUNT(*) FROM ' + QUOTENAME(@schema) + '.' + QUOTENAME(@table) + ';'
    EXEC sp_executesql @local, N'@recordcount INT OUTPUT', @devrowcount OUTPUT;

    SET @azuresql = N'SELECT @recordcount = COUNT(*) FROM [AZURE].[DATABASENAME].' + QUOTENAME(@schema) + '.' + QUOTENAME(@table) + ';'
    EXEC sp_executesql @azuresql, N'@recordcount INT OUTPUT', @azurerowcount OUTPUT;

    -- if matching rowcount, nothing to update, return
    IF @devrowcount = @azurerowcount
        BEGIN
            PRINT 'Matching row counts.';
            RETURN;
        END

    -- initialize row count
    SET @getrowcount = 0;

    -- string aggregate column names for @gettable for insert and one as table alias a., do not include computed or rowversion columns
    SELECT 
        @cols = STRING_AGG(CONCAT('[',c.name,']'), ', '),
        @colsalias = STRING_AGG(CONCAT('a.[',c.name,']'), ', ')
        FROM sys.columns c
        INNER JOIN sys.tables t ON c.object_id = t.object_id
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
        INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
        WHERE t.schema_id = 1 
	        AND s.name = @schema
	        AND t.name = @table
            AND c.is_computed = 0       -- exclude computed columns
            AND ty.name <> 'timestamp'; --exclude rowversioning columns
                               
            
    -- get @schema, @table key column and determine whether is identity
    SELECT @keycol = dbo.GetPrimaryKeyCol(@schema, @table);
    SELECT @isidentity = dbo.PrimaryKeyColIsIdentity(@schema, @table);
    
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
        BEGIN TRY
        
            BEGIN TRAN;        
            
            -- if @keycol is identity, set identity insert on            
            -- define insert statement for differentials only
            IF @isidentity = 1
                BEGIN
                SET @sql = 
                      N'SET IDENTITY_INSERT ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N' ON; '
                    + N'INSERT INTO ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N'(' + @cols 
                    + N') SELECT ' + @colsalias 
                    + N' FROM [AZURE].[DATABASENAME].' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + ' a LEFT JOIN ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table)
                    + N' b ON a.' + QUOTENAME(@keycol) + N' = b.' + QUOTENAME(@keycol) + N' WHERE b.' + QUOTENAME(@keycol) + N' IS NULL; '
                    + N' SET @rowsinserted = @@ROWCOUNT; '
                    + N'SET IDENTITY_INSERT ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N' OFF;';
                END
            ELSE
                BEGIN
                SET @sql =
                      N'INSERT INTO ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N'(' + @cols + N') '
                    + N'SELECT ' + @colsalias
                    + N' FROM [AZURE].[DATABASENAME].' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N' a LEFT JOIN ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table)
                    + N' b ON a.' + QUOTENAME(@keycol) + N' = b.' + QUOTENAME(@keycol) + N' WHERE b.' + QUOTENAME(@keycol) + N' IS NULL; '
                    + N' SET @rowsinserted = @@ROWCOUNT; '
                END

            EXEC sp_executesql @sql, N'@rowsinserted INT OUTPUT', @rowsinserted OUTPUT;
            SET @getrowcount += @rowsinserted;

            COMMIT;

        END TRY

        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            IF @isidentity = 1
                BEGIN
                    SET @sql = N'SET IDENTITY_INSERT ' + QUOTENAME(@schema) + N'.'  + QUOTENAME(@table) + N' OFF;';
	                EXEC sp_executesql @sql;
                END
            SET @getrowcount = 0;    
            THROW;
        END CATCH;

    -- display row count
    SELECT RowsInserted = @getrowcount;

-- function to return the name of a table's primary key column
ALTER FUNCTION [dbo].[GetPrimaryKeyCol]
(@schemaname sysname, @tablename sysname)
RETURNS sysname
AS
BEGIN
    DECLARE @columnname AS sysname;
    SELECT @columnname = c.name
    FROM   sys.tables AS t
           INNER JOIN
           sys.schemas AS s
           ON t.schema_id = s.schema_id
           INNER JOIN
           sys.indexes AS i
           ON t.object_id = i.object_id
              AND i.is_primary_key = 1
           INNER JOIN
           sys.index_columns AS icx
           ON i.object_id = icx.object_id
              AND i.index_id = icx.index_id
           INNER JOIN
           sys.columns AS c
           ON icx.object_id = c.object_id
              AND icx.column_id = c.column_id
           INNER JOIN
           sys.types AS ty
           ON c.user_type_id = ty.user_type_id
           LEFT OUTER JOIN
           sys.identity_columns AS ic
           ON t.object_id = ic.object_id
              AND c.column_id = ic.column_id
    WHERE s.name = @schemaname
    	AND t.name = @tablename;
    RETURN @columnname;
END
GO

-- function to return bit / boolean as to whether a primary key column is an identity column
ALTER FUNCTION [dbo].[PrimaryKeyColIsIdentity]
(@schemaname sysname, @tablename sysname)
RETURNS BIT
AS
BEGIN
    DECLARE @isidentity AS BIT;
    SET @isidentity = 0;
    SELECT @isidentity = CASE WHEN ic.column_id IS NOT NULL THEN 1 ELSE 0 END
    FROM   sys.tables AS t
           INNER JOIN
           sys.schemas AS s
           ON t.schema_id = s.schema_id
           INNER JOIN
           sys.indexes AS i
           ON t.object_id = i.object_id
              AND i.is_primary_key = 1
           INNER JOIN
           sys.index_columns AS icx
           ON i.object_id = icx.object_id
              AND i.index_id = icx.index_id
           INNER JOIN
           sys.columns AS c
           ON icx.object_id = c.object_id
              AND icx.column_id = c.column_id
           INNER JOIN
           sys.types AS ty
           ON c.user_type_id = ty.user_type_id
           LEFT OUTER JOIN
           sys.identity_columns AS ic
           ON t.object_id = ic.object_id
              AND c.column_id = ic.column_id
    WHERE s.name = @schemaname
           AND t.name = @tablename;
    RETURN @isidentity;
END

GO




