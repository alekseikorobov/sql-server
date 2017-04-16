USE [master]
GO
/****** Object:  StoredProcedure [dbo].[Dubl]    Script Date: 04/16/2017 08:55:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DECLARE @table NVARCHAR(MAX) = 'e_history_221'

ALTER PROCEDURE [dbo].[Dubl] 
		@table NVARCHAR(MAX),
		@isSelect INT = 1
AS 
BEGIN

--select
DECLARE @select NVARCHAR(MAX) = (
SELECT CASE 
			WHEN isgroup = 0 THEN 'MIN('+ nameColumns + ') m,'
			ELSE 'isnull('+nameColumns + ','''') ' +nameColumns+' ,'
       END 
FROM tableList
WHERE /*[type] = 'egrul' AND*/ isgroup IN (1,0) AND nameTable = @table
FOR XML PATH('')
)
SET @select = LEFT(@select,LEN(@select)-1)
--SELECT @select
--group
DECLARE @group NVARCHAR(MAX) =(
SELECT nameColumns + ','
FROM tableList
WHERE /*[type] = 'egrul' AND*/ isgroup IN (1) AND nameTable = @table
FOR XML PATH('')
)
SET @group = LEFT(@group,LEN(@group)-1)
--SELECT @group
--on
DECLARE @on NVARCHAR(MAX) =(
SELECT
	   CASE 
			WHEN isgroup = 0 THEN 'e.'+nameColumns+' <> s.m and ' 
			ELSE 'isnull(e.'+nameColumns+','''') = s.'+nameColumns+' and '
       END 

FROM tableList
WHERE /*[type] = 'egrul' AND*/ isgroup IN (1,0) AND nameTable = @table
FOR XML PATH('')
)
SET @on = LEFT(@on,LEN(@on)-3)
SET @on = REPLACE(@on,'&lt;&gt;','<>')
--SELECT @on
CREATE TABLE #resSql(NAME NVARCHAR(MAX),c int)
--query
IF(@isSelect = 1)
		BEGIN
			DECLARE @sql NVARCHAR(MAX) = 'with s as( SELECT '+@select+ ' ,count(*) c'+
			   ' from ' + @table + ' with(nolock) '+
			   ' group by ' + @group+
			   ' having count(*) > 1 ) '+
			   ' SELECT ''' + @table +''' name ,COUNT(*) c' +	--'e_history_0',COUNT(*)		   
			   ' from ' + @table +' e with(nolock) join s on '+ @on
			 insert into #resSql  
			 EXEC(@sql)
			 SELECT * FROM #resSql
			 IF	(SELECT c FROM #resSql) > 0
			 BEGIN    
				SELECT @sql
			 end			  
		END
		ELSE
		BEGIN
			SELECT 'with s as( SELECT '+@select+
			   ' from ' + @table +
			   ' group by ' + @group+
			   ' having count(*) > 1 ) '+			    
			   ' delete ' + @table +
			   ' from ' + @table +' e join s on '+ @on
		END	
END
