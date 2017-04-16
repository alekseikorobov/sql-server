USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_HelptextS]    Script Date: 04/16/2017 08:54:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[sp_HelptextS]
			@db NVARCHAR(MAX),
			@like NVARCHAR(MAX) = ''
as  
BEGIN
DECLARE @q NVARCHAR(MAX)= N'declare @objname nvarchar(776)
declare @dbname sysname  
,@objid int  
,@BlankSpaceAdded   int  
,@BasePos       int  
,@CurrentPos    int  
,@TextLength    int  
,@LineId        int  
,@AddOnLen      int  
,@LFCR          int
,@DefinedLength int  
,@SyscomText nvarchar(4000)  
,@Line          nvarchar(255)  
  
select @DefinedLength = 255  
select @BlankSpaceAdded = 0 
CREATE TABLE #CommentText  
(objname NVARCHAR(MAX), LineId INT ,Text  nvarchar(max) collate database_default)  

  declare ms_crs_syscom  CURSOR LOCAL  
  FOR 
  SELECT o.name, TEXT + char(13)+char(10) from ['+@db+'].sys.syscomments s JOIN ['+@db+'].sys.objects o ON s.id=o.[object_id] where encrypted = 0
  AND o.[type] = ''P''
  ORDER BY number, colid
    
  FOR READ ONLY  
select @LFCR = 2  
select @LineId = 1  

DECLARE @ObjName_temp NVARCHAR(MAX) = ''''
DECLARE @isNew BIT = 0
  
OPEN ms_crs_syscom  
  
FETCH NEXT from ms_crs_syscom into @objname,@SyscomText  
  
WHILE @@fetch_status >= 0  
begin  
  
  IF(@ObjName_temp <> @objname)
  BEGIN
  	set @ObjName_temp = @objname
  	SET @LineId = 1  	
  END  
  
    select  @BasePos    = 1  
  select  @CurrentPos = 1  
    select  @TextLength = LEN(@SyscomText)  
  
    WHILE @CurrentPos  != 0  
    begin        
        select @CurrentPos =   CHARINDEX(char(13)+char(10), @SyscomText, @BasePos)
        
        IF @CurrentPos != 0 
        begin  
            while (isnull(LEN(@Line),0) + @BlankSpaceAdded + @CurrentPos-@BasePos + @LFCR) > @DefinedLength  
            begin  
                select @AddOnLen = @DefinedLength-(isnull(LEN(@Line),0) + @BlankSpaceAdded)  
                INSERT #CommentText VALUES  
                (@objname, @LineId,  
                  isnull(@Line, N'''') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''''))  
                select @Line = NULL, @LineId = @LineId + 1,  
                       @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0  
            end  
            select @Line    = isnull(@Line, N'''') + isnull(SUBSTRING(@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'''')  
            select @BasePos = @CurrentPos+2  
            INSERT #CommentText VALUES(@objname, @LineId, @Line )  
            select @LineId = @LineId + 1  
            select @Line = NULL  
        end  
        else   
        begin  
            IF @BasePos <= @TextLength  
            begin    
                while (isnull(LEN(@Line),0) + @BlankSpaceAdded + @TextLength-@BasePos+1 ) > @DefinedLength  
                begin  
                    select @AddOnLen = @DefinedLength - (isnull(LEN(@Line),0) + @BlankSpaceAdded)  
                    INSERT #CommentText VALUES  
                    ( @objname,@LineId,  
                      isnull(@Line, N'''') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''''))  
                    select @Line = NULL, @LineId = @LineId + 1,  
                        @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0  
                end  
                select @Line = isnull(@Line, N'''') + isnull(SUBSTRING(@SyscomText, @BasePos, @TextLength-@BasePos+1 ), N'''')  
                if LEN(@Line) < @DefinedLength and charindex('' '', @SyscomText, @TextLength+1 ) > 0  
                begin  
                    select @Line = @Line + '' '', @BlankSpaceAdded = 1  
                end  
            end  
        end  
    end  
  
 FETCH NEXT from ms_crs_syscom into @objname,@SyscomText  
end  
  
IF @Line is NOT NULL  
    INSERT #CommentText VALUES(@objname, @LineId, @Line )  
    
SELECT '''+@db+''',* from #CommentText
' + CASE WHEN @like = '' THEN '' ELSE ' where [Text] like ''%'+@like+'%'' ' END +' 
order BY objname,LineId
  
CLOSE  ms_crs_syscom  
DEALLOCATE  ms_crs_syscom  
  
DROP TABLE  #CommentText' 

EXEC(@q)
--SELECT @q
END

 /*'master'
 truncate table #allData
--CREATE TABLE #allData(n NVARCHAR(MAX),objname NVARCHAR(MAX), LineId INT, Line NVARCHAR(MAX))
declare @cmd varchar(500)
set @cmd='IF ''?'' NOT IN(''master'',''msdb'',''tempdb'',''model'',''ReportServer'',''ReportServerTempDB'')
		INSERT INTO #allData(n,objname,LineId,Line) EXEC [sp_HelptextS] ''?'''
exec sp_MSforeachdb @cmd

SELECT * FROM #allData*/
