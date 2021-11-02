IF EXISTS ( SELECT 1 FROM TEMPDB.SYS.tables WHERE name like '#temperror%')
BEGIN
	DROP TABLE #TEMPERROR
END
create table #temperror
(logdate datetime,
processinfo varchar(20),
text varchar(2000)
)

insert into #temperror
EXEC sys.xp_readerrorlog 0,1, N'Logging SQL Server messages in file', NULL, NULL,NULL,N'asc'
go
declare @len int 
declare @subst varchar(2000)
declare @fileloc varchar(2000)
select @len = len(SUBSTRING([text],38,2000) ),@subst =  SUBSTRING([text],38,2000) 
from #temperror
select @fileloc = substring (@subst, 1,@len -11) + '\ErrorReported'
DECLARE @filelocxel varchar(2000) = @fileloc + '*.xel'
DECLARE @filelocxem varchar(2000) = @fileloc + '*.xem'
select @filelocxel AS [file location xel], @filelocxem as [file location xem] -- use these values below, or put in your own location

CREATE EVENT SESSION [Error_reported]
ON SERVER
    ADD EVENT sqlserver.error_reported
    (ACTION
     (
         sqlserver.client_app_name,
         sqlserver.nt_username,
         sqlserver.sql_text,
         sqlserver.username
     )
     WHERE (
               [package0].[greater_than_equal_int64]([severity], (16))
               OR [error] = (6004)
               OR [error] = (15469)
			   OR [error] = (15470)
			   OR [error] = (15472)
			   OR [error] = (15562)
			   OR [error] = (15622)
			   OR [error] = (3701)
			   OR [error] = (15388)
			   OR [error] = (229)
			   OR [error] = (230)
			   OR [error] = (300)
			   OR [error] = (2104)
			   OR [error] = (15457)
           )
    )
    ADD TARGET package0.asynchronous_file_target
	(set filename = 'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Log\ErrorReported.xel' ,
		metadatafile = 'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Log\ErrorReported.xem',
		max_file_size = 10,
		max_rollover_files = 5) 
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 90 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
);
GO

ALTER EVENT SESSION [Error_Reported] ON SERVER STATE = START;
GO


IF EXISTS ( SELECT 1 FROM TEMPDB.SYS.tables WHERE name like '#temperror%')
BEGIN
	DROP TABLE #TEMPERROR
END
create table #temperror
(logdate datetime,
processinfo varchar(20),
text varchar(2000)
)

insert into #temperror
EXEC sys.xp_readerrorlog 0,1, N'Logging SQL Server messages in file', NULL, NULL,NULL,N'asc'
go
declare @len int 
declare @subst varchar(2000)
declare @fileloc varchar(2000)
select @len = len(SUBSTRING([text],38,2000) ),@subst =  SUBSTRING([text],38,2000) 
from #temperror
select @fileloc = substring (@subst, 1,@len -11) + '\ErrorReported'
DECLARE @filelocxel varchar(2000) = @fileloc + '*.xel'
declare @filelocxem varchar(2000) = @fileloc + '*.xem'

;WITH CTE AS
(
SELECT  StartTime = d.value(N'(/event/@timestamp)[1]', N'datetime'),
		Error_Reported = d.value(N'(/event/data[@name="message"]/value)[1]', N'varchar(max)'),
		UserNAme = d.value(N'(/event/action[@name="username"]/value)[1]', N'varchar(128)'),
		NTUserNAme = d.value(N'(/event/action[@name="nt_username"]/value)[1]', N'varchar(128)'),
		SQL_Text = ISNULL(d.value(N'(/event/action[@name="sql_text"]/value)[1]', N'varchar(max)'),'No SQL Text for this error'),
		ClientApplication = d.value(N'(/event/action[@name="client_app_name"]/value)[1]',N'varchar(128)'),
		[error] = d.value(N'(/event/data[@name="error_number"]/value)[1]',N'int'),
		[Severity] = d.value(N'(/event/data[@name="severity"]/value)[1]',N'int'),
		[State] = d.value(N'(/event/data[@name="state"]/value)[1]',N'int'),
		[Database_name] = d.value(N'(/event/action[@name="database_name"]/value)[1]', N'varchar(128)')
FROM
(
    SELECT CONVERT(XML, event_data) 
    FROM sys.fn_xe_file_target_read_file(@filelocxel ,@filelocxem,NULL,NULL)
) AS x(d)
)
SELECT * FROM CTE;
