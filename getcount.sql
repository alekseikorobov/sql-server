USE [master]
GO
/****** Object:  StoredProcedure [dbo].[getcount]    Script Date: 4/28/2019 11:27:25 AM ******/
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
	
	declare @precommand nvarchar(max) = 'if OBJECT_ID(''tempdb..##t_count'') is not null drop table ##t_count create table ##t_count(db nvarchar(max),sh nvarchar(max),tname nvarchar(max),reserved_kb int,index_size_kb int,rows int,data int,unused int)'
	
	declare @q1_insert nvarchar(max) = 'insert into ##t_count(db,sh,tname,reserved_kb,index_size_kb,rows,data,unused)';
	declare @q2_select nvarchar(max) = 'SELECT
			''[?]'',
			[schemaname] = a3.name,
			[tablename] = a2.name,
			reserved = (a1.reserved + ISNULL(a4.reserved,0))* 8,
			index_size = (CASE WHEN (a1.used + ISNULL(a4.used,0)) > a1.data THEN (a1.used + ISNULL(a4.used,0)) - a1.data ELSE 0 END) * 8,
			row_count = a1.rows,
			data = a1.data * 8,
			unused = (CASE WHEN (a1.reserved + ISNULL(a4.reserved,0)) > a1.used THEN (a1.reserved + ISNULL(a4.reserved,0)) - a1.used ELSE 0 END) * 8
	FROM
			(SELECT
				ps.object_id,
				[rows] = SUM (CASE WHEN (ps.index_id < 2) THEN row_count ELSE 0 END),
				reserved = SUM (ps.reserved_page_count),
				data = SUM (CASE WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count)
								ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count)
							END),
				used = SUM (ps.used_page_count)
				FROM [?].sys.dm_db_partition_stats ps
			GROUP BY ps.object_id) AS a1
				LEFT JOIN
					(SELECT
						it.parent_id,
						reserved = SUM(ps.reserved_page_count),
						used = SUM(ps.used_page_count)
						FROM [?].sys.dm_db_partition_stats ps
					JOIN [?].sys.internal_tables it ON it.object_id = ps.object_id
					WHERE it.internal_type IN (202,204)
					GROUP BY it.parent_id) 
				AS a4 ON a4.parent_id = a1.object_id
			JOIN [?].sys.all_objects a2  ON a1.object_id = a2.object_id 
			JOIN [?].sys.schemas a3 ON a2.schema_id = a3.schema_id			
		';
	declare @q_from1 nvarchar(max) = 'SELECT it.parent_id,reserved_page_count = sum(reserved_page_count),used_page_count = sum(used_page_count)
										FROM [?].sys.dm_db_partition_stats p, sys.internal_tables it
										WHERE it.internal_type IN (202,204,211,212,213,214,215,216) AND p.object_id = it.object_id
										group by it.parent_id'
	declare @q3_from nvarchar(max) = 'FROM [?].sys.dm_db_partition_stats ss join [?].sys.tables t on t.object_id=ss.object_id
								  join [?].sys.schemas sh on sh.schema_id = t.schema_id
								  left join ('+@q_from1+') part on part.parent_id = ss.object_id'
	
	
	declare @where1 nvarchar(max) = coalesce(@name_where + 'and '+@schema_where ,@name_where,@schema_where);
	declare @where nvarchar(max) = 'WHERE a2.type <> N''S'' and a2.type <> N''IT'''+  isnull(' AND ' + @where1,'');

	--declare @tab nvarchar(max) = ',[query]=case when [type] = ''USER_TABLE'' then ''select top 100 * from ''+db+''.[''+sh+''].[''+name+'']'' else null end'	
	declare @postcommand nvarchar(max) =  'select db,sh,tname,reserved_kb,index_size_kb,data,unused,rows from ##t_count order by db,sh,tname,rows'

	declare  @q nvarchar(max) =  @q1_insert +' '+ @q2_select +' '+@where
	--print(@q)
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

	PRINT @postcommand
END
