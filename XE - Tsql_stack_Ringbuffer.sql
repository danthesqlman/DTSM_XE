--Demo 
--and example based on Jonathan Kehayias's Pluralsight course
--https://www.sqlskills.com/blogs/jonathan/category/extended-events/

USE master;
GO
IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME = 'XE_tsql_stack_demo2')
	BEGIN
		DROP DATABASE [XE_tsql_stack_demo2]
	END
CREATE DATABASE XE_tsql_stack_demo2
GO
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'tsql_stack_trace')
	BEGIN
		DROP EVENT SESSION tsql_stack_trace ON server
	END

GO
USE XE_tsql_stack_demo2;
GO
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Table_being_updated')
BEGIN
	CREATE TABLE [dbo].[Table_being_updated](
		[Num_of_updates] [int] NOT NULL,
		[ColumnThatWillBeUpdated] [int]  NOT NULL,
		[ModifiedBY] VARCHAR(100) NOT NULL

	) ON [PRIMARY]
END
GO
INSERT [dbo].[Table_being_updated] ([Num_of_updates], [ColumnThatWillBeUpdated],[ModifiedBY]) VALUES (1, 20,'DBA')
GO		
IF EXISTS(SELECT 1 FROM sys.triggers WHERE name = 'tracing_table_update')
BEGIN
	DROP TRIGGER dbo.tracing_table_update 
END
GO
CREATE TRIGGER [dbo].[tracing_table_update]
ON [dbo].[table_being_updated]
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON
END
	
 
GO
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'TestTable')
BEGIN
	CREATE TABLE [dbo].[TestTable](
		[Testtable_id] [int] IDENTITY(1,1) NOT NULL,
		[TestTable_name] [nchar](10) NOT NULL,
		[InsertedBy] VARCHAR(128) NOT NULL
	 CONSTRAINT [PK_TestTable_Testtable_id] PRIMARY KEY CLUSTERED 
	(
		[Testtable_id] ASC
	)
	)
END
GO

CREATE TRIGGER [dbo].[triggerCausingMysteryUpdate] 
   ON  [dbo].[TestTable] 
   AFTER INSERT
AS 
BEGIN
    SET NOCOUNT ON;

UPDATE [dbo].[Table_being_updated]
   SET [Num_of_updates] = [Num_of_updates]+1
   ,ModifiedBY = CURRENT_USER

END
GO

CREATE PROCEDURE [dbo].[Procedure_demo4]
AS
BEGIN
INSERT INTO [dbo].[TestTable]
           (
           [TestTable_name],[InsertedBy])
     VALUES
           ('Customers',CURRENT_USER)
END

GO

CREATE PROCEDURE [dbo].[Procedure_demo3]
AS
BEGIN

EXEC dbo.[Procedure_demo4] -- comments again
END
GO

CREATE PROCEDURE [dbo].[Procedure_demo2]
AS
BEGIN
EXEC dbo.[Procedure_demo3]--more comments
END
GO

CREATE PROCEDURE [dbo].[Procedure_demo1]
AS
BEGIN
--Adding additional code here. 
SET NOCOUNT ON
EXEC dbo.[Procedure_demo2] -- with some comments

END

GO
--SELECT * FROM dbo.[Table_being_updated]
--SELECT * FROM dbo.[TestTable]
--Working on building what we want Traced
GO

--To begin start running what is above to build what is needed. 
--Using default values for Create Database. Modify if needed




--This Xevent is only saving currently to RINGBUFFER with not good options, mainly setup for this demo. Please review before executing on a PRODUCTION
--System. 
USE [XE_tsql_stack_demo2];
GO
DECLARE @Object_id int
DECLARE @SQL nvarchar(MAX)
SET @Object_id = Object_id('dbo.tracing_table_update')
IF @Object_id IS NOT NULL 
	BEGIN
		SET @SQL = 'CREATE EVENT SESSION Tsql_stack_trace
			ON SERVER 
			ADD EVENT sqlserver.module_start(
				ACTION(sqlserver.tsql_stack)
				WHERE ([object_id]= ' + CAST(@object_id AS NVARCHAR(16))+ ')) 
			ADD TARGET package0.ring_buffer
			WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)'
		
		EXEC sp_executesql @stmt = @sql
		
		ALTER EVENT SESSION Tsql_stack_trace
		ON SERVER
		STATE=START;

	END
	ELSE
		BEGIN
			RAISERROR('Object id is invalid',10,1) WITH NOWAIT;
		END

GO
--Lets run our statement to cause some damage
EXEC dbo.[Procedure_demo1]
--And the data is changed....
--SELECT * FROM dbo.[Table_being_updated]
--SELECT * FROM dbo.[TestTable]
GO
-- What's executing the trigger
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT
	event_id,
	level,
	handle,
	line,
	offset_start,
	offset_end,
	st.dbid,
	st.objectid,
	OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
    SUBSTRING(st.text, (offset_start/2)+1, 
        ((CASE offset_end
          WHEN -1 THEN DATALENGTH(st.text)
         ELSE offset_end
         END - offset_start)/2) + 1) AS stmt

FROM
(
	SELECT 
		tab.event_id,
		frame.value('(@level)[1]', 'int') AS [level],
		frame.value('xs:hexBinary(substring((@handle)[1], 3))', 'varbinary(max)') AS [handle],
		frame.value('(@line)[1]', 'int') AS [line],
		frame.value('(@offsetStart)[1]', 'int') AS [offset_start],
		frame.value('(@offsetEnd)[1]', 'int') AS [offset_end]
	FROM
	(
		SELECT 
			ROW_NUMBER() OVER (ORDER BY XEvent.value('(event/@timestamp)[1]', 'datetime2')) AS event_id,
			XEvent.query('(action[@name="tsql_stack"]/value/frames)[1]') AS [tsql_stack]
		FROM 
		(    -- Cast the target_data to XML 
			SELECT CAST(target_data AS XML) AS TargetData 
			FROM sys.dm_xe_session_targets st 
			JOIN sys.dm_xe_sessions s 
				ON s.address = st.event_session_address 
			WHERE s.name = N'Tsql_stack_trace' 
				AND st.target_name = N'ring_buffer'
		) AS Data 
		-- Split out the Event Nodes 
		CROSS APPLY TargetData.nodes ('RingBufferTarget/event') AS XEventData (XEvent)
	) AS tab 
	CROSS APPLY tsql_stack.nodes ('(frames/frame)') AS stack(frame)
) AS tab2
CROSS APPLY sys.dm_exec_sql_text(tab2.handle) AS st
WHERE tab2.LEVEL >1
GO
