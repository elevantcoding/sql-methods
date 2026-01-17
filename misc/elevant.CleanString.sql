ALTER FUNCTION [dbo].[CleanString] (@input NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @output NVARCHAR(MAX) = ''
    DECLARE @i INT = 1
    DECLARE @c NCHAR(1)

    WHILE @i <= LEN(@input)
    BEGIN
        SET @c = SUBSTRING(@input, @i, 1)
        IF UNICODE(@c) BETWEEN 48 AND 57  -- 0-9
           OR UNICODE(@c) BETWEEN 65 AND 90  -- A-Z
           OR UNICODE(@c) BETWEEN 97 AND 122 -- a-z
        BEGIN
            SET @output = @output + @c;
        END
        SET @i = @i + 1;
    END

    RETURN @output
END
GO


