/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                            Ring_Buffer Target                            */
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
    RAISERROR('However, you can work with ring_buffer target the same way as it is shown here', 16, 1) WITH NOWAIT;
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

;WITH TargetData (Data)
 AS (SELECT CONVERT(XML, st.target_data) AS Data
     FROM sys.dm_xe_sessions s
         JOIN sys.dm_xe_session_targets st
             ON s.address = st.event_session_address
     WHERE s.name = 'TempDB Spills'
           AND st.target_name = 'ring_buffer'),
      EventInfo ([Event Time], [Event], SPID, [SQL], PlanHandle)
 AS (SELECT t.e.value('@timestamp', 'datetime') AS [Event Time],
            t.e.value('@name', 'sysname') AS [Event],
            t.e.value('(action[@name="session_id"]/value)[1]', 'smallint') AS [SPID],
            t.e.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [SQL],
            t.e.value('xs:hexBinary((action[@name="plan_handle"]/value)[1])', 'varbinary(64)') AS [PlanHandle]
     FROM TargetData
         CROSS APPLY TargetData.DATA.nodes('/RingBufferTarget/event') AS t(E) )
SELECT ei.[Event Time],
       ei.[Event],
       ei.SPID,
       ei.SQL,
       qp.query_plan
FROM EventInfo ei
    OUTER APPLY sys.dm_exec_query_plan(ei.PlanHandle) qp;
GO