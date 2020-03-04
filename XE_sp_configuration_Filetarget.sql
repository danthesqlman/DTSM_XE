
--This XE traces sp_configure changes and the messages that was executed. 
--Only fires when sp_configure changes very light.
IF NOT EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = 'Audit_SP_configure')
	BEGIN
		CREATE EVENT SESSION [Audit_SP_configure] ON SERVER 
			ADD EVENT sqlserver.error_reported(
				ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.is_system,sqlserver.nt_username,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.session_nt_username,sqlserver.session_server_principal_name,sqlserver.sql_text,sqlserver.username)
				WHERE ([package0].[equal_int64]([error_number],(15457)) AND [sqlserver].[client_app_name]<>N'SQLServerCEIP'))
			ADD TARGET package0.event_file(SET filename=N'c:\temp\Audit_SP_configure',max_rollover_files=(0))
			WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=60 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_CPU,TRACK_CAUSALITY=ON,STARTUP_STATE=ON);
	ALTER EVENT SESSION Audit_SP_configure
		ON SERVER
	STATE=START;
	END


EXEC sp_configure 'xp_cmdshell', 1



;WITH CTE AS
(
SELECT  StartTime = d.value(N'(/event/@timestamp)[1]', N'datetime'),
		Config_Change = d.value(N'(/event/data[@name="message"]/value)[1]', N'varchar(max)'),
		UserNAme = d.value(N'(/event/action[@name="username"]/value)[1]', N'varchar(128)'),
		SQL_Text = d.value(N'(/event/action[@name="sql_text"]/value)[1]', N'varchar(max)'),
		ClientApplication = d.value(N'(/event/action[@name="client_app_name"]/value)[1]',N'varchar(128)')
FROM
(
    SELECT CONVERT(XML, event_data) 
    FROM sys.fn_xe_file_target_read_file('C:\Temp\Audit_SP_configure*.xel',NULL,NULL,NULL)
) AS x(d)
)
SELECT * FROM CTE;