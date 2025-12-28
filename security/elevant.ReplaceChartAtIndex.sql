USE [SAMPLE]
GO

/****** Object:  UserDefinedFunction [elevant].[ReplaceCharAtIndex]    Script Date: 12/28/2025 1:58:38 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- replace char at index
ALTER FUNCTION [elevant].[ReplaceCharAtIndex](@origString nvarchar(128), @idx int, @newChar nvarchar(1))
RETURNS nvarchar(128)
AS
BEGIN

	DECLARE @newString nvarchar(128);

	IF LEN(@origString) = 0 RETURN @origString;

	IF @idx < 1 OR @idx > LEN(@origString) RETURN @origString;

	IF LEN(@newChar) <> 1 RETURN @origString;

	SET @newString = LEFT(@origString, @idx - 1) + @newChar + RIGHT(@origString, LEN(@origString) - @idx)

RETURN @newString
END
GO


