USE GBLDBSYSTEM
GO

-- SCHEMABINDING can't stop drops on objects referenced via dynamic SQL
-- This trigger can.
CREATE TRIGGER [DoNotDropDynamicSQLRefObjects]
    ON DATABASE
    FOR DROP_TABLE, DROP_VIEW
    AS BEGIN
           DECLARE @objname AS NVARCHAR (255);
           DECLARE @msg AS NVARCHAR (255);
           DECLARE @eventinfo AS XML = EVENTDATA();

           SELECT @objname = @eventinfo.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(255)');

           IF EXISTS (
                SELECT 1 FROM sys.objects o
                INNER JOIN sys.sql_modules AS m ON m.object_id = o.object_id
                WHERE o.schema_id = 1
                AND o.[type] = 'P'
                AND m.[definition] LIKE '%[' + @objname + ']%'
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


