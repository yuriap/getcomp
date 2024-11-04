--*****************************************************************************************
-- Parameters
--*****************************************************************************************
define output_file_suff=dcb4bcudadkm3

REM DBID for the first DB, can be only local AWR repository
define dbid1=1108362173
REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
define start_snap1=23527
REM SNAP_ID range for the first DB
define end_snap1=32933
rem ====================================
rem local AWR repository
REM DBID for the second DB
define dbid2=1108362173
REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
define start_snap2=23527
REM SNAP_ID range for the first DB
define end_snap2=32933
rem DB Link for the second DB, can be "" (empty for local DB) or like "@DBAWR1". Remote AWR repository is useful to analyze overlapping ranges from the same DB.
define dblnk=""
rem ====================================
rem use columns from dba_hist_sqlstat to filter queries
rem define filter="not(nvl(action,'~')='RTE_REFRESH_JOB' or nvl(module,'~')='oracle@devsp095cn.netcracker.com (TNS V1-V3)' or (nvl(ACTION,'~') like 'CA%' and nvl(MODULE,'~')='DBMS_SCHEDULER'))"
rem define filter="1=1"
define filter="sql_id='dcb4bcudadkm3'"
rem ====================================
rem Filters out most lightweight sqls sorting by one of the following: CPU_TIME_DELTA,ELAPSED_TIME_DELTA,BUFFER_GETS_DELTA,EXECUTIONS_DELTA
define sortcol=ELAPSED_TIME_DELTA
rem Limits output
define sortlimit=1e4
rem For standalone usage
define embeded=FALSE

--*****************************************************************************************
--End of Parameters
--*****************************************************************************************