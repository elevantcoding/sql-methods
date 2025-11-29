-- compare records between a local and Azure SQL instance
-- uses Linked Servers

USE LOCALDATABASENAME -- your local database
GO

BEGIN TRY --procedure-level handler

	DECLARE @sql nvarchar(max);
	DECLARE @sqlazure nvarchar(max);

	DECLARE @count int;
	DECLARE @countazure int;
	DECLARE @counttables int;

	DECLARE @tablename sysname;
	DECLARE @schemaname sysname;

	DECLARE @gettablename nvarchar(128);
	DECLARE @gettablenameazure nvarchar(128);

	DROP TABLE IF EXISTS #unmatchedrecordcounts; -- drop table before creating, if it exists

		CREATE TABLE #unmatchedrecordcounts -- create temp table to store results
		(TableName sysname,
		CountDev INT NULL,
		CountAzure INT NULL,
		StatusMessage NVARCHAR(4000),
		ErrorMessage NVARCHAR(4000),
		LoggedAt DATETIME DEFAULT GETDATE()
		);

	DECLARE recordset CURSOR FOR  --tables in dbo, schema 1

		SELECT --recordset columns to match vars
		t.name As TableName,
		s.name As SchemaName
		FROM sys.tables t 
		INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
		WHERE t.schema_id = 1
			AND t.name Not IN('tables to exclude');

	SET @counttables = 0;

	OPEN recordset
	FETCH NEXT FROM recordset INTO @tablename, @schemaname;

	WHILE @@FETCH_STATUS = 0 --remains 0 until no more rows; becomes -1
		BEGIN
			BEGIN TRY
				SET @counttables = @counttables + 1
				SET @count = 0; --intitalize
				SET @countazure = 0;

				SET @gettablename = CONCAT('[',@schemaname, '].[', @tablename, ']') -- local instance
				SET @gettablenameazure = CONCAT('[AZURE].[DATABASENAME].[',@schemaname, '].[', @tablename, ']') -- Azure instance
		
				SET @sql = N'SELECT @recordcount = COUNT(*) FROM ' + @gettablename		-- create sql for record count
				EXEC sp_executesql @sql, N'@recordcount INT OUTPUT', @count OUTPUT;		-- exec sql and retrieve @recordcount into @count
		
				SET @sqlazure = N'SELECT @recordcountazure = COUNT(*) FROM ' + @gettablenameazure -- if exists, create sql for azure table record count
				EXEC sp_executesql @sqlazure, N'@recordcountazure INT OUTPUT', @countazure OUTPUT; -- exec sql and retrieve @recordcountazure into @countazure
		
				IF @count <> @countazure -- if count returned for both tables, if count of records does not match
					INSERT INTO #unmatchedrecordcounts (TableName, CountDev, CountAzure, StatusMessage) --log table name, counts and message
					VALUES (@tablename, @count, @countazure, 'Record count mismatch');
				
				FETCH NEXT FROM recordset INTO @tablename, @schemaname; -- next record
			END TRY
	
			BEGIN CATCH
				INSERT INTO #unmatchedrecordcounts (TableName, ErrorMessage)
				VALUES (@tablename, ERROR_MESSAGE());
				FETCH NEXT FROM recordset INTO @tablename, @schemaname; -- next record
			END CATCH

		END

	CLOSE recordset
	DEALLOCATE recordset

	-- get tables with unmatched counts
	SELECT 
	TableName, CountDev, CountAzure, CAST(CASE WHEN ErrorMessage IS NULL THEN COALESCE(CountAzure,0) - COALESCE(CountDev,0) ELSE NULL END AS INT) AS Diff,
	StatusMessage, ErrorMessage, LoggedAt
	FROM #unmatchedrecordcounts;

	-- display aggregate sums
	SELECT 
		@counttables As TotalTables,
		COUNT(*) AS LoggedIssues,
		SUM(CASE WHEN StatusMessage = 'Record count mismatch' THEN 1 ELSE 0 END) AS Mismatched,
		SUM(CASE WHEN ErrorMessage IS NOT NULL THEN 1 ELSE 0 END) AS Errors,
		(@counttables - COUNT(*)) As Matching
	FROM #unmatchedrecordcounts;
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE();
END CATCH

