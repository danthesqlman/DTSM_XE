/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                          Creating Event Session                          */
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
    RAISERROR('You should have SQL Server 2012+ to execute this script', 16, 1) WITH NOWAIT;
    RAISERROR('SQL Server 2008/2008R2 does not support hash_warning/sort_warning events', 16, 1) WITH NOWAIT;
    SET NOEXEC ON;
END;
GO

IF EXISTS
(
    SELECT *
    FROM sys.server_event_sessions
    WHERE name = 'TempDB Spills'
)
    DROP EVENT SESSION [TempDB Spills] ON SERVER;
GO

CREATE EVENT SESSION [TempDB Spills]
ON SERVER
    ADD EVENT sqlserver.hash_warning
    (ACTION
     (
         sqlserver.session_id,
         sqlserver.plan_handle,
         sqlserver.sql_text
     )
     WHERE (sqlserver.is_system = 0)
    ),
    ADD EVENT sqlserver.sort_warning
    (ACTION
     (
         sqlserver.session_id,
         sqlserver.plan_handle,
         sqlserver.sql_text
     )
     WHERE (sqlserver.is_system = 0)
    )
    ADD TARGET package0.event_file
    (SET filename = 'c:\ExtEvents\TempDB_Spiils.xel', max_file_size = 25),
    ADD TARGET package0.ring_buffer
    (SET max_memory = 4096)
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 15 SECONDS,
    TRACK_CAUSALITY = OFF,
    MEMORY_PARTITION_MODE = NONE,
    STARTUP_STATE = OFF
);
GO

ALTER EVENT SESSION [TempDB Spills] ON SERVER STATE = START;
GO