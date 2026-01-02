USE [SAMPLE] -- your database name
GO

-- SCHEMABINDING can't stop drops on objects referenced via dynamic SQL
-- This trigger can.
-- dynamic sql; ddl trigger; prevent accidental drop; dependency management; sql_modules search; alter view safety

-- NOTE: this trigger assumes your database uses meaningful and structured object naming conventions so that the
-- object names are unlikely to appear coincidentally in unrelated contexts.
-- This code may be adapted to what works for your environment and in order to effectively identify the object,
-- such as looking for the fully-qualified object name including schema and/or using OR for identifying the object
-- both with and without brackets

CREATE TRIGGER [DoNotDropDynamicSQLRefObjects]
    ON DATABASE
    FOR DROP_TABLE, DROP_VIEW, DROP_FUNCTION, DROP_PROCEDURE
    AS BEGIN
           SET NOCOUNT ON;
    
           DECLARE @objname AS SYSNAME;
           DECLARE @msg AS NVARCHAR (4000);
           DECLARE @eventinfo AS XML = EVENTDATA();

           SELECT @objname = @eventinfo.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

           IF EXISTS (
                SELECT 1 FROM sys.objects o
                INNER JOIN sys.sql_modules AS m ON m.object_id = o.object_id
                WHERE o.schema_id = 1 --if schema is applicable, your schema
                AND m.[definition] LIKE '%[' + @objname + ']%' -- eventdata object
           )
               BEGIN
                   SET @msg = @objname + ' is referenced in a procedure with dynamic sql and cannot be dropped.';
                   THROW 50001, @msg, 1;
               END
           ELSE
               SET @msg = @objname + ' has been dropped.';
               PRINT @msg;
       END

GO







