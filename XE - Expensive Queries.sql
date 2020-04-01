/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                            Expensive Queries                             */
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
    WHERE name = 'Expensive Queries'
)
BEGIN
    DROP EVENT SESSION [Expensive Queries] ON SERVER;
END;
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
create event session [Expensive Queries] 
on server
add event
	sqlserver.sql_statement_completed
	(
		action	(sqlserver.plan_handle)
		where
		(
			(
				cpu >= 5000000 or -- Time in microseconds
				reads >= 10000 or
				writes >= 10000
			) and
			sqlserver.is_system = 0 
		)
	),
add event
	sqlserver.rpc_completed
	(
		where
		(
			(
				cpu >= 5000000 or
				reads >= 10000 or
				writes >= 10000
			) and
			sqlserver.is_system = 0 
		)
	)
 
add target 
	package0.asynchronous_file_target
	(
		set 
			filename = ''c:\ExtEvents\Expensive Queries.xel''
			,metadatafile = ''c:\ExtEvents\Expensive Queries.xem''
	)
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=30 seconds
	);';
END;
ELSE
BEGIN -- SQL Server 2012+	
    EXEC sp_executesql N'
create event session [Expensive Queries] 
on server
add event
	sqlserver.sql_statement_completed
	(
		action	(sqlserver.plan_handle)
		where
		(
			(
				cpu_time >= 5000000 or -- Time in microseconds
				logical_reads >= 10000 or
				writes >= 10000
			) and
			sqlserver.is_system = 0 
		)
	),
add event
	sqlserver.rpc_completed
	(
		where
		(
			(
				cpu_time >= 5000000 or
				logical_reads >= 10000 or
				writes >= 10000
			) and
			sqlserver.is_system = 0 
		)
	)
 
add target 
	package0.event_file
	(
		set filename = ''c:\ExtEvents\Expensive Queries.xel''
	)
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=30 seconds
	);';
END;
GO

ALTER EVENT SESSION [Expensive Queries] ON SERVER STATE = START;
GO

/*** Examining Session Data ***/
;WITH TargetData (Data, File_Name, File_Offset)
 AS (SELECT CONVERT(XML, event_data) AS Data,
            file_name,
            file_offset
     FROM sys.fn_xe_file_target_read_file(
                                             'c:\extevents\Expensive*.xel',
                                             'c:\extevents\Expensive*.xem', -- Not Required in SQL Server 2012+
                                             NULL,
                                             NULL
                                         ) ),
      EventInfo ([Event], [Event Time], [CPU Time], [Duration], [Logical Reads], [Physical Reads], [Writes], [Rows],
                 [Statement], [PlanHandle], File_Name, File_Offset
                )
 AS (SELECT Data.value('/event[1]/@name', 'sysname') AS [Event],
            Data.value('/event[1]/@timestamp', 'datetime') AS [Event Time],
            Data.value('((/event[1]/data[@name="cpu_time"]/value/text())[1])', 'bigint') AS [CPU Time],
            Data.value('((/event[1]/data[@name="duration"]/value/text())[1])', 'bigint') AS [Duration],
            Data.value('((/event[1]/data[@name="logical_reads"]/value/text())[1])', 'int') AS [Logical Reads],
            Data.value('((/event[1]/data[@name="physical_reads"]/value/text())[1])', 'int') AS [Physical Reads],
            Data.value('((/event[1]/data[@name="writes"]/value/text())[1])', 'int') AS [Writes],
            Data.value('((/event[1]/data[@name="row_count"]/value/text())[1])', 'int') AS [Rows],
            Data.value('((/event[1]/data[@name="statement"]/value/text())[1])', 'nvarchar(max)') AS [Statement],
            Data.value('xs:hexBinary(((/event[1]/action[@name="plan_handle"]/value/text())[1]))', 'varbinary(64)') AS [PlanHandle],
            File_Name,
            File_Offset
     FROM TargetData)
SELECT ei.[Event],
       ei.[Event Time],
       ei.[CPU Time] / 1000 AS [CPU Time (ms)],
       ei.[Duration] / 1000 AS [Duration (ms)],
       ei.[Logical Reads],
       ei.[Physical Reads],
       ei.[Writes],
       ei.[Rows],
       ei.[Statement],
       ei.[PlanHandle],
       ei.File_Name,
       ei.File_Offset,
       qp.query_plan
FROM EventInfo ei
    OUTER APPLY sys.dm_exec_query_plan(ei.PlanHandle) qp;