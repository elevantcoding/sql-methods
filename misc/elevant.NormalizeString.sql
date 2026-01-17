ALTER FUNCTION [elevant].[NormalizeString]
(@input NVARCHAR (MAX))
RETURNS NVARCHAR (MAX)
AS
BEGIN
    SET @input = ' ' + LTRIM(RTRIM(@input)) + ' ';
    SET @input = REPLACE(@input, ' St ', ' Street ');
    SET @input = REPLACE(@input, ' Rd ', ' Road ');
    SET @input = REPLACE(@input, ' Blvd ', ' Boulevard ');
    SET @input = REPLACE(@input, ' Ln ', ' Lane ');
    SET @input = REPLACE(@input, ' Dr ', ' Drive ');
    SET @input = REPLACE(@input, ' Ave ', ' Avenue ');
    SET @input = REPLACE(@input, ' 1 ', ' One ');
    SET @input = REPLACE(@input, ' 2 ', ' Two ');
    SET @input = REPLACE(@input, ' 3 ', ' Three ');
    SET @input = REPLACE(@input, ' 4 ', ' Four ');
    SET @input = REPLACE(@input, ' 5 ', ' Five ');
    SET @input = REPLACE(@input, ' 6 ', ' Six ');
    SET @input = REPLACE(@input, ' 7 ', ' Seven ');
    SET @input = REPLACE(@input, ' 8 ', ' Eight ');
    SET @input = REPLACE(@input, ' 9 ', ' Nine ');
    SET @input = REPLACE(@input, ' 1st ', ' First ');
    SET @input = REPLACE(@input, ' 2nd ', ' Second ');
    SET @input = REPLACE(@input, ' 3rd ', ' Third ');
    SET @input = REPLACE(@input, ' 4th ', ' Fourth ');
    SET @input = REPLACE(@input, ' 5th ', ' Fifth ');
    SET @input = REPLACE(@input, ' 6th ', ' Sixth ');
    SET @input = REPLACE(@input, ' 7th ', ' Seventh ');
    SET @input = REPLACE(@input, ' 8th ', ' Eighth ');
    SET @input = REPLACE(@input, ' 9th ', ' Ninth ');
    SET @input = REPLACE(@input, ' 10th ', ' Tenth ');
    SET @input = REPLACE(@input, ' 11th ', ' Eleventh ');
    SET @input = REPLACE(@input, ' 12th ', ' Twelfth ');
    WHILE CHARINDEX('  ', @input) > 0
        SET @input = REPLACE(@input, '  ', ' ');
    RETURN LTRIM(RTRIM(@input));
END

GO
