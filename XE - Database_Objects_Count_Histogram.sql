IF EXISTS (SELECT 1 
            FROM sys.server_event_sessions 
            WHERE name = 'SQLskills_DatabaseUsage')
    DROP EVENT SESSION [SQLskills_DatabaseUsage] 
    ON SERVER;
 
-- Create the Event Session
CREATE EVENT SESSION [SQLskills_DatabaseUsage] 
ON SERVER 
ADD EVENT sqlserver.lock_acquired( 
    WHERE owner_type = 4 -- SharedXactWorkspace
      AND resource_type = 2 -- Database level lock
      AND database_id > 4 -- non system database
      AND sqlserver.is_system = 0 -- must be a user process
) 
ADD TARGET package0.histogram
( SET slots = 32, -- Adjust based on number of databases in instance
      filtering_event_name='sqlserver.lock_acquired', -- aggregate on the lock_acquired event
      source_type=0, -- event data and not action data
      source='database_id' -- aggregate by the database_id
); -- dispatch immediately and don't wait for full buffers
GO
 
-- Start the Event Session
ALTER EVENT SESSION [SQLskills_DatabaseUsage] 
ON SERVER 
STATE = START;
GO

IF EXISTS (SELECT 1 
            FROM sys.server_event_sessions 
            WHERE name = 'XE_DatabaseUsage_objects')
    DROP EVENT SESSION [XE_DatabaseUsage_objects] 
    ON SERVER;
GO

CREATE EVENT SESSION [XE_DatabaseUsage_objects] ON SERVER 
ADD EVENT sqlserver.lock_acquired(
    WHERE ([package0].[equal_uint64]([resource_type],(5)) 
	AND [package0].[greater_than_uint64]([database_id],(4)) 
	AND [package0].[equal_boolean]([sqlserver].[is_system],(0)) 
	AND [package0].[greater_than_int64]([object_id],(100))))
ADD TARGET package0.histogram(SET filtering_event_name=N'sqlserver.lock_acquired',slots=(1024),source=N'object_id',source_type=(0))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)

GO
ALTER EVENT SESSION [XE_DatabaseUsage_objects] 
ON SERVER 
STATE = START;


 
-- Parse the session data to determine the objects being used.
;WITH cte AS
(
SELECT  slot.value('./@count', 'int') AS [Count] ,
        slot.query('./value').value('.', 'int') AS [Object_id],
		 OBJECT_NAME(slot.query('./value').value('.', 'int')) AS [Object_Name]
FROM
(
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets AS t
    INNER JOIN sys.dm_xe_sessions AS s 
        ON t.event_session_address = s.address
    WHERE   s.name = 'SQLSkills_DatabaseUsage_objects'
      AND t.target_name = 'histogram') AS tgt(target_data)
CROSS APPLY target_data.nodes('/HistogramTarget/Slot') AS bucket(slot)
)
SELECT * FROM cte
GO






;WITH cte AS
(
SELECT  slot.value('./@count', 'int') AS [Count] ,
        DB_NAME(slot.query('./value').value('.', 'int')) AS [Object_id]
FROM
(
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets AS t
    INNER JOIN sys.dm_xe_sessions AS s 
        ON t.event_session_address = s.address
    WHERE   s.name = 'SQLskills_DatabaseUsage'
      AND t.target_name = 'histogram') AS tgt(target_data)
CROSS APPLY target_data.nodes('/HistogramTarget/Slot') AS bucket(slot)
)
SELECT * FROM cte WHERE [Object_id] IS NOT NULL
GO
