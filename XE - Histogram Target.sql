/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                            Histogram Target                              */
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

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'DBUsage')
    DROP EVENT SESSION DBUsage ON SERVER;
GO

/*** Examining lock_acquired event data columns ***/
SELECT column_id,
       name,
       type_name
FROM sys.dm_xe_object_columns
WHERE column_type = 'data'
      AND object_name = 'lock_acquired';
GO

/*** Examining lock_resource_type and lock_owner_type maps ***/
SELECT name,
       map_key,
       map_value
FROM sys.dm_xe_map_values
WHERE name = 'lock_resource_type'
ORDER BY map_key;

SELECT name,
       map_key,
       map_value
FROM sys.dm_xe_map_values
WHERE name = 'lock_owner_type'
ORDER BY map_key;
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
create event session DBUsage
on server
add event
	sqlserver.lock_acquired
	(
		where
			database_id > 4 and -- Users DB
			owner_type = 4 and	-- SharedXactWorkspace
			resource_type = 2 and -- DB-level lock
			sqlserver.is_system = 0 
	)
add target 
	package0.asynchronous_bucketizer
	(
		set 
			slots = 32 -- Based on # of DB
			,filtering_event_name = ''sqlserver.lock_acquired''
			,source_type = 0 -- event data column
			,source = ''database_id'' -- grouping column
	)
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=10 seconds
	);';
END;
ELSE
BEGIN -- SQL Server 2012+	
    EXEC sp_executesql N'
create event session DBUsage
on server
add event
	sqlserver.lock_acquired
	(
		where
			database_id > 4 and -- Users DB
			owner_type = 4 and	-- SharedXactWorkspace
			resource_type = 2 and -- DB-level lock
			sqlserver.is_system = 0 
	)
add target 
	package0.histogram
	(
		set 
			slots = 32 -- Based on # of DB
			,filtering_event_name = ''sqlserver.lock_acquired''
			,source_type = 0 -- event data column
			,source = ''database_id'' -- grouping column
	)
with	
	(
		event_retention_mode=allow_single_event_loss
		,max_dispatch_latency=10 seconds
	);';
END;
GO

ALTER EVENT SESSION DBUsage ON SERVER STATE = START;
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
              'asynchronous_bucketizer' -- Need to fix
          ELSE
              'histogram'
      END;
WITH TargetData (Data)
AS (SELECT CONVERT(XML, st.target_data) AS Data
    FROM sys.dm_xe_sessions s
        JOIN sys.dm_xe_session_targets st
            ON s.address = st.event_session_address
    WHERE s.name = 'DBUsage'
          AND st.target_name = @TargetName),
     EventInfo ([Count], [DBID])
AS (SELECT t.e.value('@count', 'int'),
           t.e.value('((./value)/text())[1]', 'smallint')
    FROM TargetData
        CROSS APPLY TargetData.DATA.nodes('/HistogramTarget/Slot') AS t(E) )
SELECT e.dbid,
       d.name,
       e.[Count]
FROM sys.databases d
    LEFT OUTER JOIN EventInfo e
        ON e.DBID = d.database_id
WHERE d.database_id > 4
ORDER BY e.Count;



