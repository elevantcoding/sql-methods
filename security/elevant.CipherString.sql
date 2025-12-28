/****** Object:  UserDefinedFunction [elevant].[CipherString]    Script Date: 12/28/2025 5:16:25 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- perform obfuscation of a string value using random values provided to the function
-- the string will contain the key for deobfuscation and can be deobfuscated by 
-- DecipherString

ALTER FUNCTION [elevant].[CipherString](@string varchar(128), @vals varchar(6), @randval tinyint, @ciph varchar(10), @padding varchar(128))
RETURNS varchar(256)
AS
BEGIN
	DECLARE @strLen int;
	DECLARE @i int;
	DECLARE @loops int;
	DECLARE @v int;
	DECLARE @altervals varchar(6);
	DECLARE @loopcount int;
	DECLARE @char varchar(1);
	DECLARE @getasc int;
	DECLARE @getval int;
	DECLARE @addasc int;
	DECLARE @addchar varchar(1);
	DECLARE @prefix varchar(21);
	DECLARE @key varchar(10);
	DECLARE @c int;
	DECLARE @ciphprefix varchar(21);
	DECLARE @prefixlen int;
	DECLARE @maxstrlen int;
	DECLARE @availablelen int;
	DECLARE @spacing int;
	DECLARE @s int;
	DECLARE @p int;
	DECLARE @paddedstring varchar(128);
	DECLARE @hexstring varchar(256);
	DECLARE @hexvalue varchar(2);

	-- handle input errors
	SET @string = TRIM(@string);

	IF LEN(@string) = 0
		RETURN N''

	-- initialize
	SET @strLen = LEN(@string);
	SET @i = @strLen + 1
	SET @v = 0;
	SET @loops = @strLen * @randval
	SET @altervals = @vals
	SET @loopcount = 1;
	
	-- build string: traverse backward on string, forward on altervals
	WHILE @loopcount <= @loops
		BEGIN
			SET @i = @i - 1;
			SET @v = @v + 1;
			
			IF @i = 0
				SET @i = @strLen;

			IF @v > LEN(@altervals)
				BEGIN
					SET @v = 1;
					SET @altervals = elevant.GetAlterVals(@altervals, 1);
				END
			
			SET @char = SUBSTRING(@string, @i, 1);
			SET @getasc = ASCII(@char);
			SET @getval = CAST(SUBSTRING(@altervals, @v, 1) AS INT);
			SET @addasc = @getasc ^ @getval;
			SET @addchar = CHAR(@addasc);			
			SET @string = STUFF(@string, CHARINDEX(@char, @string, @i),1, @addchar)
			SET @loopcount = @loopcount + 1;
		END

	-- create prefix / key
	SET @prefix = CONCAT(@altervals, CAST(@randval AS varchar(1)), CAST(@v AS varchar(1)), FORMAT(@strLen,'000'))

	-- use @ciph to cipher the prefix
	SET @key = N'0123456789';
	SET @i = 1;
	SET @ciphprefix = '';
	WHILE @i <= LEN(@prefix)
		BEGIN
			SET @char = SUBSTRING(@prefix, @i, 1)
			SET @c = CHARINDEX(@char, @key, 1)
			SET @ciphprefix = @ciphprefix + SUBSTRING(@ciph, @c, 1)
			SET @i = @i + 1;
		END
	
	-- create full prefix / key by adding the ciphered prefix to the ciph
	SET @prefix = @ciphprefix + @ciph
	
	-- get length of prefix
	SET @prefixlen = LEN(@prefix)	
	SET @maxstrlen = 128;

	-- pad ciphered chars with random chars in @padding
	SET @availablelen = @maxstrlen - @prefixlen;
	SET @spacing = 0;
	IF @strLen < @availablelen
		SET @spacing = CAST(@availablelen / @strLen As int)

	IF @spacing = 0
		SET @paddedstring = @string
	ELSE
		BEGIN
			SET @paddedstring = '';
			SET @s = @spacing;
			SET @i = 1;
			SET @p = 1;

			WHILE @p <= @availablelen
				BEGIN
					
					IF @s = @spacing
						SET @s = 1
					ELSE
						SET @s = @s + 1

					IF @s = 1 AND @i <= @strLen
						BEGIN
							SET @paddedstring = @paddedstring + SUBSTRING(@string, @i, 1);
							SET @i = @i + 1
						END
					ELSE
						SET @paddedstring = @paddedstring + SUBSTRING(@padding, @p, 1);

					SET @p = @p + 1;
				END
		END

	-- add prefix to padded string
	SET @paddedstring = @prefix + @paddedstring;

	-- build hex string
	SET @hexstring = '';
	SET @i = 1;
	WHILE @i <= @maxstrlen
		BEGIN
			SET @char = SUBSTRING(@paddedstring, @i, 1)
			SET @hexvalue = UPPER(FORMAT(ASCII(@char), 'x2'))
			SET @hexstring = @hexstring + @hexvalue
			SET @i = @i + 1
		END	
	RETURN @hexstring
END
GO



