
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Timoor S. Nikitenko
--		F201 Item Size interface processing
--		(1) IS.TN 14-06-12	create
--		(2) IS.TN 28-08-12	F201 can be inside of prepack (F190P)
--		(3) IS.TN 11-09-12	delete unused fields [WH SAP Log]
--		(4) IS.TN 10-10-12	rename multicompany tables
--		(5) IS.TN 15-10-12	SQL eXtra log
--		(6) IS.TN 26-11-12	refactoring 4 SQL2005
--		(7) IS.TN 05-12-12	schema is changed

-- $Revision: 7 $

IF EXISTS( SELECT * FROM sys.procedures WHERE [name] = 'up_LoadItemSize' AND [type] = 'P' AND [schema_id] = SCHEMA_ID( 'sap'))
	DROP PROCEDURE [sap].[up_LoadItemSize]
GO

CREATE PROCEDURE [sap].[up_LoadItemSize]
(
	@nHeaderNo	int		-- Header No.
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@Log		tinyint,			-- = (5) IS.TN 15-10-12
		@rc			int,
		@ec			int

	-- > (5) IS.TN 15-10-12
	SELECT TOP 1 @Log = [SQL Extra Log]  
	FROM   dbo.[WH SAP Setup] (nolock)
	SET @Log = ISNULL( @Log, 0)
	-- < (5) IS.TN 15-10-12

	-- table for errorneous entry
	CREATE TABLE dbo.#InvalidEntry(
		EntryNo	int	NOT NULL PRIMARY KEY CLUSTERED
	)

	--> check for asterisk in column 5
	INSERT dbo.#InvalidEntry (EntryNo)
	SELECT s.[Entry No_]
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column5 <> '*'

	INSERT [dbo].[WH SAP Log] (			-- = (4) IS.TN 10-10-12
		[Status]
		,[Description]
		,[Date]
		,[Time]
		,[WH SAP Line Buff_ Entry No_]
		,[WH SAP Header Buff_ No_]
		,[Message Source]
		,[Column No_]
		,[Interface Code]
		,[Error Code]
	)
	SELECT
		3
		,'17: End of line is missing in Column 5 for Entry No. ' + CAST( s.[Entry No_] AS varchar( 30)) + ' Interface "F201"'
		,sap.ufn_getNavDate( default)			-- = (7) IS.TN 05-12-12
		,sap.ufn_getNavTime( default)			-- = (7) IS.TN 05-12-12
		,s.[Entry No_]
		,@nHeaderNo
		,3
		,5
		,'F201'
		,'WHSQL017'
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column5 <> '*'
	--< check for asterisk in column 5

	--> check for item in [Item Size] exists
	INSERT dbo.#InvalidEntry (EntryNo)
	SELECT s.[Entry No_]
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	  -- > (2) IS.TN 28-08-12
	  LEFT JOIN (
		SELECT No_
		FROM   [dbo].[Item] (nolock)
			UNION
		SELECT UPPER( Column2)
		FROM   dbo.[WH SAP Line Buff_] (nolock)	-- = (4) IS.TN 10-10-12
		WHERE  [Header No_] = @nHeaderNo
		   AND Column1 = 'F190P'
	  ) i
	  -- < (2) IS.TN 28-08-12
		ON i.No_ = UPPER( s.Column2)
	  LEFT JOIN dbo.#InvalidEntry e
		ON s.[Entry No_] = e.EntryNo 
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column2 <> ''
	   AND i.No_ IS NULL
	   AND e.EntryNo IS NULL

	INSERT [dbo].[WH SAP Log] (		-- = (4) IS.TN 10-10-12
		[Status]
		,[Description]
		,[Date]
		,[Time]
		,[WH SAP Line Buff_ Entry No_]
		,[WH SAP Header Buff_ No_]
		,[Message Source]
		,[Column No_]
		,[Interface Code]
		,[Error Code]
	)
	SELECT
		3
		,'54: Item "' + UPPER( s.Column2) + '" was not found for Entry No. ' + CAST( s.[Entry No_] AS varchar( 30)) + ' Interface "F201"'
		,sap.ufn_getNavDate( default)			-- = (7) IS.TN 05-12-12
		,sap.ufn_getNavTime( default)			-- = (7) IS.TN 05-12-12
		,s.[Entry No_]
		,@nHeaderNo
		,3
		,2
		,'F201'
		,'WHSQL054'
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	  -- > (2) IS.TN 28-08-12
	  LEFT JOIN (
		SELECT No_
		FROM   [dbo].[Item] (nolock)
			UNION
		SELECT UPPER( Column2)
		FROM   dbo.[WH SAP Line Buff_] (nolock)	-- = (4) IS.TN 10-10-12
		WHERE  [Header No_] = @nHeaderNo
		   AND Column1 = 'F190P'
	  ) i
	  -- < (2) IS.TN 28-08-12
		ON i.No_ = UPPER( s.Column2)
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column2 <> ''
	   AND i.No_ IS NULL
	--< check for item in [Item Size] exists

	--> check for non existing [IAM Size] lines
	INSERT dbo.#InvalidEntry (EntryNo)
	SELECT s.[Entry No_]
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	  JOIN [dbo].[Item] i (nolock)
		ON i.No_ = UPPER( s.Column2)
	  LEFT JOIN dbo.[IAM Size] m (nolock)
		ON m.[Size Scale] = i.[Size Scale]
	   AND m.[Size Index] = UPPER( s.Column3)
	  LEFT JOIN dbo.#InvalidEntry e
		ON s.[Entry No_] = e.EntryNo
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column2 <> ''
	   AND m.[Size Scale] IS NULL
	   AND e.EntryNo IS NULL

	INSERT [dbo].[WH SAP Log] (			-- = (4) IS.TN 10-10-12
		[Status]
		,[Description]
		,[Date]
		,[Time]
		,[WH SAP Line Buff_ Entry No_]
		,[WH SAP Header Buff_ No_]
		,[Message Source]
		,[Column No_]
		,[Interface Code]
		,[Error Code]
	)
	SELECT
		3
		,'43: No size index ' + UPPER( s.Column3) + ' in scale ' + i.[Size Scale] + '. Line was not loaded'
		,sap.ufn_getNavDate( default)			-- = (7) IS.TN 05-12-12
		,sap.ufn_getNavTime( default)			-- = (7) IS.TN 05-12-12
		,s.[Entry No_]
		,@nHeaderNo
		,3
		,2
		,'F201'
		,'WHSQL043'
	  FROM [dbo].[WH SAP Line Buff_] s (nolock)	-- = (4) IS.TN 10-10-12
	  JOIN [dbo].[Item] i (nolock)
		ON s.Column2 = i.No_
	  LEFT JOIN dbo.[IAM Size] m (nolock)
		ON m.[Size Scale] = i.[Size Scale]
	   AND m.[Size Index] = UPPER( s.Column3)
	WHERE  s.[Header No_] = @nHeaderNo
	   AND s.Column1 = 'F201'
	   AND s.Column2 <> ''
	   AND m.[Size Scale] IS NULL
	--< check for non existing [IAM Size] lines

	BEGIN TRAN
		-- update must be first
		-- > update existing [Item Size] lines
		UPDATE [dbo].[Item Size]
		SET    [Size Name] = s.Column4
		FROM
		(	SELECT MAX( d.[Entry No_]) AS [EntryNo]
			  FROM [dbo].[WH SAP Line Buff_] d (nolock)	-- = (4) IS.TN 10-10-12
			LEFT JOIN dbo.#InvalidEntry y
				ON y.EntryNo = d.[Entry No_]
			WHERE  d.[Header No_] = @nHeaderNo
			   AND d.Column1 = 'F201'
			   AND y.EntryNo IS NULL
			GROUP BY UPPER( d.Column2), UPPER( d.Column3)
		) w
		  JOIN [dbo].[WH SAP Line Buff_] s (nolock)		-- = (4) IS.TN 10-10-12
			ON w.EntryNo = s.[Entry No_]
		  JOIN [dbo].[Item Size] i (nolock)    
			ON i.[Item No_] = UPPER( s.Column2)
		   AND i.[Size Index] = UPPER( s.Column3)
		WHERE  s.[Header No_] = @nHeaderNo 
		   AND s.Column1 = 'F201'

		SELECT @rc = @@ROWCOUNT, @ec = @@ERROR
		IF @ec <> 0
		BEGIN
			ROLLBACK TRAN
			RETURN( @ec)
		END

		IF @Log <> 0							-- = (5) IS.TN 15-10-12
			INSERT [dbo].[WH SAP Log] (			-- = (4) IS.TN 10-10-12
				[Status]
				,[Description]
				,[Date]
				,[Time]
				,[WH SAP Line Buff_ Entry No_]
				,[WH SAP Header Buff_ No_]
				,[Message Source]
				,[Column No_]
				,[Interface Code]
				,[Error Code]
			)
			VALUES (
				1
				,'62: up_LoadItemSize updated ' + CAST( @rc AS varchar( 30)) + ' rows of [Item Size]'
				,sap.ufn_getNavDate( default)			-- = (7) IS.TN 05-12-12
				,sap.ufn_getNavTime( default)			-- = (7) IS.TN 05-12-12
				,0
				,@nHeaderNo
				,3
				,0
				,'F201'
				,'WHSQL062'
			)
		-- < update existing [Item Size] lines

		-- > insert new [Item Size] lines
		INSERT [dbo].[Item Size] (
			[Item No_]
			,[Size Index]
			,[Size Name]
			,[Salomon Item No_]
			,[VAT Product Group]
			,[Baby Custom Tariff No_]
			,[Your reference]
			,[Qty In Purchase Cr_ Memos]
			,[Temp Qty_]
			,[Item ToHandle Qty_]
			,[Item Init_ Qty_]
			,[Item ToDo Qty_]
			,[ITF ToHandle Qty_]
			,[ITF Init_ Qty_]
			,[ITF ToDo Qty_]
			,[ITF InBox Qty_]
			,[Child?]
			,[Minimum Box Whsing]
			,[Maximum Box Whsing]
			,[Zone]
			,[Available]
			,[SizeID]
			,[Replication Counter]
			,[Company owner]
			,[WH abc]
		)
		SELECT
			UPPER( s.Column2)
			,UPPER( s.Column3)
			,s.Column4
			,''
			,''
			,''
			,''
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,''
			,''
		FROM
		(	SELECT MAX( d.[Entry No_]) AS [EntryNo]
			  FROM [dbo].[WH SAP Line Buff_] d (nolock)	-- = (4) IS.TN 10-10-12
			LEFT JOIN dbo.#InvalidEntry y
				ON y.EntryNo = d.[Entry No_]
			WHERE  d.[Header No_] = @nHeaderNo
			   AND d.Column1 = 'F201'
			   AND y.EntryNo IS NULL
			GROUP BY UPPER( d.Column2), UPPER( d.Column3) 
		) w
		  JOIN [dbo].[WH SAP Line Buff_] s (nolock)		-- = (4) IS.TN 10-10-12
			ON w.EntryNo = s.[Entry No_]
		  LEFT JOIN [dbo].[Item Size] i (nolock)    
			ON i.[Item No_] = UPPER( s.Column2)
		   AND i.[Size Index] = UPPER( s.Column3)
		WHERE  s.[Header No_] = @nHeaderNo 
		   AND s.Column1 = 'F201'
		   AND i.[Item No_] IS NULL

		SELECT @rc = @@ROWCOUNT, @ec = @@ERROR
		IF @ec <> 0
		BEGIN
			ROLLBACK TRAN
			RETURN( @ec)
		END

		IF @Log <> 0							-- = (5) IS.TN 15-10-12
			INSERT [dbo].[WH SAP Log] (			-- = (4) IS.TN 10-10-12
				[Status]
				,[Description]
				,[Date]
				,[Time]
				,[WH SAP Line Buff_ Entry No_]
				,[WH SAP Header Buff_ No_]
				,[Message Source]
				,[Column No_]
				,[Interface Code]
				,[Error Code]
			)
			VALUES (
				1
				,'61: up_LoadItemSize inserted ' + CAST( @rc AS varchar( 30)) + ' rows of [Item Size]'
				,sap.ufn_getNavDate( default)			-- = (7) IS.TN 05-12-12
				,sap.ufn_getNavTime( default)			-- = (7) IS.TN 05-12-12
				,0
				,@nHeaderNo
				,3
				,0
				,'F201'
				,'WHSQL061'
			)
		-- < insert new [Item Size] lines
	COMMIT TRAN

	DROP TABLE dbo.#InvalidEntry
END
GO

EXEC sys.sp_addextendedproperty 
     @name = N'Version',
     @value = N'$Revision: 7 $',
     @level0type = N'SCHEMA',
     @level0name = [sap],
     @level1type = N'PROCEDURE',
     @level1name = [up_LoadItemSize]
GO

-- [sap].[up_LoadItemSize] 11425
