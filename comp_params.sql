REM DBID for the first DB, can be only local AWR repository
define dbid1=3781652766
REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
define start_snap1=6086
REM SNAP_ID range for the first DB
define end_snap1=6087
rem ====================================
rem local AWR repository
REM DBID for the second DB
define dbid2=3781652766
REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
define start_snap2=6080
REM SNAP_ID range for the first DB
define end_snap2=6082
rem DB Link for the second DB, can be "" (empty for local DB) or like "@DBAWR1". Remote AWR repository is useful to analyze overlapping ranges from the same DB.
define dblnk="@DBAWR1"
rem ====================================
rem use columns from dba_hist_sqlstat to filter queries
rem define filter="not(nvl(action,'~')='RTE_REFRESH_JOB' or nvl(module,'~')='oracle@devsp095cn.netcracker.com (TNS V1-V3)' or (nvl(ACTION,'~') like 'CA%' and nvl(MODULE,'~')='DBMS_SCHEDULER'))"
define filter="1=1"
rem define filter="sql_id='3tjr5wz29zru8'"
rem ====================================
rem Filters out most lightweight sqls sorting by one of the following: CPU_TIME_DELTA,ELAPSED_TIME_DELTA,BUFFER_GETS_DELTA,EXECUTIONS_DELTA
define sortcol=ELAPSED_TIME_DELTA
rem Limits output
define sortlimit=1e6
rem For standalone usage
define embeded=FALSE
