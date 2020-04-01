/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                          Pair_Matching Target                            */
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
    RAISERROR('SQL Server 2008/2008R2 does not support "statement" in the matching columns.', 16, 1) WITH NOWAIT;
    RAISERROR('However, you can work with pair_matching target the same way as it is shown here', 16, 1) WITH NOWAIT;
    SET NOEXEC ON;
END;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'Timeouts')
    DROP EVENT SESSION Timeouts ON SERVER;
GO

CREATE EVENT SESSION [Timeouts]
ON SERVER
    ADD EVENT sqlserver.sql_statement_starting
    (ACTION
     (
         sqlserver.session_id
     )
    ),
    ADD EVENT sqlserver.sql_statement_completed
    (ACTION
     (
         sqlserver.session_id
     )
    )
    ADD TARGET package0.pair_matching
    (SET begin_event = 'sqlserver.sql_statement_starting', begin_matching_columns = 'statement', begin_matching_actions = 'sqlserver.session_id', end_event = 'sqlserver.sql_statement_completed', end_matching_columns = 'statement', end_matching_actions = 'sqlserver.session_id', respond_to_memory_pressure = 0)
WITH
(
    MAX_DISPATCH_LATENCY = 10 SECONDS,
    TRACK_CAUSALITY = ON
);

ALTER EVENT SESSION Timeouts ON SERVER STATE = START;
GO

;WITH TargetData (Data)
 AS (SELECT CONVERT(XML, st.target_data) AS Data
     FROM sys.dm_xe_sessions s
         JOIN sys.dm_xe_session_targets st
             ON s.address = st.event_session_address
     WHERE s.name = 'Timeouts'
           AND st.target_name = 'pair_matching')
SELECT t.e.value('@timestamp', 'datetime') AS [Event Time],
       t.e.value('@name', 'sysname') AS [Event],
       t.e.value('(action[@name="session_id"]/value/text())[1]', 'smallint') AS [SPID],
       t.e.value('(data[@name="statement"]/value/text())[1]', 'nvarchar(max)') AS [SQL]
FROM TargetData
    CROSS APPLY TargetData.DATA.nodes('/PairingTarget/event') AS t(E);
GO
