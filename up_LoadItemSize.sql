
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
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
--		(8) IS.TN 01-06-15	company independent stored procedure
--		(9) IS.TN 05-08-15	field [Resort Bin] added

-- $Revision: 10 $

IF EXISTS( SELECT * FROM sys.procedures WHERE [name] = 'up_LoadItemSize' AND [type] = 'P' AND [schema_id] = SCHEMA_ID( 'sap'))
	DROP PROCEDURE [sap].[up_LoadItemSize]
GO

CREATE PROCEDURE [sap].[up_LoadItemSize]
(
	@nHeaderNo		int					-- Header No.
	,@sCompanyP		nvarchar( 30) = ''	--= (8) IS.TN 01-06-15
)
AS
BEGIN

	DECLARE
		@query		nvarchar( 2048)	--= (8) IS.TN 01-06-15
		,@Log		tinyint			--= (5) IS.TN 15-10-12
		,@sMessg	varchar( 250)

	-- table for errorneous entry
	CREATE TABLE dbo.#InvalidEntry(
		EntryNo	int	NOT NULL PRIMARY KEY CLUSTERED
	)

	--> (8) IS.TN 01-06-15
	IF    (@sCompanyP IS NULL)
	   OR (@sCompanyP <> '' and sap.ufn_checkCompanyName( @sCompanyP) = 0)
	BEGIN
		SET @sMessg = 'Invalid company name "' + ISNULL( @sCompanyP, '') + '"'
		RAISERROR( @sMessg, 18, 1)
		RETURN
	END

	-- > (5) IS.TN 15-10-12
	SET @query =
		N'SELECT TOP 1 @1 = [SQL Extra Log] '
			+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Setup', '', 1)
	--select @query
	exec sp_executesql @query, N'@1 int OUTPUT', @1=@Log OUTPUT
	SET @Log = ISNULL( @Log, 0)
	-- < (5) IS.TN 15-10-12
	--< (8) IS.TN 01-06-15


	--> check for asterisk in column 5
	SET @query =
		N'INSERT dbo.#InvalidEntry (EntryNo) '
		+ N' SELECT s.[Entry No_]'
		+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)	-- = (4) IS.TN 10-10-12
		+ N' WHERE  s.[Header No_] = @1'	-- @nHeaderNo
		+ N' AND s.Column1 = @2'			-- 'F201'
		+ N' AND s.Column5 <> @3'			-- '*'
	--select @query
	exec sp_executesql @query, N'@1 varchar( 20), @2 varchar( 10), @3 varchar( 10)', @1=@nHeaderNo, @2='F201', @3='*'

	--SET @sMessg = '17: End of line is missing in Column 5'
	SET @query =
		N'INSERT' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Log', '', 0) + N'('		-- = (4) IS.TN 10-10-12
			+ N' [Status]'
			+ N',[Description]'
			+ N',[Date]'
			+ N',[Time]'
			+ N',[WH SAP Line Buff_ Entry No_]'
			+ N',[WH SAP Header Buff_ No_]'
			+ N',[Message Source]'
			+ N',[Column No_]'
			+ N',[Interface Code]'
			+ N',[Error Code]'
		+ N')'
		+ N' SELECT'
			+ N' @1'	--3
			+ N',''17: End of line is missing in Column 5 for Entry No. '' + CAST( s.[Entry No_] AS varchar( 30)) + '' Interface "F201"'''
			+ N',sap.ufn_getNavDate( default)'			-- = (7) IS.TN 05-12-12
			+ N',sap.ufn_getNavTime( default)'			-- = (7) IS.TN 05-12-12
			+ N',s.[Entry No_]'
			+ N',@3'	--@nHeaderNo
			+ N',@4'	--3
			+ N',@5'	--5
			+ N',@6'	--'F201'
			+ N',@7'	--'WHSQL017'
		  + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)		-- = (4) IS.TN 10-10-12
		+ N' WHERE  s.[Header No_] = @3'	--@nHeaderNo
		   + N' AND s.Column1 = @6'			--'F201'
		   + N' AND s.Column5 <> @8'		--'*'
	--select @query
	exec sp_executesql @query
		,N'@1 int, @3 int, @4 int, @5 int, @6 varchar( 10), @7 varchar( 10), @8 varchar( 10)'
		,@1=3, @3=@nHeaderNo, @4=3, @5=5, @6='F201', @7='WHSQL017', @8='*'
	--< check for asterisk in column 5


	--> check for item in [Item Size] exists
	-- (8) IS.TN 01-06-15	There are no prepacs in work DB
	SET @query =
		N'INSERT dbo.#InvalidEntry (EntryNo)'
		+ N' SELECT s.[Entry No_]'
		+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)		-- = (4) IS.TN 10-10-12
		  -- > (2) IS.TN 28-08-12
		  + N' LEFT JOIN ('
			+ N' SELECT No_'
			+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'Item', '', 1)
				+ N' UNION' +
			+ N' SELECT UPPER( Column2)'
			+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', '', 1)	-- = (4) IS.TN 10-10-12
			+ N' WHERE  [Header No_] = @4'
			   + N' AND Column1 = @1'	-- 'F190P'
		  + N' ) i'
		  -- < (2) IS.TN 28-08-12
			+ N' ON i.No_ = UPPER( s.Column2)'
		  + N' LEFT JOIN dbo.#InvalidEntry e'
			+ N' ON s.[Entry No_] = e.EntryNo'
		+ N' WHERE  s.[Header No_] = @4'
		   + N' AND s.Column1 = @2'		-- 'F201'
		   + N' AND s.Column2 <> @3'	-- ''
		   + N' AND i.No_ IS NULL'
		   + N' AND e.EntryNo IS NULL'
	--select @query
	exec sp_executesql @query
		,N'@1 varchar( 10), @2 varchar( 10), @3 varchar( 20), @4 int'
		,@1='F190P', @2='F201', @3='', @4=@nHeaderNo


	SET @query =
		N'INSERT' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Log', '', 0) + N'('		-- = (4) IS.TN 10-10-12
			+ N' [Status]'
			+ N',[Description]'
			+ N',[Date]'
			+ N',[Time]'
			+ N',[WH SAP Line Buff_ Entry No_]'
			+ N',[WH SAP Header Buff_ No_]'
			+ N',[Message Source]'
			+ N',[Column No_]'
			+ N',[Interface Code]'
			+ N',[Error Code]'
		+ N')'
		+ N' SELECT'
			+ N' @1'	--3
			+ N',''54: Item "'' + UPPER( s.Column2) + ''" was not found for Entry No. '' + CAST( s.[Entry No_] AS varchar( 30)) + '' Interface "F201"'''
			+ N',sap.ufn_getNavDate( default)'			-- = (7) IS.TN 05-12-12
			+ N',sap.ufn_getNavTime( default)'			-- = (7) IS.TN 05-12-12
			+ N',s.[Entry No_]'
			+ N',@2'	--@nHeaderNo
			+ N',@3'	--3
			+ N',@4'	--2
			+ N',@5'	--'F201'
			+ N',@6'	--'WHSQL054'
		  + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)		-- = (4) IS.TN 10-10-12
		  -- > (2) IS.TN 28-08-12
		  + N' LEFT JOIN ('
			+ N' SELECT No_'
			+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'Item', '', 1)
				+ N' UNION'
			+ N' SELECT UPPER( Column2)'
			+ N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', '', 1)	-- = (4) IS.TN 10-10-12
			+ N' WHERE  [Header No_] = @2'	--@nHeaderNo
			   + N' AND Column1 = @7'		--'F190P'
		  + N') i'
		  -- < (2) IS.TN 28-08-12
			+ N' ON i.No_ = UPPER( s.Column2)'
		+ N' WHERE  s.[Header No_] = @2'	--@nHeaderNo
		   + N' AND s.Column1 = @5'			--'F201'
		   + N' AND s.Column2 <> @8'		--''
		   + N' AND i.No_ IS NULL'
	--select @query
	exec sp_executesql	@query
		,N'@1 int, @2 int, @3 int, @4 int, @5 varchar( 10), @6 varchar( 10), @7 varchar( 10), @8 varchar( 10)'
		,@1=3, @2=@nHeaderNo, @3=3, @4=2, @5='F201', @6='WHSQL054', @7='F190P', @8=''
	--< check for item in [Item Size] exists


	--> check for non existing [IAM Size] lines
	SET @query =
		N'INSERT dbo.#InvalidEntry (EntryNo)'
		 + N' SELECT s.[Entry No_]'
		 + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)	--= (4) IS.TN 10-10-12
		 + N' JOIN' + sap.ufn_buildTableName( @sCompanyP, 'Item', 'i', 1)
		 + N' ON i.No_ = UPPER( s.Column2)'
		 + N' LEFT JOIN' + sap.ufn_buildTableName( @sCompanyP, 'IAM Size', 'm', 1)
		 + N' ON m.[Size Scale] = i.[Size Scale]'
		 + N' AND m.[Size Index] = UPPER( s.Column3)'
		 + N' LEFT JOIN dbo.#InvalidEntry e'
		 + N' ON s.[Entry No_] = e.EntryNo'
		+ N' WHERE  s.[Header No_] = @1'	--@nHeaderNo
		 + N' AND s.Column1 = @2'			--'F201'
		 + N' AND s.Column2 <> @3'			--''
		 + N' AND m.[Size Scale] IS NULL'
		 + N' AND e.EntryNo IS NULL'
	--select @query
	exec sp_executesql	@query
		,N'@1 int, @2 varchar( 10), @3 varchar( 10)', @1=@nHeaderNo, @2='F201', @3=''

	SET @query =
		N'INSERT' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Log', '', 0) + N'('		-- = (4) IS.TN 10-10-12
			+ N' [Status]'
			+ N',[Description]'
			+ N',[Date]'
			+ N',[Time]'
			+ N',[WH SAP Line Buff_ Entry No_]'
			+ N',[WH SAP Header Buff_ No_]'
			+ N',[Message Source]'
			+ N',[Column No_]'
			+ N',[Interface Code]'
			+ N',[Error Code]'
		+ N')'
		+ N' SELECT'
			+ N' @1'	--3
			+ N',''43: No size index '' + UPPER( s.Column3) + '' in scale '' + i.[Size Scale] + ''. Line was not loaded'''
			+ N',sap.ufn_getNavDate( default)'			-- = (7) IS.TN 05-12-12
			+ N',sap.ufn_getNavTime( default)'			-- = (7) IS.TN 05-12-12
			+ N',s.[Entry No_]'
			+ N',@2'	--@nHeaderNo
			+ N',@3'	--3
			+ N',@4'	--2
			+ N',@5'	--'F201'
			+ N',@6'	--'WHSQL043'
		  + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)	-- = (4) IS.TN 10-10-12
		  + N' JOIN' + sap.ufn_buildTableName( @sCompanyP, 'Item', 'i', 1)
			+ N' ON s.Column2 = i.No_'
		  + N' LEFT JOIN' + sap.ufn_buildTableName( @sCompanyP, 'IAM Size', 'm', 1)
			+ N' ON m.[Size Scale] = i.[Size Scale]'
		   + N' AND m.[Size Index] = UPPER( s.Column3)'
		+ N' WHERE  s.[Header No_] = @2'	--@nHeaderNo
		   + N' AND s.Column1 = @5'			--'F201'
		   + N' AND s.Column2 <> @6'		--''
		   + N' AND m.[Size Scale] IS NULL'
	--select @query
	exec sp_executesql	@query
		,N'@1 int, @2 int, @3 int, @4 int, @5 varchar( 10), @6 varchar( 10)',
		@1=3, @2=@nHeaderNo, @3=3, @4=2, @5='F201', @6='WHSQL043'
	--< check for non existing [IAM Size] lines

	BEGIN TRAN
		-- update must be first
		-- > update existing [Item Size] lines
		SET @query =
			N'UPDATE' + sap.ufn_buildTableName( @sCompanyP, 'Item Size', '', 0)
			 + N' SET    [Size Name] = s.Column4'
			 + N' FROM'
			 + N' (	SELECT MAX( d.[Entry No_]) AS [EntryNo]'
				   + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 'd', 1)	-- = (4) IS.TN 10-10-12
				 + N' LEFT JOIN dbo.#InvalidEntry y'
					 + N' ON y.EntryNo = d.[Entry No_]'
				 + N' WHERE  d.[Header No_] = @1'	--@nHeaderNo
				    + N' AND d.Column1 = @2'		--'F201'
				    + N' AND y.EntryNo IS NULL'
				 + N' GROUP BY UPPER( d.Column2), UPPER( d.Column3)'
			 + N' ) w'
			   + N' JOIN' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)		-- = (4) IS.TN 10-10-12
				 + N' ON w.EntryNo = s.[Entry No_]'
			   + N' JOIN' + sap.ufn_buildTableName( @sCompanyP, 'Item Size', 'i', 1)
				 + N' ON i.[Item No_] = UPPER( s.Column2)'
			    + N' AND i.[Size Index] = UPPER( s.Column3)'
			 + N' WHERE  s.[Header No_] = @1'		--@nHeaderNo
			    + N' AND s.Column1 = @2'			--'F201'
		--select @query
		exec sp_executesql	@query
			,N'@1 int, @2 varchar( 10)', @1=@nHeaderNo, @2='F201'

		SET @sMessg = '62: up_LoadItemSize updated ' + CAST( @@ROWCOUNT AS varchar( 30)) + ' rows of [Item Size]'
		IF @Log <> 0
			exec sap.up_insertSingleError
				@sCompanyP
				,@sMessg
				,1
				,0
				,@nHeaderNo
				,3
				,0
				,'F201'
				,'WHSQL062'
		-- < update existing [Item Size] lines

		-- > insert new [Item Size] lines
		SET @query =
			N'INSERT' + sap.ufn_buildTableName( @sCompanyP, 'Item Size', '', 0) + N'('
				+ N' [Item No_]'
				+ N',[Size Index]'
				+ N',[Size Name]'
				+ N',[Salomon Item No_]'
				+ N',[VAT Product Group]'
				+ N',[Baby Custom Tariff No_]'
				+ N',[Your reference]'
				+ N',[Qty In Purchase Cr_ Memos]'
				+ N',[Temp Qty_]'
				+ N',[Item ToHandle Qty_]'
				+ N',[Item Init_ Qty_]'
				+ N',[Item ToDo Qty_]'
				+ N',[ITF ToHandle Qty_]'
				+ N',[ITF Init_ Qty_]'
				+ N',[ITF ToDo Qty_]'
				+ N',[ITF InBox Qty_]'
				+ N',[Child?]'
				+ N',[Minimum Box Whsing]'
				+ N',[Maximum Box Whsing]'
				+ N',[Zone]'
				+ N',[Available]'
				+ N',[SizeID]'
				+ N',[Replication Counter]'
				+ N',[Company owner]'
				+ N',[WH abc]'
				--> (8) IS.TN 030113
				+ N',[WH abc New]'
				+ N',[Min Mezzanine Stock Ctns_]'
				+ N',[Min Mezzanine Stock Pcs_]'
				+ N',[Mez_ Floor]'
				--< (8) IS.TN 030113
				--> (9) IS.TN 050815
				+ N',[Resort Wave]'
				+ N',[Resort Bin]'
				--< (9) IS.TN 050815
			+ N')'
			+ N' SELECT'
				+ N' UPPER( s.Column2)'
				+ N',UPPER( s.Column3)'
				+ N',s.Column4'
				+ N','''''
				+ N','''''
				+ N','''''
				+ N','''''
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N',0'
				+ N','''''
				+ N','''''
				--> (8) IS.TN 030113
				+ N','''''
				+ N',0'
				+ N',0'
				+ N','''''
				--< (8) IS.TN 030113
				--> (9) IS.TN 050815
				+ N','''''
				+ N','''''
				--< (9) IS.TN 050815			
				+ N' FROM'
			+ N'(	SELECT MAX( d.[Entry No_]) AS [EntryNo]'
				  + N' FROM' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 'd', 1)		-- = (4) IS.TN 10-10-12
				+ N' LEFT JOIN dbo.#InvalidEntry y'
					+ N' ON y.EntryNo = d.[Entry No_]'
				+ N' WHERE  d.[Header No_] = @1'	--@nHeaderNo
				   + N' AND d.Column1 = @2'			--'F201'
				   + N' AND y.EntryNo IS NULL'
				+ N' GROUP BY UPPER( d.Column2), UPPER( d.Column3)'
			+ N') w'
			  + N' JOIN' + sap.ufn_buildTableName( @sCompanyP, 'WH SAP Line Buff_', 's', 1)		-- = (4) IS.TN 10-10-12
				+ N' ON w.EntryNo = s.[Entry No_]'
			  + N' LEFT JOIN' + sap.ufn_buildTableName( @sCompanyP, 'Item Size', 'i', 1)
				+ N' ON i.[Item No_] = UPPER( s.Column2)'
			   + N' AND i.[Size Index] = UPPER( s.Column3)'
			+ N' WHERE  s.[Header No_] = @1'	--@nHeaderNo 
			   + N' AND s.Column1 = @2'			--'F201'
			   + N' AND i.[Item No_] IS NULL'
		--select @query
		exec sp_executesql @query, N'@1 int, @2 varchar( 10)', @1=@nHeaderNo, @2='F201'

		SET @sMessg = '61: up_LoadItemSize inserted ' + CAST( @@ROWCOUNT AS varchar( 30)) + ' rows of [Item Size]'
		IF @Log <> 0							-- = (5) IS.TN 15-10-12
			exec sap.up_insertSingleError
				@sCompanyP
				,@sMessg
				,1
				,0
				,@nHeaderNo
				,3
				,0
				,'F201'
				,'WHSQL062'
		-- < insert new [Item Size] lines
	COMMIT TRAN
END
GO

EXEC sys.sp_addextendedproperty 
     @name = N'Version',
     @value = N'$Revision: 9 $',
     @level0type = N'SCHEMA',
     @level0name = [sap],
     @level1type = N'PROCEDURE',
     @level1name = [up_LoadItemSize]
GO

-- [sap].[up_LoadItemSize] 255743
