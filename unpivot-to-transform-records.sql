-- use of UNPIVOT to transform horizontally-stored day columns from a staging table
-- into a row-based structure for insertion into operational recordkeeping

-- this view takes weekly timesheet entry records and produces a 
-- normalized, daily record format using a relational transform

CREATE VIEW elevant.[View_UnpivotAndTransformEntryByWeek]
AS
SELECT
    HourEntryID,
    ContractNo,    
	EmployeeID,
    EEMasterID,	
	DATEADD(DAY, 
        (CASE [DayOfWeek]
            WHEN 'Mon' THEN -6
            WHEN 'Tue' THEN -5
            WHEN 'Wed' THEN -4
            WHEN 'Thu' THEN -3
            WHEN 'Fri' THEN -2
            WHEN 'Sat' THEN -1
            WHEN 'Sun' THEN  0
        END),
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
    ModifiedDateTime, 
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
		CASE WHEN et.HireType = 1 THEN 1 ELSE 0 END AS Process,
        h.Notes,
        h.NotesExist,
        h.ModifiedDateTime
    FROM elevant.EntryByWeek h
	INNER JOIN elevant.Employee en ON h.EmployeeID = en.EmployeeID
	INNER JOIN elevant.EmployeeTypes et ON en.[TypeID] = et.[TypeID]
) p
UNPIVOT (
    HoursWorked FOR [DayOfWeek] IN (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
) AS unpvt

WHERE HoursWorked <> 0
GO




