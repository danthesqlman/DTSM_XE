/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                          Event_Counter Target                            */
/****************************************************************************/

SET NOEXEC OFF;
GO

IF CONVERT(
              INT,
              LEFT(CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')), CHARINDEX(
                                                                                          '.',
                                                                                          CONVERT(
                                                                                                     NVARCHAR(128),
                                                                                                     SERVERPROPERTY('ProductVersion')
                                                                                                 )
                                                                                      ) - 1)
          ) < 10
BEGIN
    RAISERROR('You should have SQL Server 2008+ to execute this script', 16, 1) WITH NOWAIT;
    SET NOEXEC ON;
END;
GO

IF EXISTS
(
    SELECT *
    FROM sys.server_event_sessions
    WHERE name = 'FileStats'
)
    DROP EVENT SESSION FileStats ON SERVER;
GO


IF CONVERT(
              INT,
              LEFT(CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')), CHARINDEX(
                                                                                          '.',
                                                                                          CONVERT(
                                                                                                     NVARCHAR(128),
                                                                                                     SERVERPROPERTY('ProductVersion')
                                                                                                 )
                                                                                      ) - 1)
          ) = 10 -- SQL Server 2008
BEGIN -- SQL Server 2008	
    EXEC sp_executesql N'
create event session [FileStats] 
on server
add event
	sqlserver.file_read_completed
	(
		where(sqlserver.database_id = 2)
	),
add event
	sqlserver.file_write_completed
	(
		where(sqlserver.database_id = 2)
	)
add target
	package0.synchronous_event_counter
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=5 seconds
	);';
END;
ELSE
BEGIN -- SQL Server 2012+	
    EXEC sp_executesql N'
create event session [FileStats] 
on server
add event
	sqlserver.file_read_completed
	(
		where(sqlserver.database_id = 2)
	),
add event
	sqlserver.file_write_completed
	(
		where(sqlserver.database_id = 2)
	)
add target
	package0.event_counter
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=5 seconds
	);';
END;
GO

ALTER EVENT SESSION [FileStats] ON SERVER STATE = START;
GO

RAISERROR('You can trigger tempdb activity with Chapter 3 "04.Statistics and Memory Grants.sql" script', 0, 1) WITH NOWAIT;
GO

/*** Examining Session Data ***/
DECLARE @TargetName sysname;

SELECT @TargetName
    = CASE
          WHEN CONVERT(
                          INT,
                          LEFT(CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')), CHARINDEX(
                                                                                                      '.',
                                                                                                      CONVERT(
                                                                                                                 NVARCHAR(128),
                                                                                                                 SERVERPROPERTY('ProductVersion')
                                                                                                             )
                                                                                                  ) - 1)
                      ) = 10 THEN
              'synchronous_event_counter'
          ELSE
              'event_counter'
      END;
WITH TargetData (Data)
AS (SELECT CONVERT(XML, st.target_data) AS Data
    FROM sys.dm_xe_sessions s
        JOIN sys.dm_xe_session_targets st
            ON s.address = st.event_session_address
    WHERE s.name = 'FileStats'
          AND st.target_name = @TargetName),
     EventInfo ([Event], [Count])
AS (SELECT t.e.value('@name', 'sysname') AS [Event],
           t.e.value('@count', 'bigint') AS [Count]
    FROM TargetData
        CROSS APPLY TargetData.DATA.nodes('/CounterTarget/Packages/Package[@name="sqlserver"]/Event') AS t(E) )
SELECT [Event],
       [Count]
FROM EventInfo;
GO


