-- use LEAD to derive an End Date from Sequential Start Dates

-----------------------------------------------------------------------------
--| RateID  | EmployeeID | PositionID | HourlyRate | StartDate  | EndDate   |
-----------------------------------------------------------------------------
--| 1	    | 1	         | 20	      | 20.00	   | 2011-05-01 | 2013-05-26|
--| 2	    | 1	         | 20	      | 21.00	   | 2013-05-27 | 2015-03-22|
--| 3	    | 1	         | 20	      | 22.50	   | 2015-03-23 | 2050-12-31|
--| 4	    | 1	         | 45	      | 22.00	   | 2011-05-01 | 2013-05-26|
--| 5	    | 1	         | 45	      | 24.00	   | 2013-05-27 | 2015-03-22|
--| 6	    | 1	         | 45	      | 26.50	   | 2015-03-23 | 2050-12-31|

SELECT
r.RateID,
r.EmployeeID,
r.PositionID,
r.HourlyRate,
r.StartDate,

CASE 
    WHEN LEAD(r.StartDate) OVER (PARTITION BY r.EmployeeID, r.PositionID ORDER BY r.StartDate) IS NOT NULL THEN 
        DATEADD(DAY, -1, LEAD(r.StartDate) OVER (PARTITION BY r.EmployeeID, r.PositionID ORDER BY r.StartDate))        
    ELSE 
        '12/31/2050'
END AS EndDate
FROM elevant.RateTable r
ORDER BY r.EmployeeID, r.PositionID

