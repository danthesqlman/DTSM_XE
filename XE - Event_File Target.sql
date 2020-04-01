/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                            Event_File Target                             */
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
          ) < 11 -- SQL Server 2012/2014 is required
BEGIN
    RAISERROR('SQL Server 2008/2008R2 does not support hash_warning/sort_warning events', 16, 1) WITH NOWAIT;
    RAISERROR('However, you can work with asynchronous_file_target target the same way as it is shown here', 16, 1) WITH NOWAIT;
    SET NOEXEC ON;
END;
GO

IF NOT EXISTS
(
    SELECT *
    FROM sys.dm_xe_sessions
    WHERE name = 'TempDB Spills'
)
BEGIN
    RAISERROR('Session [TempDB Spills] is not active', 16, 1) WITH NOWAIT;
    RAISERROR('Create and start session using "02.Monitoring TempDB Spills.sql" script', 16, 1) WITH NOWAIT;
    SET NOEXEC ON;
END;
GO

RAISERROR('You can trigger tempdb spill with Chapter 3 "04.Statistics and Memory Grants.sql" script', 0, 1) WITH NOWAIT;
GO

/*** Obtaining File Name from the target ***/

-- SQL Server 2012/2014: 
DECLARE @dataFile NVARCHAR(260);

-- Get path to event data file 
SELECT @dataFile
    = LEFT(column_value, LEN(column_value) - CHARINDEX('.', REVERSE(column_value))) + N'*.'
      + RIGHT(column_value, CHARINDEX('.', REVERSE(column_value)) - 1)
FROM sys.dm_xe_session_object_columns oc
    JOIN sys.dm_xe_sessions s
        ON oc.event_session_address = s.address
WHERE s.name = 'TempDB Spills'
      AND oc.object_name = 'event_file'
      AND oc.column_name = 'filename';

SELECT @dataFile AS [Data File Path];
GO

-- SQL Server 2008/2008R2: 
DECLARE @dataFile NVARCHAR(512),
        @metaFile NVARCHAR(512);

-- Get path to event data file 
SELECT @dataFile
    = LEFT(column_value, LEN(column_value) - CHARINDEX('.', REVERSE(column_value))) + N'*.'
      + RIGHT(column_value, CHARINDEX('.', REVERSE(column_value)) - 1)
FROM sys.dm_xe_session_object_columns oc
    JOIN sys.dm_xe_sessions s
        ON oc.event_session_address = s.address
WHERE s.name = 'TempDB Spills'
      AND oc.object_name = 'asynchronous_file_target'
      AND oc.column_name = 'filename';

-- Get path to metadata file
SELECT @metaFile
    = LEFT(column_value, LEN(column_value) - CHARINDEX('.', REVERSE(column_value))) + N'*.'
      + RIGHT(column_value, CHARINDEX('.', REVERSE(column_value)) - 1)
FROM sys.dm_xe_session_object_columns oc
    JOIN sys.dm_xe_sessions s
        ON oc.event_session_address = s.address
WHERE s.name = 'TempDB Spills'
      AND oc.object_name = 'asynchronous_file_target'
      AND oc.column_name = 'metadatafile';

IF @metaFile IS NULL
    SELECT @metaFile = LEFT(@dataFile, LEN(@dataFile) - CHARINDEX('*', REVERSE(@dataFile))) + N'*.xem';

SELECT @dataFile AS [Data File Path],
       @metaFile AS [Metadata File Path];
GO

/*** Reading Data from Event_File target ***/
;WITH TargetData (Data, File_Name, File_Offset)
 AS (SELECT CONVERT(XML, event_data) AS Data,
            file_name,
            file_offset
     FROM sys.fn_xe_file_target_read_file(   'c:\extevents\TempDB_Spiils*.xel', -- Data File
                                             NULL,                              -- Metadata File - not required in SQL Server 2012+
                                             NULL,
                                             NULL
                                         ) ),
      EventInfo ([Event Time], [Event], SPID, [SQL], PlanHandle, File_Name, File_Offset)
 AS (SELECT Data.value('/event[1]/@timestamp', 'datetime') AS [Event Time],
            Data.value('/event[1]/@name', 'sysname') AS [Event],
            Data.value('(/event[1]/action[@name="session_id"]/value)[1]', 'smallint') AS [SPID],
            Data.value('(/event[1]/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [SQL],
            Data.value('xs:hexBinary((/event[1]/action[@name="plan_handle"]/value)[1])', 'varbinary(64)') AS [PlanHandle],
            File_Name,
            File_Offset
     FROM TargetData)
SELECT ei.[Event Time],
       ei.File_Name,
       ei.File_Offset,
       ei.[Event],
       ei.SPID,
       ei.SQL,
       qp.query_plan
FROM EventInfo ei
    OUTER APPLY sys.dm_exec_query_plan(ei.PlanHandle) qp;
GO
