-- compare record counts between a local and Azure SQL instance
-- uses Linked Servers

USE LOCALDATABASENAME -- your local database
GO

BEGIN TRY --procedure-level handler

	DECLARE @sql nvarchar(max);
	DECLARE @sqlazure nvarchar(max);

	DECLARE @localcount int;
	DECLARE @azurecount int;
	DECLARE @tablesattempted int;

	DECLARE @tablename sysname;
	DECLARE @schemaname sysname;

	DECLARE @localtable nvarchar(128);
	DECLARE @azuretable nvarchar(128);

	DROP TABLE IF EXISTS #unmatchedrecordcounts; -- create temp results table fresh
		CREATE TABLE #unmatchedrecordcounts -- temp table to store and display results at the conclusion of processing
		(
		SchemaName sysname,
		TableName sysname,
		LocalCount INT NULL,
		AzureCount INT NULL,
		StatusMessage NVARCHAR(4000),
		ErrorMessage NVARCHAR(4000),
		LoggedAt DATETIME DEFAULT GETDATE()
		);

	DECLARE localtables CURSOR FOR  -- create a cursor from local system tables
		SELECT
		s.name As SchemaName,
		t.name As TableName		
		FROM sys.tables t 
		INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.schema_id = 1 -- your schema, if applicable
			AND t.name Not IN('tables to exclude')
		ORDER BY s.name, t.name;

	SET @tablesattempted = 0; -- intialize table count

	OPEN localtables
	FETCH NEXT FROM localtables INTO @schemaname, @tablename;

	WHILE @@FETCH_STATUS = 0 --remains 0 until no more rows; becomes -1
		BEGIN
			BEGIN TRY
				SET @tablesattempted = @tablesattempted + 1 -- count the table attempt
				SET @localcount = 0; -- set to zero before sp_executesql
				SET @azurecount = 0;

				SET @localtable = QUOTENAME(@schemaname) + '.' + QUOTENAME(@tablename); --local instance
				SET @azuretable = QUOTENAME('AZURE') + '.' + QUOTENAME('DATABASENAME') + '.' + QUOTENAME(@schemaname) + '.' + QUOTENAME(@tablename); --Azure instance
				
				SET @sql = N'SELECT @recordcount = COUNT(*) FROM ' + @localtable		-- create sql for record count
				EXEC sp_executesql @sql, N'@recordcount INT OUTPUT', @localcount OUTPUT;		-- exec sql and retrieve @recordcount into @localcount
		
				SET @sqlazure = N'SELECT @recordcountazure = COUNT(*) FROM ' + @azuretable -- create sql for azure table record count
				EXEC sp_executesql @sqlazure, N'@recordcountazure INT OUTPUT', @azurecount OUTPUT; -- exec sql and retrieve @recordcountazure into @azurecount
		
				IF @localcount <> @azurecount -- if count returned for both tables, if count of records does not match
					INSERT INTO #unmatchedrecordcounts (SchemaName, TableName, LocalCount, AzureCount, StatusMessage) --log schema name, table name, counts for each and message
					VALUES (@schemaname, @tablename, @localcount, @azurecount, 'Record count mismatch');
				
				FETCH NEXT FROM localtables INTO @schemaname, @tablename; -- next record
			END TRY
	
			BEGIN CATCH
				INSERT INTO #unmatchedrecordcounts (SchemaName, TableName, ErrorMessage)
				VALUES (@schemaname, @tablename, ERROR_MESSAGE());
				FETCH NEXT FROM localtables INTO @schemaname, @tablename; -- proceed to next record if err
			END CATCH

		END

	CLOSE localtables
	DEALLOCATE localtables

	-- get tables with unmatched record counts
	SELECT 
	SchemaName, TableName, LocalCount, AzureCount, 
	CAST(CASE WHEN ErrorMessage IS NULL THEN COALESCE(AzureCount,0) - COALESCE(LocalCount,0) ELSE NULL END AS INT) AS Diff,
	StatusMessage, ErrorMessage, LoggedAt
	FROM #unmatchedrecordcounts
	ORDER BY SchemaName, TableName;

	-- display aggregate sums
	SELECT 
		@tablesattempted As TotalTables,
		COUNT(*) AS LoggedIssues,
		SUM(CASE WHEN StatusMessage = 'Record count mismatch' THEN 1 ELSE 0 END) AS Mismatched,
		SUM(CASE WHEN ErrorMessage IS NOT NULL THEN 1 ELSE 0 END) AS Errors,
		(@tablesattempted - COUNT(*)) As Matching
	FROM #unmatchedrecordcounts;
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE();
END CATCH



