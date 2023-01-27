/*
Error_Reported event

This helps show various events on the system that would show as errors that may or may not cause problems for the system. 
Some can just be fat fingered DBA quries....I mean queries. 

The selection below was started as I was helping find what permissions people were having trouble with...End users don't always know what they need, but this helped to find what was being denied. Later adding the full severity 16+ I was able to leverage to find issues when I would migrate systems, and helping developers with issues. 


*/


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
				OR [error_number] = (229)
				OR [error_number] = (230)
				OR [error_number] = (300)				
				OR [error_number] = (605)  	-- 'Page retrieval failed. Possible corruption'
											-- 'How to troubleshoot Msg 5180 (http://support.microsoft.com/kb/2015747)
				OR [error_number] = (610)  	-- 'Page header invalid. Possible corruption'
				OR [error_number] = (701)  	-- 'Insufficient memory'
											-- 'How to troubleshoot SQL Server error 8645 (http://support.microsoft.com/kb/309256)
				OR [error_number] = (802) 	-- 'No BP memory'
				OR [error_number] = (823) 
				OR [error_number] = (824) 	-- 'IO failure. Possible corruption'
				OR [error_number] = (832) 	-- 'Page checksum error. Possible corruption'
				OR [error_number] = (825) 	-- 'IO transient failure. Possible corruption'
				OR [error_number] = (833) 	-- 'Long IO detected: http://support.microsoft.com/kb/897284'
				OR [error_number] = (845) 
				OR [error_number] = (855) 	-- 'Hardware memory corruption'
				OR [error_number] = (856) 	-- 'Hardware memory corruption'
				OR [error_number] = (1101)
				OR [error_number] = (1105) 
				OR [error_number] = (1121) 	-- 'No disk space available'
				OR [error_number] = (1205) 	-- 'Deadlocked transaction'
				OR [error_number] = (1214) 	-- 'Internal parallelism error'
				OR [error_number] = (2104)
				OR [error_number] = (2508) 	-- 'Catalog views inaccuracies in DB. Run DBCC UPDATEUSAGE'
				OR [error_number] = (2511) 	-- 'Index Keys errors'
				OR [error_number] = (3271) 	-- 'IO nonrecoverable error'
				OR [error_number] = (3452) 	-- 'Metadata inconsistency in DB. Run DBCC CHECKIDENT'
				OR [error_number] = (3619) 	-- 'Chkpoint failed. No Log space available'
				OR [error_number] = (3624) 
				OR [error_number] = (3701)				
				OR [error_number] = (5180) 	-- 'Invalid file ID. Possible corruption: http://support.microsoft.com/kb/2015747'
				OR [error_number] = (5228) 	-- 'Online Index operation errors'
				OR [error_number] = (5229) 	-- 'Online Index operation errors'
				OR [error_number] = (5242) 	-- 'Page structural inconsistency'
				OR [error_number] = (5243) 	-- 'In-memory structural inconsistency'
				OR [error_number] = (5250) 	-- 'Corrupt page. Error cannot be fixed'
				OR [error_number] = (5572) 	-- 'Possible FILESTREAM corruption'
				OR [error_number] = (5901) 	-- 'Chkpoint failed. Possible corruption'
				OR [error_number] = (6004)
				OR [error_number] = (8621) 	-- 'QP stack overflow during optimization. Please simplify the query'
				OR [error_number] = (8642) 	-- 'QP insufficient threads for parallelism'
				OR [error_number] = (8645) 	-- 'Insufficient memory: http://support.microsoft.com/kb/309256'
				OR [error_number] = (8966) 	-- 'Unable to read and latch on a PFS or GAM page'
				OR [error_number] = (9001) 
				OR [error_number] = (9002) 	-- 'Transaction log errors.'
				OR [error_number] = (9003) 
				OR [error_number] = (9004) 
				OR [error_number] = (9002) 	-- 'No Log space available'
				OR [error_number] = (9015) 	-- 'Transaction log errors. Possible corruption'
											-- How to reduce paging of buffer pool memory in the 64-bit version of SQL Server (http://support.microsoft.com/kb/918483)
				OR [error_number] = (9100) 	-- 'Possible index corruption'
											-- How To Diagnose and Correct Errors 17883, 17884, 17887, and 17888 (http://technet.microsoft.com/en-us/library/cc917684.aspx)
				OR [error_number] = (15388)
				OR [error_number] = (15457) -- Sp_configure changes
				OR [error_number] = (15469)
				OR [error_number] = (15470)
				OR [error_number] = (15472)
				OR [error_number] = (15562)
				OR [error_number] = (15622)
				OR [error_number] = (15622) -- Master key corruption
				OR [error_number] = (17065) 
				OR [error_number] = (17066) 
				OR [error_number] = (17067) -- 'System assertion check failed. Possible corruption'
				OR [error_number] = (17130) -- 'No lock memory'
				OR [error_number] = (17179) -- 'No AWE - LPIM related'
				OR [error_number] = (17204) -- 'Error opening file during startup process'
				OR [error_number] = (17207) -- 'Error opening file during startup process'
				OR [error_number] = (17300) -- 'Unable to run new system task'
				OR [error_number] = (17883) -- 'Non-yielding scheduler: http://technet.microsoft.com/en-us/library/cc917684.aspx'
				OR [error_number] = (17884) 
				OR [error_number] = (17887) -- 'IO completion error: http://technet.microsoft.com/en-us/library/cc917684.aspx'
				OR [error_number] = (17888) -- 'Deadlocked scheduler: http://technet.microsoft.com/en-us/library/cc917684.aspx'
				OR [error_number] = (17890) -- 'sqlservr process paged out'
				OR [error_number] = (28036)
				OR [error_number] = (33094) -- Master key corruption
           )
    )
    ADD TARGET package0.event_file
    (SET filename = N'Error_reported.xel') -- change file location here if needed. 
WITH
(
    MAX_MEMORY = 8192KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 5 SECONDS,
    MAX_EVENT_SIZE = 8192KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
);
GO

ALTER EVENT SESSION [Error_Reported] ON SERVER STATE = START;
GO

DECLARE @FileName NVARCHAR(4000)
SELECT @FileName = target_data.value('(EventFileTarget/File/@name)[1]','nvarchar(4000)')
FROM (
	SELECT CAST(target_data AS XML) target_data
	FROM sys.dm_xe_sessions s
		JOIN sys.dm_xe_session_targets t
			ON s.address = t.event_session_address
	WHERE s.name = N'Error_reported'
	) ft
;
WITH CTE AS
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
    SELECT CONVERT(XML, event_data) 
    FROM sys.fn_xe_file_target_read_file(@FileName,NULL,NULL,NULL)
) AS x(d)
)
SELECT * FROM CTE;