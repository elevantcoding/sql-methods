USE [SAMPLE]
GO

/****** Object:  UserDefinedFunction [elevant].[GetAlterVals]    Script Date: 12/28/2025 1:58:58 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER FUNCTION [elevant].[GetAlterVals](@getvals nvarchar(20), @cipher bit)
RETURNS nvarchar(20)
AS
BEGIN
	
	DECLARE @v int;
	DECLARE @char nvarchar(1);
	DECLARE @num tinyint;
	DECLARE @stepVal smallint;
	DECLARE @returnvals nvarchar(6);
	DECLARE @iscipher bit;

	IF LEN(@getvals) = 0
		RETURN @getvals;

	IF @getvals LIKE '%[^0-9]%'
		RETURN @getvals;

	SET @v = 1;
	SET @returnvals = '';

	WHILE @v <= LEN(@getvals)
		BEGIN
			SET @char = SUBSTRING(@getvals, @v, 1);
			SET @num = CAST(@char AS tinyint);

			IF @v % 2 <> 0
				SET @iscipher = 1;
			ELSE
				SET @iscipher = 0;

			IF @iscipher = @cipher
				SET @stepVal = 1;
			ELSE
				SET @stepVal = - 1;

			SET @num = (@num + @stepVal + 10) % 10

			SET @char = CAST(@num AS nvarchar)
			SET @returnvals = @returnvals + @char
			SET @v = @v + 1
		END
	RETURN @returnvals

END
GO


