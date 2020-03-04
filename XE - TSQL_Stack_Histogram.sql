SELECT 
tab2.Handle
,tab2.slotcount
,st.dbid
,st.objectid
,st.number
,st.text
,st.encrypted

FROM
(
SELECT xed.slot_data.value('xs:hexBinary(substring((value/frames/frame/@handle)[1], 3))', 'varbinary(max)') AS [handle],
       xed.slot_data.value('(@count)[1]', 'varchar(256)') AS slotcount
FROM
(
    SELECT CAST(xet.target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets AS xet
        JOIN sys.dm_xe_sessions AS xe
            ON (xe.address = xet.event_session_address)
    WHERE xe.name = 'linkedserverole'
          AND target_name = 'histogram'
) AS t
    CROSS APPLY t.target_data.nodes('//HistogramTarget/Slot') AS xed(slot_data)
)  tab2
	CROSS APPLY sys.dm_exec_sql_text(tab2.handle) AS st


