Description: A high-integrity T-SQL view engineered to reconcile session-based timestamps against manually reported labor hours.

Key Innovation: Utilizes Conditional Aggregation within a CTE framework to flatten multi-category labor data into a single-row-per-employee grain, neutralizing a Cartesian product.
* Business Logic: Implements exclusionary filters for PTO, Site Visits, and Lunch breaks to derive "True Clockable Hours" for forensic auditing.
* Defensive Pattern: Employs ANSI-standard COALESCE and Type Casting to prevent operand clashes and ensure mathematical parity across complex datasets.
  
  WITH BaseHourInfo AS (
  SELECT
  m.Department,
  m.EEMasterID,
  m.[Employee Name],
  m.UserName,
  m.WeekEnd As WeekEndingDate,
  COUNT(DISTINCT m.WorkDate) As DaysReported,
  SUM(m.TotalHours) As HoursReported, --hours
  SUM(CASE
  	WHEN m.CategoryCode = 26 THEN 
  	m.TotalHours ELSE 0 END) As SiteVisitHoursReported, --site visit hours to exclude from clocked hours
  
  COALESCE(COUNT(DISTINCT CASE
  	WHEN m.CategoryCode IN (15, 18, 19, 20, 23) THEN
  	CAST(m.WorkDate AS VARCHAR(10)) END),0) As PTODaysReported,
  
  SUM(CASE 
  	WHEN m.CategoryCode IN (15, 18, 19, 20, 23) THEN
  	m.TotalHours ELSE 0 END) As PTOHoursReported, --pto hours to exclude from clocked hours
  
  SUM(CASE
  	WHEN m.CategoryCode = 0 AND m.SubContract = 'Lunch' THEN	
  	m.TotalHours ELSE 0 END) As LunchHoursReported --lunch hours to exclude
  FROM elevant.View_HourEntry_Master m
  WHERE m.Department = 'Engineering'
  GROUP BY m.Department, m.EEMasterID, m.[Employee Name], m.UserName, m.WeekEnd
),
SessionHourInfo AS (
  SELECT
  st.Department,
  st.EEMasterID,
  st.WeekEndingDate,
  st.[Seconds]
  FROM elevant.View_SessionTimes st
)
SELECT
  b.Department,
  b.EEMasterID,
  b.[Employee Name],
  b.UserName,
  b.WeekEndingDate,
  b.DaysReported,
  COALESCE(b.PTODaysReported, 0) As PTODaysReported,
  b.HoursReported AS HoursReported,
  COALESCE(b.SiteVisitHoursReported,0) As SiteVisitHoursReported,
  COALESCE(b.PTOHoursReported, 0) As PTOHoursReported,
  COALESCE(b.LunchHoursReported,0) As LunchHoursReported,
  b.HoursReported - (COALESCE(b.PTOHoursReported, 0) + COALESCE(b.LunchHoursReported,0) + COALESCE(b.SiteVisitHoursReported,0)) As ClockableHours,
  
  SUM(i.[Seconds]) / 60 As [TotalMinutes],
  
  SUM(i.[Seconds]) / 3600 As [Hours],
  (SUM(i.[Seconds]) - (SUM(i.[Seconds]) / 3600) * 3600) / 60 As [Minutes],
  CONVERT(decimal (10,2), ((SUM(i.[Seconds]) - (SUM(i.[Seconds]) / 3600) * 3600) / 60) / 60.0) As [MinutesDecimal],
  
  CAST(ROUND(CONVERT(decimal (10,2), ((SUM(i.[Seconds]) - (SUM(i.[Seconds]) / 3600) * 3600) / 60) / 60.0) / 25,2) * 25 As Decimal (18,2))  As [MinutesDecimalROUNDed],
  
  CAST(SUM(i.[Seconds]) / 3600 + ROUND(CONVERT(decimal (10,2), ((SUM(i.[Seconds]) - (SUM(i.[Seconds]) / 3600) * 3600) / 60) / 60.0) / 25,2) * 25 As Decimal (18,2))  As HoursMinutesClocked
  
  FROM BaseHourInfo b
  	LEFT JOIN SessionHourInfo i ON b.EEMasterID = i.EEMasterID AND b.WeekEndingDate = i.WeekEndingDate
  GROUP BY b.Department, b.EEMasterID, b.[Employee Name], b.UserName, b.WeekEndingDate, b.DaysReported, b.PTOHoursReported, 
  	b.PTODaysReported, b.HoursReported, b.SiteVisitHoursReported, b.LunchHoursReported
