USE [master]
GO
/****** Object:  StoredProcedure [dbo].[getobject]    Script Date: 16.12.2016 14:39:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		korobov
-- Create date: 
-- Description:	выборка объектов по всем базам
-- =============================================
ALTER PROCEDURE [dbo].[getobject]	
	@type nvarchar(max) = null, --тип объекта
	@sh nvarchar(max) = null, --схема
	@name nvarchar(max)  =null,  --название объекта (по like)
	@db nvarchar(max) = null --название базы данных (по like)
AS
BEGIN
	SET NOCOUNT ON;
	if( @type is not null )
	begin 
		if not exists (select * from (
			select 'AF' t,'AGGREGATE_FUNCTION' t_d union 
			select 'C' t,'CHECK_CONSTRAINT' t_d union 
			select 'D' t,'DEFAULT_CONSTRAINT' t_d union 
			select 'F' t,'FOREIGN_KEY_CONSTRAINT' t_d union 
			select 'FN' t,'SQL_SCALAR_FUNCTION' t_d union 
			select 'FS' t,'CLR_SCALAR_FUNCTION' t_d union 
			select 'FT' t,'CLR_TABLE_VALUED_FUNCTION' t_d union 
			select 'IF' t,'SQL_INLINE_TABLE_VALUED_FUNCTION' t_d union 
			select 'IT' t,'INTERNAL_TABLE' t_d union 
			select 'P' t,'SQL_STORED_PROCEDURE' t_d union 
			select 'PC' t,'CLR_STORED_PROCEDURE' t_d union 
			select 'PK' t,'PRIMARY_KEY_CONSTRAINT' t_d union 
			select 'S' t,'SYSTEM_TABLE' t_d union 
			select 'SN' t,'SYNONYM' t_d union 
			select 'SQ' t,'SERVICE_QUEUE' t_d union 
			select 'TF' t,'SQL_TABLE_VALUED_FUNCTION' t_d union 
			select 'TR' t,'SQL_TRIGGER' t_d union 
			select 'TT' t,'TYPE_TABLE' t_d union 
			select 'U' t,'USER_TABLE' t_d union 
			select 'UQ' t,'UNIQUE_CONSTRAINT' t_d union 
			select 'V' t,'VIEW' t_d
		) as s where t like @type or t_d like @type)
		begin
			print 'Выбранного типи ''' + @type + ''' не существует'
			return;
		end
	end
	
	declare @type_where nvarchar(max)='o.type='''+@type+''''
	if(len(@type) > 3)
	begin
		set @type_where ='o.type_desc='''+@type+''''
	end
	declare @name_where nvarchar(max)='o.name like '''+@name+''''
	declare @schema_where nvarchar(max)='s.name like '''+@sh+''''
	
	declare @precommand nvarchar(max) = 'if object_id(''tempdb..##t'') is not null begin drop table ##t end create table ##t(db nvarchar(max),sh nvarchar(max),name nvarchar(max),type nvarchar(max))'
	declare @q nvarchar(max) = 'insert ##t(db,sh,name,type) select ''[?]'',s.name,o.name,o.type_desc from [?].sys.objects o  join [?].sys.schemas s on o.schema_id=s.schema_id';
	declare @where1 nvarchar(max) = coalesce(@type_where + ' and '+@name_where,@type_where,@name_where);
	declare @where2 nvarchar(max) = coalesce(@where1 + 'and '+@schema_where ,@where1,@schema_where);
	declare @where nvarchar(max) = isnull(' where ' + @where2,'');

	declare @tab nvarchar(max) = ',[query]=case when [type] = ''USER_TABLE'' then ''select top 100 * from ''+db+''.[''+sh+''].[''+name+'']'' else null end'	
	declare @postcommand nvarchar(max) =  'select *'+@tab+' from ##t order by db,sh,type,name'

	set @q = @q + @where

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

--exec [dbo].[getobject] @type = 'USER_TABLE',@name='%l%'
