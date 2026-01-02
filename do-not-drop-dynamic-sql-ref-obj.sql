USE [SAMPLE] -- your database name
GO

-- SCHEMABINDING can't stop drops on objects referenced via dynamic SQL
-- This trigger can.
-- dynamic sql; ddl trigger; prevent accidental drop; dependency management; sql_modules search; alter view safety

-- NOTE this trigger assumes your database uses meaningful and structured object naming conventions so that the
-- object names are unlikely to appear coincidentally in unrelated contexts.
-- This code may be adapted to what works for your environment and in order to effectively identify the object,
-- such as looking for the fully-qualified object name including schema and/or using OR for identifying the object
-- both with and without brackets
-- NOTE In environments where database collation differs from server collation, comparisons against sys.sql_modules.definition
-- may require explicit COLLATE normalization.

CREATE TRIGGER [DoNotDropDynamicSQLRefObjects]
     ON DATABASE
    FOR DROP_TABLE, DROP_VIEW, DROP_FUNCTION, DROP_PROCEDURE
    AS BEGIN
          SET NOCOUNT ON;
     
          DECLARE @found SYSNAME;
          DECLARE @objname AS NVARCHAR (255);
          DECLARE @msg AS NVARCHAR (4000);
          DECLARE @eventinfo AS XML = EVENTDATA();
           
          SELECT @objname = @eventinfo.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(255)');
                      
          SELECT TOP (1) @found = QUOTENAME(s.name) + '.' + QUOTENAME(o.name) + ' (' + o.type + ')'
          FROM   sys.objects AS o
                  INNER JOIN sys.sql_modules AS m ON m.object_id = o.object_id
                  INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
          WHERE  s.name = 'dbo'
                  AND (
                        m.definition LIKE '%[^a-zA-Z0-9_]' + @objname + '[^a-zA-Z0-9_]%' OR
                        m.definition LIKE @objname + '[^a-zA-Z0-9_]%' OR
                        m.definition LIKE '%[^a-zA-Z0-9_]' + @objname OR
                        m.definition = @objname
                       )
           
          IF @found IS NOT NULL
               BEGIN
                   SET @msg = @objname + ' is referenced in dynamic sql of ' + @found;
                   THROW 50001, @msg, 1;
               END
          ELSE
               SET @msg = @objname + ' has been dropped.';
          PRINT @msg;
       END
GO












