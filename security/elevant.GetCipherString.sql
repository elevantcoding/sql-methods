USE [SAMPLE]
GO

/****** Object:  StoredProcedure [elevant].[GetCipherString]    Script Date: 12/28/2025 1:59:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- create a stored procedure that can generate
-- information for elevant.CipherString

ALTER PROC [elevant].[GetCipherString](@stringtocipher nvarchar(128), @ciphered nvarchar(256) OUT)
AS
BEGIN
	-- generate:
	-- random six-digit number as string
	-- random one-digit number 2 to 6
	-- a random cipher of 10 chars ascii 58 to 126, no duplicates
	-- and a padded string of randoms 128 chars in length
	-- pass to CipherString and return @ciphered
	DECLARE @sixDigit int;
	DECLARE @randval tinyint;
	DECLARE @getvals nvarchar(6);
	DECLARE @ciph nvarchar(10);
	DECLARE @getasc int;
	DECLARE @padding nvarchar(128);


	SET @sixDigit = ABS(CHECKSUM(NEWID())) % 1000000;
	SET @getvals = FORMAT(@sixDigit, '000000');
	SET @randval = (ABS(CHECKSUM(NEWID())) % 5) + 2;

	SET @ciph = '';
	WHILE LEN(@ciph) < 10
		BEGIN
			SET @getasc = (ABS(CHECKSUM(NEWID())) % (126 - 58 + 1)) + 58;
			IF CHARINDEX(CHAR(@getasc), @ciph) = 0
				SET @ciph = @ciph + CHAR(@getasc)

		END

	SET @padding = '';
	WHILE LEN(@padding) < 128
		BEGIN
			SET @getasc = (ABS(CHECKSUM(NEWID())) % (126 - 32 + 1)) + 32;
			SET @padding = @padding + CHAR(@getasc)
		END
	SET @ciphered = elevant.CipherString(@stringtocipher, @getvals, @randval, @ciph, @padding)

END
GO


