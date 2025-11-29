USE [GBLDBSYSTEM]
GO

/****** Object:  View [dbo].[View_Timekeeping_HourEntry_New]    Script Date: 11/29/2025 5:21:00 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [dbo].[View_Timekeeping_HourEntry_New]
AS

SELECT
    HourEntryID,
    ContractNo,    
	EmployeeID,
    EEMasterID,	
	DATEADD(DAY, 
        CASE [DayOfWeek]
            WHEN 'Mon' THEN -6
            WHEN 'Tue' THEN -5
            WHEN 'Wed' THEN -4
            WHEN 'Thu' THEN -3
            WHEN 'Fri' THEN -2
            WHEN 'Sat' THEN -1
            WHEN 'Sun' THEN  0
        END,
        WeekEndingDate
    ) AS WorkDate,
	WeekEndingDate,    
	[Shift], 
    WorkCategory As CategoryCode,    
	PayrollWeekEndingDate,
    PayrollNumber, 
    FieldWorkCode, 
    CASE WHEN [Time] = 'ST' THEN HoursWorked ELSE 0 END AS STHours,
    CASE WHEN [Time] = 'OT' THEN HoursWorked ELSE 0 END AS OTHours,
    CASE WHEN [Time] = 'DT' THEN HoursWorked ELSE 0 END AS DTHours,
    CASE WHEN WorkCategory = 14 THEN HoursWorked ELSE 0 END AS SiteHours,
	HoursWorked As Total,
    SubContract,         	
	'Actual' AS HourType,
	UserName,
	Process,
    Notes,
    NotesExist,
    ModifiedDate As ModDate, 
    ModifiedTime As ModTime,
    [DayOfWeek]
    
FROM (
    SELECT 
        h.HourEntryID, 
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
        h.Mon, h.Tue, h.Wed, h.Thu, h.Fri, h.Sat, h.Sun,
        h.UserName,
		CASE WHEN ua.HireType = 'Direct-hire' THEN 1 ELSE 0 END AS Process,
        h.Notes,
        h.NotesExist,
        h.ModifiedDate, 
        h.ModifiedTime
    FROM tblHourEntry h
	INNER JOIN tblEmployeeName en ON h.EmployeeID = en.EmpID
	INNER JOIN tblEEType et ON en.[Type] = et.[Type]
	INNER JOIN tblUnionAffiliation ua On et.UnionAffiliation = ua.UnionAffiliationID
) p
UNPIVOT (
    HoursWorked FOR [DayOfWeek] IN (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
) AS unpvt

WHERE HoursWorked <> 0
GO


