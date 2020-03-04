USE MASTER;
SET NOCOUNT ON

IF ((SELECT CAST(REPLACE(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)),'.','')AS INT)) >= 13250260) 
	BEGIN
		SELECT 'Server is SQL Server 2016 sp2 or greater and this will work on Standard edition'
	END
ELSE
	BEGIN
		
		RETURN;
	END

DECLARE @filesavelocation nvarchar(max)
DECLARE @guid UNIQUEIDENTIFIER = NEWID()
DECLARE @on_failure nvarchar(20)
DECLARE @auditname nvarchar(100)
DECLARE @databaseauditname nvarchar(100)
DECLARE @Serverauditname NVARCHAR(100)
DECLARE @max_rollover_files nvarchar(10)
DECLARE @maxsize_MB nvarchar(10)
DECLARE @databasename nvarchar(100)
DECLARE @databaseid nvarchar(100)
DECLARE @Filterpredicate nvarchar(max) 
DECLARE @err nvarchar(max)						
DECLARE @QUEUE_DELAY_MS nvarchar(10) 			
DECLARE @Reserve_disk_space nvarchar(3) 		
DECLARE @turnedon nvarchar(10) 					
DECLARE @execute bit 							 
DECLARE @whatif bit 							
DECLARE @addingDBtoExisting bit
----------Fill out this section----------
/* SET YOUR parameters here **************************************************************************************************************
*****************************************************************************************************************************************/
--Server level parameters
SET @filesavelocation = N'C:\temp\'
SET @maxsize_MB = N'1024'
SET @max_rollover_files = N'50'
SET @Reserve_disk_space = N'ON' -- Options: ON, OFF
SET @QUEUE_DELAY_MS = N'1000'-- default of 1000 MS increase if you need more latency
--If you specify a Server audit name already in use, you can apply a second Database level audit to point to it. 
SET @auditname = N'ServerAudit_Tracking' -- Can have multiple database ones point to the same Server level, same predicate is for all
--Options for @on_failure: CONTINUE, FAIL_OPERATION , SHUTDOWN if the requested logged operation cannot be logged what do you want to happen
SET @on_failure = N'Continue' 
--@filterpredicate info: Add additional predicates here for additional users if needing others, we can review.
SET @Filterpredicate = N'Server_principal_name <> ''principal_name'' AND server_principal_name <> ''domain\name'''
SET @turnedon = N'ON' -- Options: ON, OFF
SET @execute = 0 --Options: 0,1 
SET @whatif = 1 --Options: 0,1

--Server level parameters 
--Leave Servername NULL if not adding one. 
SET @Serverauditname = NULL--N'ServerAudit'

--Database level parameters
--Leave Databasename NULL to not add one. 
SET @databasename = N'bginfo'
SET @databaseauditname = @databasename + N'_Audit'
SET @addingDBtoExisting = 0 --Options: 0,1,Set to 1 to add a new database to an existing Server Audit, 0 will just allow for errors and skip

/*****************************************************************************************************************************************
*****************************************************************************************************************************************/

ADDINGsystem:
SET @databaseID = (SELECT database_id FROM sys.databases WHERE name = @databasename)
 
IF EXISTS (SELECT * FROM master.sys.server_audits WHERE name = @serverauditname) 
	BEGIN
	IF @addingDBtoExisting = 1 
	BEGIN 
		GOTO AddingDB
	END	
		SET @err = N'Another Audit already exists with the given name, please change before continuing'
		RAISERROR (@err,16,1) WITH NOWAIT;
		RETURN
	END
ELSE 
BEGIN

DECLARE @cmd nvarchar(max)

SET @cmd = N'CREATE SERVER AUDIT ['+ @auditname + N']
TO FILE 
(	FILEPATH = ''' + @filesavelocation + N'''
	,MAXSIZE = ' + @maxsize_MB + N' MB
	,MAX_ROLLOVER_FILES = ' + @max_rollover_files + N'
	,RESERVE_DISK_SPACE = ' + @Reserve_disk_space + N'
)
WITH
(	QUEUE_DELAY = ' + @QUEUE_DELAY_MS + N'
	,ON_FAILURE = ' + @on_failure + N'
	,AUDIT_GUID = ''' + CONVERT(nvarchar(50), @guid )+ N'''
)
WHERE ([database_id]=(' + @databaseID + N') 
AND ' + @filterpredicate + N')
ALTER SERVER AUDIT [' + @auditname + N'] WITH (STATE = ' + @turnedon + N');'

IF @execute = 1
	BEGIN
		IF @whatif = 1
		BEGIN
			SELECT @cmd
			PRINT @cmd
		END
		EXEC (@cmd)
	ENd
ELSE 
	BEGIN
		SELECT @cmd
		PRINT @cmd
	END

END
AddingServer:
IF @Serverauditname IS NOT NULL 
	BEGIN
		DECLARE @cmd3 NVARCHAR(MAX) 
		SET @cmd3 = N'
		CREATE SERVER AUDIT SPECIFICATION [' + @Serverauditname + N']
		FOR SERVER AUDIT [' + @auditname + N']
		ADD (AUDIT_CHANGE_GROUP),
		ADD (FAILED_LOGIN_GROUP),
		ADD (SUCCESSFUL_LOGIN_GROUP)'
		EXEC (@cmd3)
				IF @execute = 1
			BEGIN
				IF @whatif = 1
				BEGIN
					SELECT @cmd3
					PRINT @cmd3
				END
				EXEC (@cmd3)
			ENd
		ELSE 
			BEGIN
				SELECT @cmd3
				PRINT @cmd3
			END
	END

ADDINGDB:
IF @databaseauditname IS NOT NULL
	BEGIN
		DECLARE @cmd2 nvarchar(max)
		DECLARE @exists nvarchar(100) = 0
		DECLARE @databaseauditname1 nvarchar(100)
		SET @cmd2 = N'SELECT @databaseauditname1 =  MAX(name) FROM ' + @databasename + N'.sys.database_audit_specifications WHERE name = ''' + @databaseauditname + ''';'
		EXEC sp_executesql @cmd2,N'@databaseauditname1 nvarchar(100) OUTPUT', @databaseauditname1 = @exists OUTPUT

		IF @exists IS NOT NULL
			BEGIN
				SET @err = N'Another Database Audit has the same name as ' + @databaseauditname + N' please change it before creating it'
				RAISERROR (@err, 16,1) WITH NOWAIT;
				RETURN
			END
		ELSE

		SET @cmd2 = N'
		USE [' + @databasename + N'];
		CREATE DATABASE AUDIT SPECIFICATION [' + @databaseauditname + N']
		FOR SERVER AUDIT [' + @auditname + N']
		ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
		ADD (AUDIT_CHANGE_GROUP),
		ADD (DATABASE_PERMISSION_CHANGE_GROUP),
		ADD (DATABASE_PRINCIPAL_IMPERSONATION_GROUP),
		ADD (DATABASE_OBJECT_CHANGE_GROUP),
		ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
		ADD (SCHEMA_OBJECT_CHANGE_GROUP),
		ADD (DATABASE_OWNERSHIP_CHANGE_GROUP),
		ADD (USER_CHANGE_PASSWORD_GROUP),
		ADD (UPDATE ON DATABASE::' + @databasename + N' BY [public]),
		ADD (DELETE ON DATABASE::' + @databasename + N' BY [public]),
		ADD (INSERT ON DATABASE::' + @databasename + N' BY [public]),
		ADD (SELECT ON DATABASE::' + @databasename + N' BY [public])
		WITH (STATE = ' + @turnedon + N');'

		IF @execute = 1
			BEGIN
				IF @whatif = 1
				BEGIN
					SELECT @cmd2
					PRINT @cmd2
				END
				EXEC (@cmd2)
			ENd
		ELSE 
			BEGIN
				SELECT @cmd2
				PRINT @cmd2
			END
	END

/*---TSQL that can assist with other functions 

--Turns off Server level Audit specification
ALTER SERVER AUDIT <serverauditName> WITH (STATE = OFF);--Options: ON/OFF

--Turns database specification off, but must be in the context of the database you are turning it off. 
USE <databasename>;
GO
ALTER DATABASE AUDIT SPECIFICATION <Database_Auditname> WITH (STATE=OFF);--Options: ON/OFF

--Query from the Audit file itself. use REgular expressions as needed for file name. 
--I.E. N'C:\temp\database_audit*.*' 
--Ie N'\\fileshare\shared\serveraudit*.sqlaudit' 
SELECT * --
FROM fn_get_audit_file ('<file_location_on_disk>',NULL,NULL)
WHERE 1=1 -- can add additional predicate based on columns output for specific filtering criteria. 

*/