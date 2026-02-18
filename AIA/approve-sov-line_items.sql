-- AIA database project using Access as front-end application
-- avoid throw if call proc from Access, throw otherwise if err

USE [AIA]
GO

/****** Object:  StoredProcedure [dbo].[SOV_LineItems_Approve]    Script Date: 2/18/2026 9:57:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- create a stored procedure to handle Approving AIA SOV Line Items
ALTER PROC [dbo].[SOV_LineItems_Approve](@AIAKey INT, @AIAProjStart DATE, @UserID INT, @LineItemCount INT OUT, @SPSuccess BIT OUT, @IsErrID INT OUT)
AS
BEGIN

DECLARE @OriginApp SYSNAME;
DECLARE @ItemCount INT;
DECLARE @ItemCountUpdate INT;
DECLARE @AppDate DATE;
DECLARE @ItemNumber INT;

-- where sp is called from
SET @OriginApp = APP_NAME();

-- defaults: line item count = 0, sp executed successfully = 0, err id = 0
SET @LineItemCount = 0;
SET @SPSuccess = 0;
SET @IsErrID = 0;

-- count items not approved for this AIAKey
SELECT @ItemCount = COUNT(*)
FROM dbo.table_AIA_SOV_LineItems
WHERE AIAKey = @AIAKey AND AIASOVItemIsApproved = 0;

-- if no item count, sp is successfully executed, return line count
IF @ItemCount = 0
	BEGIN 
		SET @SPSuccess = 1;
		SET @LineItemCount = @ItemCount;
		RETURN
	END

-- create isolated transaction
-- so no other user can update the same records during this operation
SET XACT_ABORT ON;
BEGIN TRY
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	BEGIN TRAN

		-- get most recent finalized application date
		-- use proj start if isnull
		SELECT @AppDate = ISNULL(MAX(AIAAppDate),@AIAProjStart)
		FROM table_AIA_Applications
		WHERE AIAKey = @AIAKey AND AIAAppIsFinalized = 1;

		-- if AppDate <> @AIAProjStart then increment by 1 day
		-- to make sure approved sov line items are after
		-- last finalized application
		IF @AppDate <> @AIAProjStart
			SET @AppDate = DATEADD(DAY,1,@AppDate);
		
		-- get next item number for this app
		SELECT @ItemNumber = IsNull(MAX(AIASOVItemNumber),0) + 1
		FROM table_AIA_SOV_LineItems WITH (UPDLOCK, HOLDLOCK)
		WHERE AIAKey = @AIAKey;

		-- use cte to assign AIASOVItemNumber in numeric order by headingID
		-- row_number creates a row_number value to be decremented by 1 to add to @ItemNumber
		WITH cte AS
		(
			SELECT AIASOVKey,
			ROW_NUMBER() OVER (ORDER BY AIASOVHeadingID, AIASOVKey) AS rn
			FROM table_AIA_SOV_LineItems
			WHERE AIAKey = @AIAKey AND AIASOVItemIsApproved = 0
		)
		UPDATE sovli
		SET
			AIASOVItemIsApproved = 1,
			AIASOVItemApprovedDate = @AppDate,
			AIASOVItemNumber = @ItemNumber + cte.rn - 1
		FROM table_AIA_SOV_LineItems sovli
		JOIN cte ON sovli.AIASOVKey = cte.AIASOVKey;
		
		-- get affected rows to return
		SET @ItemCountUpdate = @@ROWCOUNT;

		-- commit the transaction
		COMMIT TRAN;

		-- sp is successfully executed, return LineItemCount
		SET @SPSuccess = 1;
		SET @LineItemCount = @ItemCountUpdate
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
END TRY

BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK;
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
	
	INSERT INTO dbo.table_AIA_Except (ExceptNum, ExceptDesc, ExceptBy, ExceptLine, ExceptProc, ExceptSource)
	VALUES (ERROR_NUMBER(), ERROR_MESSAGE(), @UserID, ERROR_LINE(), ERROR_PROCEDURE(), 'AIA-SQL');
	SET @IsErrID = SCOPE_IDENTITY();
	
	-- report errant proc if not ms office, else this proc will return err info to the calling application
	IF @OriginApp NOT LIKE 'Microsoft Office%'
		THROW;
END CATCH
END
GO



