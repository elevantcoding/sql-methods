USE [GBLDBSYSTEM]
GO

/****** Object:  StoredProcedure [dbo].[SubmitHours]    Script Date: 11/29/2025 2:57:09 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SubmitHours]
@WEDate DATE, @PRWEDate DATE, @UserName VARCHAR (75), @Commit BIT OUTPUT, @Message NVARCHAR (255) OUTPUT, @LogID INT OUTPUT
AS
BEGIN

    DECLARE @PR AS INT;
    DECLARE @NextPR AS NVARCHAR (5);
    DECLARE @no AS INT;
    DECLARE @line AS INT;
    DECLARE @msg AS NVARCHAR (4000);
    DECLARE @proc AS NVARCHAR (128);

    SET @Commit = 0;
    SET @Message = '';
    SET @LogID = 0;

    IF NOT EXISTS (SELECT 1
                   FROM   tblHourEntry
                   WHERE  PayrollWeekEndingDate = @PRWEDate
                          AND WeekEndingDate = @WEDate
                          AND UserName = @UserName)
        BEGIN
            SET @Message = N'No records found to submit / already submitted.';
            RETURN;
        END

    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        
        SET @PR = dbo.GetNextPayrollNumber(@PRWEDate);
        SET @NextPR = CAST (@PR AS NVARCHAR (5));
        
        IF @PR > 1
            INSERT INTO tblEdits (FormName, EditDescription, UserName, EditDateTime)
            VALUES ('tblHourEntry', 'Updated to Payroll Number ' + CONVERT (NVARCHAR (MAX), @NextPR) + ' Due to Completed Payrolls Found on Payroll Week Ending Date ' + CONVERT (NVARCHAR (MAX), @PRWEDate), @UserName, dbo.ZoneESTDateTime());

        INSERT INTO tblHourEntry_Archive (HourEntryID, EmployeeID, EEMasterID, ContractNo, SubContract, WeekEndingDate, PayrollWeekEndingDate, PayrollNumber, [Shift], [Time], WorkCategory, FieldWorkCode, Mon, Tue, Wed, Thu, Fri, Sat, Sun, UserName, Notes, NotesExist, ModifiedDate, ModifiedTime)
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
        FROM   tblHourEntry AS h
        WHERE  h.WeekEndingDate = @WEDate
               AND h.PayrollWeekEndingDate = @PRWEDate
               AND h.UserName = @UserName;

        INSERT INTO tblHours (ContractNo, EmployeeID, WorkDate, [Shift], CategoryCode, PayrollWeekEndingDate, PayrollNumber, WeekEndingDate, EngineeringSubContract, FieldWorkCode, STHours, OTHours, DTHours, HourType, UserName, Notes, NotesExist, Submitted, Process, ModifiedDate, ModifiedTime, RecordTypeID, ArchiveID)
        SELECT he.ContractNo,
               he.EmployeeID,
               he.WorkDate,
               he.[Shift],
               he.CategoryCode,
               he.PayrollWeekEndingDate,
               @NextPR,
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
        FROM   View_Timekeeping_HourEntry_New AS he
               INNER JOIN
               tblHourEntry_Archive AS hea
               ON he.HourEntryID = hea.HourEntryID
        WHERE  he.PayrollWeekEndingDate = @PRWEDate
               AND he.WeekEndingDate = @WEDate
               AND he.UserName = @UserName
               AND hea.ArchiveID IS NOT NULL;
        
        
        DELETE h
        FROM   tblHourEntry AS h
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
        EXECUTE dbo.SystemFunctionRpt @no, @line, @msg, @proc, @UserName, @LogID;
    END CATCH

END

GO


