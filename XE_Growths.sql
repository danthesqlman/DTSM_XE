CREATE EVENT SESSION [Growths] ON SERVER 
ADD EVENT sqlserver.database_file_size_change(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.nt_username,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)),
ADD EVENT sqlserver.databases_data_file_size_changed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.nt_username,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)),
ADD EVENT sqlserver.databases_log_file_size_changed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.nt_username,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text,sqlserver.username)),
ADD EVENT sqlserver.databases_log_growth(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.nt_username,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text,sqlserver.username))
ADD TARGET package0.event_file(SET filename=N'Growths',max_file_size=(10))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO


ALTER EVENT SESSION [Growths] ON SERVER STATE = START;

GO

DECLARE @FileName NVARCHAR(4000)
SELECT @FileName = target_data.value('(EventFileTarget/File/@name)[1]','nvarchar(4000)')
FROM (
	SELECT CAST(target_data AS XML) target_data
	FROM sys.dm_xe_sessions s
	JOIN sys.dm_xe_session_targets t
		ON s.address = t.event_session_address
	WHERE s.name = N'Growths'
	) ft
;

/*top select columns must match bottom, add or subtract NULL below as needed */
SELECT

  dateadd(minute, datediff(minute, sysutcdatetime(), sysdatetime()), n.value('(@timestamp)[1]', 'datetime2'))  as timestamp1
 , n.value ('(action[@name="database_name"]/value)[1]', 'nvarchar(50)') AS database_name
 , n.value ('(action[@name="client_app_name"]/value)[1]','nvarchar(50)') AS client_app_name
 , n.value ('(action[@name="client_hostname"]/value)[1]','nvarchar(50)') AS Client_HostName
 , n.value ('(data[@name="duration"]/value)[1]', 'int') AS duration_in_MS
 , n.value ('(data[@name="file_type"]/text)[1]','nvarchar(50)') AS file_type
 , n.value ('(action[@name="session_id"]/value)[1]','nvarchar(50)') AS session_id
 , n.value ('(data[@name="file_name"]/value)[1]','nvarchar(50)') AS file_names
 , n.value ('(data[@name="is_automatic"]/value)[1]','nvarchar(50)') AS Is_Automatic
 , n.value ('(action[@name="sql_text"]/value)[1]','nvarchar(4000)') AS SQL_Text
 , n.value ('(data[@name="size_change_kb"]/value)[1]', 'int')/1024.0 AS size_change_mb
 , n.value ('(data[@name="total_size_kb"]/value)[1]', 'int')/1024.0 AS total_size_mb
 , n.value ('(action[@name="username"]/value)[1]', 'varchar(50)') AS username
 , n.value ('(action[@name="server_principal_name"]/value)[1]', 'nvarchar(50)') AS server_principal_name
 , n.value ('(action[@name="nt_username"]/value)[1]', 'varchar(50)') AS nt_username
FROM
 (
	SELECT CAST(event_data AS XML) AS event_data
	FROM sys.fn_xe_file_target_read_file(@FileName, NULL, NULL, NULL)
) AS Event_Data_Table
CROSS APPLY event_data.nodes('event') AS q(n)

UNION ALL
 /* helps to see what the current drivespace looks like. */
SELECT GETDATE() as timestamp,
	'Drive:  ' + fixed_drive_path  , 
	'Available Space GB:  ' + CAST(CONVERT(DECIMAL(18,2), free_space_in_bytes/1073741824.0) as varchar(50)) 
	,Null,null,null,null,null,null,null,null,null,null,null,null
FROM sys.dm_os_enumerate_fixed_drives WITH (NOLOCK) 
Order by 1 desc