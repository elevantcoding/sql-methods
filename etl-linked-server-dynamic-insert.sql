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


