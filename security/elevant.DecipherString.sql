/****** Object:  UserDefinedFunction [elevant].[DecipherString]    Script Date: 12/28/2025 5:17:24 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- decipher a hex string created using elevant.CipherString or VBA StringCipher.CipherString or Py cipher.cipher_string
ALTER FUNCTION [elevant].[DecipherString](@cipherstring varchar(256))
RETURNS varchar(128)
AS
BEGIN
	DECLARE @prefixlen int;
	DECLARE @maxstrlen int;
	DECLARE @i int;
	DECLARE @hex varchar(2);
	DECLARE @string varchar(256);
	DECLARE @prefix varchar(21);
	DECLARE @numciph varchar(10);
	DECLARE @key varchar(10);
	DECLARE @k int;
	DECLARE @deciphprefix varchar(21);
	DECLARE @char varchar(1);
	DECLARE @chars varchar(21);
	DECLARE @strLen int;
	DECLARE @v int;
	DECLARE @randval int;
	DECLARE @altervals varchar(6);
	DECLARE @paddedstring varchar(128);
	DECLARE @availablelen int;
	DECLARE @spacing int;
	DECLARE @s int;
	DECLARE @p int;
	DECLARE @loops int;
	DECLARE @loopcount int;
	DECLARE @altervalsorig varchar(6)
	DECLARE @getasc int;
	DECLARE @getval int;
	DECLARE @addasc int;
	DECLARE @addchar varchar(1);

	SET @prefixlen = 21;
	SET @maxstrlen = 128;

	SET @cipherstring = TRIM(@cipherstring)

	IF LEN(@cipherstring) = 0
		RETURN N'';

	SET @i = 1;
	SET @string = '';
	WHILE @i <= LEN(@cipherstring)
		BEGIN
			SET @hex = SUBSTRING(@cipherstring,@i,2)
			SET @string = @string + CHAR(CONVERT(INT, CONVERT (VARBINARY (1), @hex,2)));
			SET @i = @i + 2;
		END

	-- get prefix
	SET @prefix = LEFT(@string, @prefixlen)
	
	-- get numeric cipher
	SET @numciph = RIGHT(@prefix, 10)
	
	-- decipher the prefix of the string
	SET @prefix = LEFT(@prefix, LEN(@prefix) - 10)
	
	-- use binary compare for decipher
	SET @key = N'0123456789'
	SET @i = 1;
	SET @deciphprefix = '';
	WHILE @i <= LEN(@prefix)
		BEGIN
			SET @char = SUBSTRING(@prefix, @i, 1)
			SET @k = CHARINDEX(@char COLLATE Latin1_General_100_BIN2, @numciph COLLATE Latin1_General_100_BIN2, 1)
			SET @deciphprefix = @deciphprefix + SUBSTRING(@key, @k, 1)
			SET @i = @i + 1
		END

	SET @prefix = @deciphprefix

	IF @prefix LIKE '%[^0-9]%'
		RETURN 'N'

	-- get strLen
	SET @chars = RIGHT(@prefix, 3)
	SET @strLen = CAST(@chars AS INT);

	-- trim strLen from prefix
	SET @prefix = LEFT(@prefix, LEN(@prefix) - 3)

	-- get v
	SET @char = RIGHT(@prefix, 1)
	SET @v = CAST(@char AS INT)

	-- trim v from prefix
	SET @prefix = LEFT(@prefix, LEN(@prefix) - 1)

	-- get rand val
	SET @char = RIGHT(@prefix, 1)
	SET @randval = CAST(@char AS INT)

	-- trim randval from prefix
	SET @prefix = LEFT(@prefix, LEN(@prefix) - 1)

	-- get altervals
	SET @altervals = @prefix

	-- remove padding
	SET @paddedstring = RIGHT(@string, LEN(@string) - @prefixlen)
	SET @availablelen = @maxstrlen - @prefixlen
	SET @spacing = CAST(@availablelen/@strLen As Int)
	IF @spacing < 1
		SET @spacing = 1

	SET @string = '';
	SET @i = 0;
	SET @s = 1;
	SET @p = 1;
	WHILE @p <= @availablelen
		BEGIN
			IF @s = 1
				BEGIN
					SET @string = @string + SUBSTRING(@paddedstring, @p, 1)
					SET @i = @i + 1
					IF @i = @strLen
						BREAK
				END
			IF @s = @spacing
				SET @s = 1
			ELSE
				SET @s = @s + 1

			SET @p = @p + 1
		END

	-- decipher string
	SET @i = 1;
	SET @loops = @strLen * @randval;
	SET @altervalsorig = @altervals;
	SET @altervals = LEFT(@altervals, @v);
	SET @loopcount = 1;
	SET @loopcount = 1

	WHILE @loopcount <= @loops
		BEGIN
						
			SET @char = SUBSTRING(@string, @i, 1)
			SET @getasc = ASCII(@char)
			SET @getval = CAST(SUBSTRING(@altervals, @v, 1) As INT)
			SET @addasc = @getasc ^ @getval
			SET @addchar = CHAR(@addasc)			
			SET @string = STUFF(@string, CHARINDEX(@char, @string, @i),1, @addchar)
			
			SET @i = @i + 1
			IF @i > @strLen SET @i = 1;			
			
			SET @v = @v - 1			
			IF @v = 0
				BEGIN
					IF LEN(@altervals) < 6 SET @altervals = @altervalsorig
					SET @v = LEN(@altervals)
					SET @altervals = elevant.GetAlterVals(@altervals, 0)
				END
			
			SET @loopcount = @loopcount + 1
		END
	RETURN @string
END
GO



