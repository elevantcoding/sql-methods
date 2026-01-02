USE [SAMPLE]
GO

/****** Object:  StoredProcedure [elevant].[GetCipherString]    Script Date: 12/28/2025 1:59:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- create a stored procedure that can generate
-- information for elevant.CipherString

ALTER PROC [elevant].[GetCipherString](@stringtocipher varchar(128), @ciphered varchar(256) OUT)
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
	DECLARE @getvals varchar(6);
	DECLARE @ciph varchar(10);
	DECLARE @getasc int;
	DECLARE @padding varchar(128);


	SET @sixDigit = ABS(CHECKSUM(NEWID())) % 1000000;
	SET @getvals = RIGHT('000000' + CAST(@sixDigit As varchar(6)), 6);
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

	IF NULLIF(TRIM(@ciphered),'') IS NULL
		THROW 50001, 'Invalid cipher format.', 1;

END
GO





