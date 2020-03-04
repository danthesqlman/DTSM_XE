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
               OR [error_number] = (6004)
               OR [error_number] = (15469)
			   OR [error_number] = (15470)
			   OR [error_number] = (15472)
			   OR [error_number] = (15562)
			   OR [error_number] = (15622)
			   OR [error_number] = (3701)
			   OR [error_number] = (15388)
			   OR [error_number] = (229)
			   OR [error_number] = (230)
			   OR [error_number] = (300)
			   OR [error_number] = (2104)
           )
    )
    ADD TARGET package0.event_file
    (SET filename = N'c:\temp\Error_reported') -- change file location here if needed. 
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 300 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
);
GO

ALTER EVENT SESSION [Error_Reported] ON SERVER STATE = START;
GO

