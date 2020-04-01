/****************************************************************************/
/*                       Pro SQL Server Internals                           */
/*      APress. 1st Edition. ISBN-13: 978-1430259626 ISBN-10:1430259620     */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      http://aboutsqlserver.com                           */
/*                      dmitri@aboutsqlserver.com                           */
/****************************************************************************/
/*                       Chapter 28. Extended Events                        */
/*                         Extended Events Objects                          */
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

/*** Packages ***/
SELECT dxp.guid,
       dxp.name,
       dxp.description,
       dxp.capabilities,
       dxp.capabilities_desc,
       os.name AS [Module]
FROM sys.dm_xe_packages dxp
    JOIN sys.dm_os_loaded_modules os
        ON dxp.module_address = os.base_address;
GO


/*** Events ***/
SELECT xp.name AS [Package],
       xo.name AS [Event],
       xo.description
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'event'
ORDER BY xp.name,
         xo.name;
GO

/*** Event Columns ***/
SELECT dxoc.column_id,
       dxoc.name,
       dxoc.type_name AS [Data Type],
       dxoc.column_type AS [Column Type],
       dxoc.column_value AS [Value],
       dxoc.description
FROM sys.dm_xe_object_columns dxoc
WHERE dxoc.object_name = 'sql_statement_completed';
GO

/*** Predicates ***/
SELECT xp.name AS [Package],
       xo.name AS [Predicate],
       xo.description
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'pred_source'
ORDER BY xp.name,
         xo.name;
GO

/*** Comparison Functions ***/
SELECT xp.name AS [Package],
       xo.name AS [Comparison Function],
       xo.description
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'pred_compare'
ORDER BY xp.name,
         xo.name;
GO

/*** Actions ***/
SELECT xp.name AS [Package],
       xo.name AS [Action],
       xo.description
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'action'
ORDER BY xp.name,
         xo.name;
GO

/*** Types and Maps ***/
SELECT xo.object_type AS [Object],
       xo.name,
       xo.description,
       xo.type_name,
       xo.type_size
FROM sys.dm_xe_objects xo
WHERE xo.object_type IN ( 'type', 'map' );
GO

/*** Map values ***/
SELECT name,
       map_key,
       map_value
FROM sys.dm_xe_map_values
WHERE name = 'wait_types'
ORDER BY map_key;
GO

/*** Targets ***/
SELECT xp.name AS [Package],
       xo.name AS [Action],
       xo.description,
       xo.capabilities_desc AS [Capabilities]
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'target'
ORDER BY xp.name,
         xo.name;
GO

/*** Target Configuration ***/
SELECT oc.column_id,
       oc.name AS [Column],
       oc.type_name,
       oc.description,
       oc.capabilities_desc AS [Capabilities]
FROM sys.dm_xe_packages xp
    JOIN sys.dm_xe_objects xo
        ON xp.guid = xo.package_guid
    JOIN sys.dm_xe_object_columns oc
        ON xo.package_guid = oc.object_package_guid
           AND xo.name = oc.object_name
WHERE (
          xp.capabilities IS NULL
          OR xp.capabilities & 1 = 0
      )
      AND
      (
          xo.capabilities IS NULL
          OR xo.capabilities & 1 = 0
      )
      AND xo.object_type = 'target'
      AND xo.name IN ( 'event_file' /* SQL Server 2012+ */, 'asynchronous_file_target' /* SQL Server 2008/2008R2 */ )
ORDER BY oc.column_id;
GO