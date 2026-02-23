-- weekly hours are submitted via procedure that commits atomically under serializable isolation
-- to prevent concurrent modifications while processing is underway.

-- this format uses hours submitted by a user for the payroll week ending date and the week ending date worked
-- returns commit success (boolean) and will return err messages, if any, along with the record id of logged err message for review

-- 1 determine available, sequential payroll batch number using a scalar function
-- 2 archive source records exactly as submitted
-- 3 transform weekly entries into row-based format using a view with UNPIVOT
-- 4 insert transformed records to operational table
-- 5 delete original staging records
-- 6 commit actions atomically

-- scalar functions referenced in this procedure are shown below the procedure definition

CREATE PROCEDURE elevant.SubmitWeeklyHours
@wedate DATE, @prwedate DATE, @submittedby VARCHAR (75), @committed BIT OUTPUT, @message NVARCHAR (255) OUTPUT, @logid INT OUTPUT
AS
BEGIN

    DECLARE @nextpayrollnumber AS INT;
    DECLARE @nextpayrollnumbertext AS NVARCHAR (5);
    DECLARE @number AS INT;
    DECLARE @line AS INT;
    DECLARE @msg AS NVARCHAR (4000);
    DECLARE @proc AS NVARCHAR (128);

    -- initialize
    SET @committed = 0;
    SET @message = '';
    SET @logid = 0;

    -- if no information found for specified parameters, exit procedure
    IF NOT EXISTS (SELECT 1
                   FROM   elevant.EntryByWeek
                   WHERE  PayrollWeekEndingDate = @prwedate
                          AND WeekEndingDate = @wedate
                          AND UserName = @submittedby)
        BEGIN
            SET @message = N'No records found to submit / already submitted.';
            RETURN;
        END

    -- begin the serialized, multi-step transaction
    SET XACT_ABORT ON; -- automatically rollback on error inside TRY
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        
        SET @nextpayrollnumber = elevant.GetNextPayrollNumber(@prwedate); -- determine the next available payroll batch number based on set-forth conditions
        SET @nextpayrollnumbertext = CAST (@nextpayrollnumber AS NVARCHAR (5)); -- convert to nvarchar per table design

        IF @nextpayrollnumber > 1 -- log a message to the edits table if not using the first sequence
            INSERT INTO elevant.EditLog (FormName, EditDescription, UserName, EditDateTime)
            VALUES ('elevant.EntryByWeek', 'Updated to Payroll Number ' + CONVERT (NVARCHAR (MAX), @nextpayrollnumbertext) + ' Due to Completed Payrolls Found on Payroll Week Ending Date ' + CONVERT (NVARCHAR (MAX), @prwedate), @submittedby, GETDATE());

        -- STEP 1: ARCHIVE
        INSERT INTO elevant.EntryByWeek_Archive (HourEntryID, EmployeeID, EEMasterID, ContractNo, SubContract, WeekEndingDate, PayrollWeekEndingDate, PayrollNumber, 
            [Shift], [Time], WorkCategory, FieldWorkCode, Mon, Tue, Wed, Thu, Fri, Sat, Sun, UserName, Notes, NotesExist, ModifiedDateTime)
        SELECT h.HourEntryID,
               h.EmployeeID,
               h.EEMasterID,
               h.ContractNo,
               h.SubContract,
               h.WeekEndingDate,
               h.PayrollWeekEndingDate,
               h.PayrollNumber,
               h.[Shift],
               h.[Time],
               h.WorkCategory,
               h.FieldWorkCode,
               h.Mon,
               h.Tue,
               h.Wed,
               h.Thu,
               h.Fri,
               h.Sat,
               h.Sun,
               h.UserName,
               h.Notes,
               h.NotesExist,
               h.ModifiedDateTime
        FROM   elevant.EntryByWeek AS h
        WHERE  h.WeekEndingDate = @wedate
               AND h.PayrollWeekEndingDate = @prwedate
               AND h.UserName = @submittedby;
        
        -- STEP 2: WRITE TO MAIN TABLE
        INSERT INTO elevant.EntryByRow (ContractNo, EmployeeID, WorkDate, [Shift], CategoryCode, PayrollWeekEndingDate, PayrollNumber, WeekEndingDate, EngineeringSubContract, FieldWorkCode,
            STHours, OTHours, DTHours, HourType, UserName, Notes, NotesExist, Submitted, Process, ModifiedDateTime, RecordTypeID, ArchiveID)
        SELECT he.ContractNo,
               he.EmployeeID,
               he.WorkDate,
               he.[Shift],
               he.CategoryCode,
               he.PayrollWeekEndingDate,
               @nextpayrollnumbertext,
               he.WeekEndingDate,
               he.SubContract,
               he.FieldWorkCode,
               he.STHours,
               he.OTHours,
               he.DTHours,
               he.HourType,
               he.UserName,
               he.Notes,
               he.NotesExist,
               1 AS Submitted,
               he.Process,
               he.ModifiedDateTime,
               13 AS RecordTypeID,
               hea.ArchiveID
        FROM   elevant.View_UnpivotAndTransformEntryByWeek AS he
               INNER JOIN elevant.EntryByWeek_Archive AS hea ON he.HourEntryID = hea.HourEntryID
        WHERE  he.PayrollWeekEndingDate = @prwedate
               AND he.WeekEndingDate = @wedate
               AND he.UserName = @submittedby
               AND hea.ArchiveID IS NOT NULL;

        -- STEP 3: DELETE FROM STAGING TABLE
        DELETE h
        FROM   elevant.EntryByWeek AS h
        WHERE  h.WeekEndingDate = @wedate
               AND h.PayrollWeekEndingDate = @prwedate
               AND h.UserName = @submittedby;
        
        COMMIT TRANSACTION;
        SET @committed = 1;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    END TRY

    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        SET @number = ERROR_NUMBER();
        SET @line = ERROR_LINE();
        SET @msg = ERROR_MESSAGE();
        SET @proc = ERROR_PROCEDURE();
        EXECUTE elevant.ExceptionLog @number, @line, @msg, @proc, @submittedby, @logid;
    END CATCH
END
GO

-- find the next, sequential payroll batch number outside of batches marked complete and outside of batches in process
CREATE FUNCTION elevant.[GetNextPayrollNumber]
(@prwedate DATE)
RETURNS INT
AS
BEGIN
    DECLARE @nextpr AS INT;
    SET @nextpr = 1;

    WHILE EXISTS (SELECT 1
                  FROM   elevant.PayrollBatchRecord
                  WHERE  PayrollWeekEndingDate = @prwedate
                         AND PayrollNumber = @nextpr
                         AND PayrollComplete = 1)
          OR EXISTS (SELECT 1
                     FROM   elevant.PayrollInProcess
                     WHERE  PayrollWeekEndingDate = @prwedate
                            AND PayrollNumber = @nextpr)
        BEGIN
            SET @nextpr = @nextpr + 1;
        END
    RETURN @nextpr;
END

GO

-- sp exception log
CREATE PROCEDURE elevant.[ExceptionLog]
@number INT, @line INT, @msg NVARCHAR (4000), @proc SYSNAME, @username NVARCHAR (128), @logid INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @date AS DATETIME;
    DECLARE @source AS NVARCHAR (50);
    DECLARE @origin AS NVARCHAR (100);

    SET @date = GETDATE();
    SET @source = 'Stored Procedure';
    SET @origin = 'SQL Server';
    
    INSERT INTO elevant.ExceptionLog (ErrDate, ErrNo, ErrLine, ErrDesc, ErrSource, ProcName, ModType, UserName, ErrOrigin)
    VALUES (@date, @number, @line, @msg, @source, @proc, 'SP', @username, @origin);
	SET @logid = SCOPE_IDENTITY();
END
GO



