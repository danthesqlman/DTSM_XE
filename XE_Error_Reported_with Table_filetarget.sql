USE db_administration
GO
IF EXISTS (SELECT 1 FROM SYS.tables WHERE name = 'SQL_Error_Reported') 
	BEGIN 
		DROP TABLE dbo.SQL_Error_Reported
	END
GO
CREATE TABLE dbo.SQL_Error_Reported
(
	ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	Start_time DATETIME2 NOT NULL,
	Error_Reported VARCHAR(MAX) NOT NULL,
	UserName VARCHAR(128) NOT NULL,
	NTUsername VARCHAR(128) NULL,
	SQL_Text NVARCHAR(MAX) NULL,
	ClientApplication VARCHAR(128) NULL,
	[ERROR_NUMBER] INT NOT null,
	[Severity] INT NOT null,
	[State] INT NOT null,
	[Database_name] VARCHAR(128) null
)
GO

IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'Error_reported') 
	BEGIN
		DROP EVENT SESSION [Error_reported] ON SERVER;
	END
GO
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
               OR [error_number] = (6004)
               OR [error_number] = (15469)
               OR [error_number] = (15470)
               OR [error_number] = (15472)
               OR [error_number] = (15562)
               OR [error_number] = (15622)
               OR [error_number] = (3701)
               OR [error_number] = (15388)
               OR [error_number] = (229)
               OR [error_number] = (230)
               OR [error_number] = (300)
               OR [error_number] = (2104)
           )
    )
    ADD TARGET package0.event_file
    (SET filename = N'c:\temp\Error_reported')
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 300 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
);

GO

;WITH CTE
AS
(
SELECT  StartTime = d.value(N'(/event/@timestamp)[1]', N'datetime'),
		Error_Reported = d.value(N'(/event/data[@name="message"]/value)[1]', N'varchar(max)'),
		UserNAme = d.value(N'(/event/action[@name="username"]/value)[1]', N'varchar(128)'),
		NTUserNAme = d.value(N'(/event/action[@name="nt_username"]/value)[1]', N'varchar(128)'),
		SQL_Text = ISNULL(d.value(N'(/event/action[@name="sql_text"]/value)[1]', N'varchar(max)'),'No SQL Text for this error'),
		ClientApplication = d.value(N'(/event/action[@name="client_app_name"]/value)[1]',N'varchar(128)'),
		[ERROR_NUMBER] = d.value(N'(/event/data[@name="error_number"]/value)[1]',N'int'),
		[Severity] = d.value(N'(/event/data[@name="severity"]/value)[1]',N'int'),
		[State] = d.value(N'(/event/data[@name="state"]/value)[1]',N'int'),
		[Database_name] = d.value(N'(/event/action[@name="database_name"]/value)[1]', N'varchar(128)')
FROM
(
    SELECT CONVERT(XML, event_data) AS TARGET_DATA
    FROM sys.fn_xe_file_target_read_file('c:\temp\Error_reported*.xel',NULL,NULL,NULL)
) AS x(d)
)
	INSERT INTO db_administration.dbo.SQL_Error_Reported
	(
	    Start_time,
	    Error_Reported,
	    UserName,
	    NTUsername,
	    SQL_Text,
	    ClientApplication,
	    ERROR_NUMBER,
	    Severity,
	    State,
	    Database_name
	)
	SELECT	StartTime,
		Error_Reported,
		UserNAme,
		NTUserNAme,
		SQL_Text,
		ClientApplication,
		[ERROR_NUMBER],
		[Severity],
		[State],
		[Database_name]
	FROM CTE;

SELECT ID,
       Start_time,
       Error_Reported,
       UserName,
       NTUsername,
       SQL_Text,
       ClientApplication,
       ERROR_NUMBER,
       Severity,
       State,
       Database_name 
FROM db_administration.dbo.SQL_Error_Reported;

ALTER EVENT SESSION [error_report] ON SERVER STATE = STOP;
ALTER EVENT SESSION [error_report] ON SERVER STATE = START;

SELECT * FROM sys.messages WHERE text LIKE '%conversion failed%'