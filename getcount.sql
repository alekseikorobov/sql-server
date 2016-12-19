USE [master]
GO
/****** Object:  StoredProcedure [dbo].[getcount]    Script Date: 19.12.2016 16:43:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		korobov
-- Create date: 
-- Description:	выборка объектов по всем базам
-- =============================================
alter PROCEDURE [dbo].[getcount]	
	@sh nvarchar(max) = null, --схема
	@name nvarchar(max)  =null,  --название объекта (по like)
	@db nvarchar(max) = null --название базы данных (по like)
AS
BEGIN
	SET NOCOUNT ON;	

	declare @name_where nvarchar(max)='t.name like '''+@name+''''
	declare @schema_where nvarchar(max)='sh.name like '''+@sh+''''
	
	declare @precommand nvarchar(max) = 'if OBJECT_ID(''tempdb..##t_count'') is not null drop table ##t_count create table ##t_count(db nvarchar(max),sh nvarchar(max),tname nvarchar(max),reserved_kb int,index_size_kb int,rows int)'
	
	declare @q1_insert nvarchar(max) = 'insert into ##t_count(db,sh,tname,reserved_kb,index_size_kb,rows)';
	declare @q2_select nvarchar(max) = 'SELECT ''[?]'',sh=sh.name,t=t.name, --ss.object_id,
	reserved_kb=SUM (ss.reserved_page_count) +isnull(part.reserved_page_count,0) , --@reservedpages
	index_size_kb =((CASE WHEN SUM (ss.used_page_count)+isnull(part.used_page_count,0) > SUM (
		CASE
			WHEN (index_id < 2) THEN (in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)
			ELSE lob_used_page_count + row_overflow_used_page_count
		END
		) THEN (SUM (ss.used_page_count)+isnull(part.used_page_count,0) - SUM (
		CASE
			WHEN (index_id < 2) THEN (in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)
			ELSE lob_used_page_count + row_overflow_used_page_count
		END
		)) ELSE 0 END) * 8),
	rows=SUM (
		CASE
			WHEN (index_id < 2) THEN row_count
			ELSE 0
		END
		)';
	declare @q_from1 nvarchar(max) = 'SELECT it.parent_id,reserved_page_count = sum(reserved_page_count),used_page_count = sum(used_page_count)
										FROM [?].sys.dm_db_partition_stats p, sys.internal_tables it
										WHERE it.internal_type IN (202,204,211,212,213,214,215,216) AND p.object_id = it.object_id
										group by it.parent_id'
	declare @q3_from nvarchar(max) = 'FROM [?].sys.dm_db_partition_stats ss join [?].sys.tables t on t.object_id=ss.object_id
								  join [?].sys.schemas sh on sh.schema_id = t.schema_id
								  left join ('+@q_from1+') part on part.parent_id = ss.object_id'
	declare @q4_group nvarchar(max) = 'group by sh.name,t.name,ss.object_id,part.reserved_page_count,part.used_page_count'
	
	declare @where1 nvarchar(max) = coalesce(@name_where + 'and '+@schema_where ,@name_where,@schema_where);
	declare @where nvarchar(max) = isnull(' where ' + @where1,'');

	--declare @tab nvarchar(max) = ',[query]=case when [type] = ''USER_TABLE'' then ''select top 100 * from ''+db+''.[''+sh+''].[''+name+'']'' else null end'	
	declare @postcommand nvarchar(max) =  'select * from ##t_count order by db,sh,tname,rows'

	declare  @q nvarchar(max) =  @q1_insert +' '+ @q2_select +' '+ @q3_from +' '+@where+' '+ @q4_group

	if @db is not null and @db != ''
	begin
		if not exists (select 1 from sys.databases where name like @db)
		begin
			print 'Нет совпадения с базой данных по названию ' + @db
			return;
		end
		set @q = 'if (''?'' like '''+@db + ''') ' + @q
	end

	if(len(@q)>2000)
	begin
		print 'Запрос не получится выполнить корректно, так как его длина больше 2000 символов!'
		return;
	end

	exec sp_msforeachdb @precommand = @precommand, @command1=@q ,@postcommand = @postcommand

END

--exec [dbo].[getcount] @db = 'kdb_test' @type = 'USER_TABLE',@name='%l%'

--exec [dbo].[getcount] @db = 'kdb_test',@name = '%Engagement%'

