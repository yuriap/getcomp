prompt File comp_params.sql has been created in local directory with following content
prompt Specify the following:
spool comp_params.sql

prompt REM DBID for the first DB, can be only local AWR repository
prompt define dbid1=
prompt REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
prompt define start_snap1=
prompt REM SNAP_ID range for the first DB
prompt define end_snap1=
prompt rem ====================================
prompt rem local AWR repository
prompt REM DBID for the second DB
prompt define dbid2=
prompt REM SNAP_ID range for the first DB (the starting snap will be excluded from analysys)
prompt define start_snap2=
prompt REM SNAP_ID range for the first DB
prompt define end_snap2=

prompt rem DB Link for the second DB, can be "" (empty for local DB) or like "@DBAWR1". Remote AWR repository is useful to analyze overlapping ranges from the same DB.
prompt define dblnk=""

prompt rem ====================================
prompt rem use columns from dba_hist_sqlstat to filter queries
prompt define filter="not(nvl(action,'~')='RTE_REFRESH_JOB' or nvl(module,'~')='oracle@devsp095cn.netcracker.com (TNS V1-V3)' or (nvl(ACTION,'~') like 'CA%' and nvl(MODULE,'~')='DBMS_SCHEDULER'))"
prompt rem define filter="1=1"
prompt rem ====================================
prompt rem Filters out most lightweight sqls sorting by one of the following: CPU_TIME_DELTA,ELAPSED_TIME_DELTA,BUFFER_GETS_DELTA,EXECUTIONS_DELTA
prompt define sortcol=ELAPSED_TIME_DELTA
prompt rem Limits output
prompt define sortlimit=1e5
prompt rem For standalone usage
prompt define embeded=FALSE

spool off
prompt Edit file get_comp_parameters.sql and rerun getcomp.sql
pause Press Enter to continue...

