USE master;
GO

DECLARE @sql NVARCHAR(MAX);

IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'Audit_Name')
BEGIN
    DECLARE @guid UNIQUEIDENTIFIER = NEWID();
    SET @sql
        = N'CREATE SERVER AUDIT [Audit_Name]
		TO APPLICATION_LOG WITH
		(    
		    QUEUE_DELAY = 1000
			,ON_FAILURE = CONTINUE
			,Audit_Name_GUID = ''' + CONVERT(NVARCHAR(100), @guid) + N'''
		)WHERE ([database_name]<>''tempdb'')';
    EXEC sp_executesql @sql;
    ALTER SERVER AUDIT Audit_Name
    WITH
    (
        STATE = ON
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.server_audit_specifications
    WHERE name = 'Audit_Name'
)
BEGIN
    SET @sql
        = N'
		CREATE SERVER AUDIT SPECIFICATION [Audit_Name]
		FOR SERVER Audit_Name [Audit_Name]
		ADD (Audit_CHANGE_GROUP), 
		ADD (DBCC_GROUP),
		ADD (DATABASE_CHANGE_GROUP),
		ADD (DATABASE_OBJECT_CHANGE_GROUP),
		ADD (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP),
		ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
		ADD (DATABASE_OWNERSHIP_CHANGE_GROUP),
		ADD (DATABASE_PERMISSION_CHANGE_GROUP),
		ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
		ADD (DATABASE_PRINCIPAL_IMPERSONATION_GROUP),
		ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
		ADD (SCHEMA_OBJECT_CHANGE_GROUP),
		ADD (SERVER_OBJECT_CHANGE_GROUP),
		ADD (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP),
		ADD (SERVER_PERMISSION_CHANGE_GROUP),
		ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
		ADD (SERVER_PRINCIPAL_IMPERSONATION_GROUP),
		ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
		ADD (SERVER_STATE_CHANGE_GROUP),
		ADD (TRACE_CHANGE_GROUP)
		WITH (STATE = ON)';
    EXEC sp_executesql @sql;
END;




--This XE traces sp_configure changes and the messages that was executed. 
--Only fires when sp_configure changes very light.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_xe_sessions
    WHERE name = 'Audit_Name_Data'
)
BEGIN
    CREATE EVENT SESSION [Audit_Name_Data]
    ON SERVER
        ADD EVENT sqlserver.error_reported
        (ACTION
         (
             sqlserver.client_app_name,
             sqlserver.client_hostname,
             sqlserver.is_system,
             sqlserver.nt_username,
             sqlserver.server_instance_name,
             sqlserver.server_principal_name,
             sqlserver.session_nt_username,
             sqlserver.session_server_principal_name,
             sqlserver.sql_text,
             sqlserver.username
         )
         WHERE (
                   [package0].[equal_int64]([error_number], (15457))
                   AND [sqlserver].[client_app_name] <> N'SQLServerCEIP'
               )
        ),
        ADD EVENT sqlserver.object_altered
        (ACTION
         (
             sqlserver.client_app_name,
             sqlserver.client_hostname,
             sqlserver.is_system,
             sqlserver.nt_username,
             sqlserver.server_instance_name,
             sqlserver.server_principal_name,
             sqlserver.session_nt_username,
             sqlserver.session_server_principal_name,
             sqlserver.sql_text,
             sqlserver.username
         )
         WHERE ([sqlserver].[client_app_name] <> N'SQLServerCEIP')
        )
        ADD TARGET package0.event_file
        (SET filename = N'Audit_Name_Data', max_rollover_files = (0))
    --By naming target here, it will go to default directory for log files and not needed to be modified, but is doable
    WITH
    (
        MAX_MEMORY = 8192KB,
        EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
        MAX_DISPATCH_LATENCY = 5 SECONDS,
        MAX_EVENT_SIZE = 0KB,
        MEMORY_PARTITION_MODE = PER_CPU,
        TRACK_CAUSALITY = ON,
        STARTUP_STATE = ON
    );
    ALTER EVENT SESSION Audit_Name_Data ON SERVER STATE = START;
END;


USE master;
GO
DECLARE @emailrecipients NVARCHAR(500) = N'email@email.com'; -- email address or distrobution you want to assign
DECLARE @smtpprofilename NVARCHAR(100) = N'Agent Mail'; -- Name of the dbmail profile to be sent from. 
--If we use a DEFAULT dbsend mail, also needing to comment out line 104
DECLARE @sub NVARCHAR(500);
DECLARE @sql NVARCHAR(MAX);
--Creates trigger on server for any login being elevated to sysadmin
--Example
--Server permission notification for: 
--Logging this information to a table is doable as well. 
--Opting for email as well due to sysadmin could delete data and would be high priority to have emailed out. 
SET @sub = N'Server permission URGENT notification for: ' + @@servername;
SET @sql
    = N'CREATE TRIGGER srvr_Audit_NameSysAdmin
	ON ALL SERVER
	FOR ADD_SERVER_ROLE_MEMBER
AS BEGIN
	IF EVENTDATA().value(''(/EVENT_INSTANCE/RoleName)[1]'', ''nvarchar(max)'') = ''sysadmin''
		BEGIN
			DECLARE @message nvarchar(max) 
			SET @message = ''Please look into '' + EVENTDATA().value(''(/EVENT_INSTANCE/EventType)[1]'', ''nvarchar(100)'') + CHAR(10) +
							'' for '' + EVENTDATA().value(''(/EVENT_INSTANCE/ServerName)[1]'', ''nvarchar(100)'') + '' BY Login: '' + 
							EVENTDATA().value(''(/EVENT_INSTANCE/LoginName)[1]'', ''nvarchar(100)'') + CHAR(10)+ '' For login: ''+
							EVENTDATA().value(''(/EVENT_INSTANCE/ObjectName)[1]'', ''nvarchar(100)'') + '' was promoted to sysadmin at: '' +  
							EVENTDATA().value(''(/EVENT_INSTANCE/PostTime)[1]'', ''nvarchar(100)'')
			BEGIN TRY
			EXEC  msdb.dbo.sp_send_dbmail
			@profile_name =  ''' + @smtpprofilename + N''',
			@recipients = ''' + @emailrecipients + N''',
			@subject = ''' + @sub
      + N''',
			@body = @message,
			@body_format =''HTML''
			END TRY
			BEGIN CATCH
				--error catching
			END CATCH
		--Insert into Audit_NameTable if you wish.

		END
END;';
EXEC sp_executesql @sql;
