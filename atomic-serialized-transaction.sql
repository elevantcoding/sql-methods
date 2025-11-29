-- weekly hours are submitted via procedure that commits atomically under serializable isolation
-- to prevent concurrent modifications while processing is underway.
-- this format uses hours submitted by user for the payroll week ending date and the week ending date worked
-- returns commit success (boolean) and will return err messages, if any, along with the record id of logged err message for review

-- 1 determine safe, unused payroll batch number
-- 2 archive source records exactly as submitted
-- 3 transform weekly entry into row-based format using a view with UNPIVOT
-- 4 insert transformed records to operational table
-- 5 delete original staging records
-- 6 commit actions atomically

ALTER PROCEDURE elevant.SubmitWeeklyHours
@WEDate DATE, @PRWEDate DATE, @UserName VARCHAR (75), @Commit BIT OUTPUT, @Message NVARCHAR (255) OUTPUT, @LogID INT OUTPUT
AS
BEGIN

    DECLARE @NextPayrollNumber AS INT;
    DECLARE @NextPayrollNumberText AS NVARCHAR (5);
    DECLARE @no AS INT;
    DECLARE @line AS INT;
    DECLARE @msg AS NVARCHAR (4000);
    DECLARE @proc AS NVARCHAR (128);

    -- initialize
    SET @Commit = 0;
    SET @Message = '';
    SET @LogID = 0;

    -- if no information found for specified parameters, exit procedure
    IF NOT EXISTS (SELECT 1
                   FROM   elevant.EntryByWeek
                   WHERE  PayrollWeekEndingDate = @PRWEDate
                          AND WeekEndingDate = @WEDate
                          AND UserName = @UserName)
        BEGIN
            SET @Message = N'No records found to submit / already submitted.';
            RETURN;
        END

    -- begin the serialized, multi-step transaction
    SET XACT_ABORT ON; -- automatically rollback on error inside TRY
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        
        SET @NextPayrollNumber = elevant.GetNextPayrollNumber(@PRWEDate); -- determine the next available payroll batch number based on set-forth conditions
        SET @NextPayrollNumberText = CAST (@NextPayrollNumber AS NVARCHAR (5)); -- convert to nvarchar per table design

        IF @NextPayrollNumber > 1 -- log a message to the edits table if not using the first sequence
            INSERT INTO tblEdits (FormName, EditDescription, UserName, EditDateTime)
            VALUES ('elevant.EntryByWeek', 'Updated to Payroll Number ' + CONVERT (NVARCHAR (MAX), @NextPayrollNumberText) + ' Due to Completed Payrolls Found on Payroll Week Ending Date ' + CONVERT (NVARCHAR (MAX), @PRWEDate), @UserName, GETDATE());

        INSERT INTO elevant.EntryByWeek_Archive (HourEntryID, EmployeeID, EEMasterID, ContractNo, SubContract, WeekEndingDate, PayrollWeekEndingDate, PayrollNumber, [Shift], [Time], WorkCategory, FieldWorkCode, Mon, Tue, Wed, Thu, Fri, Sat, Sun, UserName, Notes, NotesExist, ModifiedDate, ModifiedTime)
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
               h.ModifiedDate,
               h.ModifiedTime
        FROM   elevant.EntryByWeek AS h
        WHERE  h.WeekEndingDate = @WEDate
               AND h.PayrollWeekEndingDate = @PRWEDate
               AND h.UserName = @UserName;

        INSERT INTO elevant.EntryByRow (ContractNo, EmployeeID, WorkDate, [Shift], CategoryCode, PayrollWeekEndingDate, PayrollNumber, WeekEndingDate, EngineeringSubContract, FieldWorkCode, STHours, OTHours, DTHours, HourType, UserName, Notes, NotesExist, Submitted, Process, ModifiedDate, ModifiedTime, RecordTypeID, ArchiveID)
        SELECT he.ContractNo,
               he.EmployeeID,
               he.WorkDate,
               he.[Shift],
               he.CategoryCode,
               he.PayrollWeekEndingDate,
               @NextPayrollNumberText,
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
               he.ModDate,
               he.ModTime,
               13 AS RecordTypeID,
               hea.ArchiveID
        FROM   elevant.View_UnpivotAndTransformEntryByWeek AS he
               INNER JOIN
               elevant.EntryByWeek_Archive AS hea
               ON he.HourEntryID = hea.HourEntryID
        WHERE  he.PayrollWeekEndingDate = @PRWEDate
               AND he.WeekEndingDate = @WEDate
               AND he.UserName = @UserName
               AND hea.ArchiveID IS NOT NULL;
        
        
        DELETE h
        FROM   elevant.EntryByWeek AS h
        WHERE  h.WeekEndingDate = @WEDate
               AND h.PayrollWeekEndingDate = @PRWEDate
               AND h.UserName = @UserName;
        
        COMMIT TRANSACTION;
        SET @Commit = 1;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    END TRY

    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        SET @no = ERROR_NUMBER();
        SET @line = ERROR_LINE();
        SET @msg = ERROR_MESSAGE();
        SET @proc = ERROR_PROCEDURE();
        EXECUTE elevant.ExceptionLog @no, @line, @msg, @proc, @UserName, @LogID;
    END CATCH

END

GO



