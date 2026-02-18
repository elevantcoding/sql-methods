
/*******************************************************************************
Object:         dbo.Application_LineItems_AddEdit
Project:        AIA Billing & Construction Management System
Author:         Melinda [Your Last Name]
Date:           2/17/2026
Description:    Handles the Upsert logic for G703 Progress Billing line items.
                Manages "Work Completed" vs. "Stored Materials" calculations.

Logic Notes:
- Unbound Integration: Engineered for stateless calls from MS Access unbound forms.
- Stored Materials Netting: Automatically adjusts available stored materials 
  balance when materials are utilized in the current billing period.
- Validation: Enforces business rules to ensure (Work Completed) 
  never exceeds the Total Scheduled Value.
- Transactional Safety: Wrapped in TRY/CATCH blocks with XACT_ABORT to ensure 
  arithmetic failures result in a full rollback of the billing record.
- Error Handling: Maps T-SQL exceptions to return codes for non-blocking 
  VBA/UI communication.
*******************************************************************************/

-- stored procedure to write new lines to table_AIA_Applications_LineItems
ALTER PROC [dbo].[Applications_LineItems_AddEdit] (@AIAAppKey INT, @AIASOVKey INT, @AmtG DECIMAL (18,2), @AmtH DECIMAL (18,2), @UserID INT,
@SPSuccess BIT OUT, @UpdateSuccess INT OUT, @IsErrID INT OUT)
AS 
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @OriginApp SYSNAME;
	DECLARE @RightNow DATETIME;
	DECLARE @AvailSOVLineItemAmt DECIMAL (18,2);
	DECLARE @AvailStoredLineItemAmt DECIMAL (18,2);
	DECLARE @RowsAffected INT;


	-- where sp is called from
	SET @OriginApp = APP_NAME()

	-- defaults
	SET @SPSuccess = 0;
	SET @UpdateSuccess = 0; -- if insert, 1, if update 2, if attempt update and no update needed, 3
	SET @IsErrID = 0;

	-- current datetime for created / edited date time
	SET @RightNow = GETDATE();

	SET XACT_ABORT ON;
	BEGIN TRY
		BEGIN TRAN

			-- get sov line item remaining value, materials presently stored			
			SELECT @AvailSOVLineItemAmt = E - F, @AvailSOVLineItemAmt = H
			FROM dbo.view_AIA_App_Last
			WHERE AIAAppKey = @AIAAppKey AND AIASOVKey = @AIASOVKey;
			
			-- only vaidate new labor against remaining balance, not stored materials utilization on this app
			IF @AmtG > @AvailSOVLineItemAmt
				BEGIN -- jump to catch
					RAISERROR('Total billing (Work + Utilization) exceeds Scheduled Value.', 16, 1);
				END

			-- jump to catch
			IF @AmtH > @AvailStoredLineItemAmt
				BEGIN
					RAISERROR('Amount exceeds Available Stored Materials.', 16, 1);
				END
		
			-- attempt update
			IF EXISTS( 
				SELECT 1 
				FROM dbo.table_AIA_Applications_LineItems
				WHERE AIAAppKey = @AIAAppKey AND AIASOVKey = @AIASOVKey
				)
				BEGIN
					UPDATE appli
					SET appli.AIAAppDetailG = @AmtG + @AmtH, 
						appli.AIAAppDetailHUtilized = @AmtH, 
						appli.AIAAppDetailEdited = @RightNow,
						appli.AIAAppDetailEditedBy = @UserID
					FROM dbo.table_AIA_Applications_LineItems appli
					WHERE appli.AIAAppKey = @AIAAppKey
						AND appli.AIASOVKey = @AIASOVKey
						AND (AIAAppDetailG <> (@AmtG + @AmtH)
							OR AIAAppDetailHUtilized <> @AmtH
							);
					
					SET @RowsAffected = @@ROWCOUNT
					
					IF @RowsAffected = 1 
						SET @UpdateSuccess = 2;
					ELSE
						SET @UpdateSuccess = 3;
				END
			ELSE
				-- if not update, insert
				BEGIN
					INSERT INTO dbo.table_AIA_Applications_LineItems
					(AIAAppKey, AIASOVKey, AIAAppDetailG, AIAAppDetailHUtilized, AIAAppDetailCreated, AIAAppDetailCreatedBy, AIAAppDetailEdited, AIAAppDetailEditedBy)
					VALUES (@AIAAppKey, @AIASOVKey, (@AmtG + @AmtH), @AmtH, @RightNow, @UserID, @RightNow, @UserID);	

					SET @RowsAffected = @@ROWCOUNT
					
					IF @RowsAffected = 1 SET @UpdateSuccess = 1;
				END

		COMMIT TRAN;
		SET @SPSuccess = 1;
	END TRY

	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK;
	
		INSERT INTO dbo.table_AIA_Except (ExceptNum, ExceptDesc, ExceptBy, ExceptLine, ExceptProc, ExceptSource)
		VALUES (ERROR_NUMBER(), ERROR_MESSAGE(), @UserID, ERROR_LINE(), ERROR_PROCEDURE(), 'AIA-SQL');
		SET @IsErrID = SCOPE_IDENTITY();
	
		-- report errant proc if not ms office, else this proc will return err info to the calling application
		IF @OriginApp NOT LIKE 'Microsoft Office%'
			THROW;
	END CATCH
END
GO
