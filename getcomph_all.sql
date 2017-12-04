set timing off
set termout off
set serveroutput on
spool getcomph_all_run.sql
declare
  l_tmpl varchar2(1000):= q'[
prompt rem count=<cnt>
prompt define dbid1=<db1>
prompt define start_snap1=<sn1_1>
prompt define end_snap1=<sn1_2>
prompt define dbid2=<db2>
prompt define start_snap2=<sn2_1>
prompt define end_snap2=<sn2_2>
prompt define dblnk=""
prompt define filter="sql_id='<sql_id>'"
prompt define sortcol=ELAPSED_TIME_DELTA
prompt define sortlimit=1e5
prompt define embeded=FALSE]';
  l_cnt number := 0;
begin
  for i in (select dbid, sql_id, min(snap_id) mi, max(snap_id) ma, count(unique plan_hash_value) cnt 
              from dba_hist_sqlstat 
			 where plan_hash_value<>0 
			   and parsing_schema_name <> 'SYS'
			   and action not like 'ORA$%'
               and decode(module, 'performance_info', 0, 1) = 1
               and decode(module, 'MMON_SLAVE', 0, 1) = 1
               and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0			   
             group by dbid, sql_id
            having count(unique plan_hash_value)>1)
  loop
    dbms_output.put_line('spool comp_params.sql');
    dbms_output.put_line(
      replace(
      replace(
      replace(
      replace(
      replace(
      replace(
      replace(
      replace(l_tmpl,'<cnt>',i.cnt)
                    ,'<db1>',i.dbid)
                    ,'<sn1_1>',i.mi)
                    ,'<sn1_2>',i.ma)
                    ,'<db2>',i.dbid)
                    ,'<sn2_1>',i.mi)
                    ,'<sn2_2>',i.ma)
                    ,'<sql_id>',i.sql_id)
    );
    dbms_output.put_line('spool off');
    dbms_output.put_line('@getcomph');
    dbms_output.put_line('host move getcomp.html getcomp_'||i.sql_id||'.html');
    dbms_output.put_line('rem =====================================');
	l_cnt:=l_cnt+1;
  end loop;
  dbms_output.put_line('rem To analyze: '||l_cnt||' queries.');  
end;
/
spool off
set serveroutput off
set timing on
set termout on