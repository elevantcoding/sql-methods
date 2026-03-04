
CREATE FUNCTION [elevant].[String_Compare] (
    @FirstStr NVARCHAR(MAX),
    @SecondStr NVARCHAR(MAX)
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @Evaluate NVARCHAR(MAX), @LookIn NVARCHAR(MAX);
    DECLARE @FirstLen INT, @SecondLen INT, @CharCount INT, @Divisor INT;
    DECLARE @WindowSize INT, @i INT = 1, @CharsFound INT = 0;
    DECLARE @Found BIT = 0;
    DECLARE @Characters NVARCHAR(10);

    -- remove punctuation
    SET @FirstStr = dbo.String_Punctuation(@FirstStr);
    SET @SecondStr = dbo.String_Punctuation(@SecondStr);
    
    -- exclude specified terms
    SET @FirstStr = dbo.String_ExcludeTerms(' ' + @FirstStr + ' ');
    SET @SecondStr = dbo.String_ExcludeTerms(' ' + @SecondStr + ' ');

    -- normalize and clean
    SET @FirstStr = dbo.String_Clean(dbo.String_Normalize(@FirstStr));
    SET @SecondStr = dbo.String_Clean(dbo.String_Normalize(@SecondStr));

    -- equality check
    IF @FirstStr = @SecondStr RETURN 0;

    -- get length of each
    SET @FirstLen = LEN(@FirstStr);
    SET @SecondLen = LEN(@SecondStr);

    -- determine roles (evaluate the shorter string against the longer one)
    IF @FirstLen <= @SecondLen
    BEGIN
        SET @CharCount = @FirstLen;
        SET @Evaluate = @FirstStr;
        SET @LookIn = @SecondStr;
        SET @Divisor = @SecondLen;
    END
    ELSE
    BEGIN
        SET @CharCount = @SecondLen;
        SET @Evaluate = @SecondStr;
        SET @LookIn = @FirstStr;
        SET @Divisor = @FirstLen;
    END

    -- determine granularity
    SET @WindowSize = CASE 
        WHEN @CharCount <= 4 THEN 1
        WHEN @CharCount <= 10 THEN 2
        ELSE 3 END;

    WHILE @i <= @CharCount
    BEGIN
        SET @Characters = SUBSTRING(@Evaluate, @i, @WindowSize);
        
        -- only evaluate if we have a full window size
        IF LEN(@Characters) = @WindowSize
        
        BEGIN
            
            -- check for existence at or after current position
            IF CHARINDEX(@Characters, @LookIn, @i) > 0
            BEGIN
                IF @Found = 0
                BEGIN
                    SET @CharsFound = @CharsFound + @WindowSize;
                    SET @Found = 1;
                END
                ELSE
                BEGIN
                    SET @CharsFound = @CharsFound + 1;
                END
            END
            ELSE
            BEGIN
                SET @Found = 0;
            END
        END
        SET @i = @i + 1;
    END

    -- final result (1 - similarity percentage)
    IF @CharsFound > 0
        RETURN 1 - (CAST(@CharsFound AS FLOAT) / CAST(@Divisor AS FLOAT));
    
    RETURN 1;
END
GO

CREATE FUNCTION [elevant].[String_Punctuation](@input NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @output NVARCHAR(MAX) = ''
    DECLARE @i INT = 1
    DECLARE @c NCHAR(1)

    WHILE @i <= LEN(@input)
    BEGIN
        SET @c = SUBSTRING(@input, @i, 1)
        IF UNICODE(@c) BETWEEN 33 AND 47  -- ! to /
           OR UNICODE(@c) BETWEEN 58 AND 64  -- : to @
           OR UNICODE(@c) BETWEEN 91 AND 96 -- [ to `
           OR UNICODE(@c) BETWEEN 123 AND 127 -- { to DEL
            
            SET @output = @output + ' ';
        ELSE
            SET @output = @output + @c;

        SET @i = @i + 1;
    END

    RETURN @output

END
GO

CREATE FUNCTION [elevant].[String_ExcludeTerms] (@s NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    -- Standardize separators first
    SET @s = REPLACE(REPLACE(@s, ',', ''), '.', '');
    SET @s = ' ' + @s + ' ';

    -- Define your noise terms
    DECLARE @Terms TABLE (Term NVARCHAR(50));
    INSERT INTO @Terms VALUES 
    (' development '), (' developer '), (' developers '),
    (' construction '), (' builders '), (' contracting '),
    (' group '), (' company '), (' co '), (' llc '), 
    (' inc '), (' corp '), (' services '), (' solutions ');

    -- Loop through and strip
    SELECT @s = REPLACE(@s, Term, ' ') FROM @Terms;

    -- Clean up double spaces
    WHILE CHARINDEX('  ', @s) > 0
        SET @s = REPLACE(@s, '  ', ' ');

    RETURN LTRIM(RTRIM(@s));
END

GO

CREATE FUNCTION [elevant].[String_Normalize]
(@input NVARCHAR (MAX))
RETURNS NVARCHAR (MAX)
AS
BEGIN
    SET @input = ' ' + LTRIM(RTRIM(@input)) + ' ';
    
    -- street suffixes
    SET @input = REPLACE(@input, ' St ', ' Street ');
    SET @input = REPLACE(@input, ' Rd ', ' Road ');
    SET @input = REPLACE(@input, ' Blvd ', ' Boulevard ');
    SET @input = REPLACE(@input, ' Ln ', ' Lane ');
    SET @input = REPLACE(@input, ' Dr ', ' Drive ');
    SET @input = REPLACE(@input, ' Ave ', ' Avenue ');
    
    -- number words
    SET @input = REPLACE(@input, ' 1 ', ' One ');
    SET @input = REPLACE(@input, ' 2 ', ' Two ');
    SET @input = REPLACE(@input, ' 3 ', ' Three ');
    SET @input = REPLACE(@input, ' 4 ', ' Four ');
    SET @input = REPLACE(@input, ' 5 ', ' Five ');
    SET @input = REPLACE(@input, ' 6 ', ' Six ');
    SET @input = REPLACE(@input, ' 7 ', ' Seven ');
    SET @input = REPLACE(@input, ' 8 ', ' Eight ');
    SET @input = REPLACE(@input, ' 9 ', ' Nine ');
    
    -- numeric equivalents
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
    
    -- directions
    SET @input = REPLACE(@input, ' N ', ' North ')
    SET @input = REPLACE(@input, ' S ', ' South ')
    SET @input = REPLACE(@input, ' E ', ' East ')
    SET @input = REPLACE(@input, ' W ', ' West ')
    
    -- misc
    SET @input = REPLACE(@input, ' and ', ' ')
    SET @input = REPLACE(@input, ' the ', ' ')
    SET @input = REPLACE(@input, ' of ', ' ')

    WHILE CHARINDEX('  ', @input) > 0
        SET @input = REPLACE(@input, '  ', ' ');
    RETURN LTRIM(RTRIM(@input));
END
GO

CREATE FUNCTION [elevant].[String_Clean] (@input NVARCHAR(MAX))
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

