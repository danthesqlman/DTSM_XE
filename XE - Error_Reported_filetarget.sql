/*
Error_Reported event

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

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
				OR [error_number] = (855) 	-- 'Hardware memory corruption'
				OR [error_number] = (856) 	-- 'Hardware memory corruption'
				OR [error_number] = (2104)      -- invalid permissions
				OR [error_number] = (3452) 	-- 'Metadata inconsistency in DB. Run DBCC CHECKIDENT'
				OR [error_number] = (3619) 	-- 'Chkpoint failed. No Log space available'
				OR [error_number] = (3701)			
				OR [error_number] = (6004)
				OR [error_number] = (15388)
				OR [error_number] = (15457) -- Sp_configure changes
				OR [error_number] = (15469)
				OR [error_number] = (15470)
				OR [error_number] = (15472)
				OR [error_number] = (15562)
				OR [error_number] = (15622) -- Master key corruption
				OR [error_number] = (17065) 
				OR [error_number] = (17179) -- 'No AWE - LPIM related'
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
    (SET filename = N'Error_reported.xel',max_file_size=(20),max_rollover_files=(5)) -- change file location here if needed. 
WITH
(
    MAX_MEMORY = 8192KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 90 SECONDS,
    MAX_EVENT_SIZE = 8192KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF, /* ON  not needed for this XE as the events aren't needing to know how relate to each other */
    STARTUP_STATE = ON /* OFF  can change to off if you don't want this to start automatically */
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
