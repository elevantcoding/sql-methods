-- string comparison for detecting near-duplicates or other purposes
-- return percentage difference: 1 = completely different, no similarity detected; 0 = identical
-- does not perform a binary compare in order to detect things like A vs a.
ALTER FUNCTION [dbo].[CompareStrings]
(@stringone NVARCHAR (100), @stringtwo NVARCHAR (100))
RETURNS FLOAT
AS
BEGIN
    DECLARE @results AS FLOAT;
    DECLARE @firstlen AS INT;
    DECLARE @secondlen AS INT;
    DECLARE @dividend AS INT;
    DECLARE @divisor AS INT;
    DECLARE @charactercount AS INT;
    DECLARE @characters AS INT;
    DECLARE @foundcount AS INT;
    DECLARE @count AS INT;
    DECLARE @subLen AS INT;
    DECLARE @Character AS NVARCHAR (4);
    DECLARE @Eval AS NVARCHAR (100);
    DECLARE @Lookin AS NVARCHAR (100);

    IF (LEN(@stringone) = 0 AND LEN(@stringtwo) > 0) OR
       (LEN(@stringone) > 0 AND LEN(@stringtwo) = 0)
        RETURN 1;

    SET @stringone = LOWER(@stringone);
    SET @stringtwo = LOWER(@stringtwo);
    SET @stringone = dbo.NormalizeString(@stringone);
    SET @stringtwo = dbo.NormalizeString(@stringtwo);
    SET @stringone = dbo.CleanString(@stringone);
    SET @stringtwo = dbo.CleanString(@stringtwo);
    SET @firstlen = LEN(@stringone);
    SET @secondlen = LEN(@stringtwo);

    IF (@firstlen = @secondlen) OR
       (@firstlen < @secondlen)
        BEGIN
            SET @characters = @firstlen;
            SET @Lookin = @stringtwo;
            SET @Eval = @stringone;
            SET @divisor = @secondlen;
        END
    ELSE
        BEGIN
            SET @characters = @secondlen;
            SET @Lookin = @stringone;
            SET @Eval = @stringtwo;
            SET @divisor = @firstlen;
        END

    SET @sublen = CASE WHEN @characters <= 1 THEN 1 WHEN @characters <= 6 THEN 2 ELSE 4 END;
    SET @charactercount = 1;
    SET @count = 0;

    WHILE @charactercount <= @characters
        BEGIN
            SET @Character = SUBSTRING(@Eval, @charactercount, @subLen);
            IF LEN(@Character) = @subLen
                SET @foundcount = CHARINDEX(@Character, @Lookin, 1);
            IF @foundcount > 0
                SET @count = @count + 1;
            SET @charactercount = @charactercount + 1;
        END

    IF @count > 0
        BEGIN
            SET @dividend = @count;
            SET @results = (1 - (CAST (@dividend AS DECIMAL (18, 2)) / CAST (@divisor AS DECIMAL (18, 2))));
        END
    ELSE
        SET @results = 1;

    RETURN @results;
END

GO

