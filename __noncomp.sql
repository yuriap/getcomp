with 
function getstat(p_sql_id varchar2, p_src varchar2) return varchar2 is
  p_disk_reads_delta number;
  p_buffer_gets_delta number;
  p_cpu_time_delta number;
  p_iowait_delta number;
  p_elapsed_time_delta number;
  p_executions_delta number;
  p_plan_hash number;
  l_result varchar2(4000);
  l_fcol number := 15;
begin
  if p_src='DB1' then
    select 
      sum(disk_reads_delta)disk_reads_delta,
      sum(buffer_gets_delta)buffer_gets_delta,
      sum(cpu_time_delta)cpu_time_delta,
      sum(iowait_delta)iowait_delta,
      sum(elapsed_time_delta)elapsed_time_delta,
      sum(executions_delta)executions_delta,
      min(PLAN_HASH_VALUE)
      into p_disk_reads_delta,p_buffer_gets_delta,p_cpu_time_delta,p_iowait_delta,p_elapsed_time_delta,p_executions_delta,p_plan_hash
      --select sql_id,disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat where snap_id between &start_snap1. and &end_snap1. and dbid = &dbid1. and sql_id=p_sql_id and instance_number between 1 and 256
      group by sql_id;
  elsif p_src='DB2' then
    select 
      sum(disk_reads_delta)disk_reads_delta,
      sum(buffer_gets_delta)buffer_gets_delta,
      sum(cpu_time_delta)cpu_time_delta,
      sum(iowait_delta)iowait_delta,
      sum(elapsed_time_delta)elapsed_time_delta,
      sum(executions_delta)executions_delta,
      min(PLAN_HASH_VALUE)
      into p_disk_reads_delta,p_buffer_gets_delta,p_cpu_time_delta,p_iowait_delta,p_elapsed_time_delta,p_executions_delta,p_plan_hash
      --select disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat&dblnk. where snap_id between &start_snap2. and &end_snap2. and dbid = &dbid2. and sql_id=p_sql_id and instance_number between 1 and 256
      group by sql_id;
  else 
    return 'N/A';
  end if;   
  if p_executions_delta=0 then p_executions_delta:=1; end if;
  l_result:=substr('===================================='||chr(10)||
    'ELA (sec):...'||round(p_elapsed_time_delta/1e6,3)               ||'; '||round(p_elapsed_time_delta/p_executions_delta/1e6,3) ||';'||chr(10)||
    'CPU (sec):...'||round(p_cpu_time_delta/1e6,3)                   ||'; '||round(p_cpu_time_delta/p_executions_delta/1e6,3) ||';'||chr(10)||
    'LIO:.........'||to_char(p_buffer_gets_delta,'fm999g999g999g999')||'; '||to_char(round(p_buffer_gets_delta/p_executions_delta),'fm999g999g999g999') ||';'||chr(10)||
    'PIO:.........'||to_char(p_disk_reads_delta,'fm999g999g999g999') ||'; '||to_char(round(p_disk_reads_delta/p_executions_delta),'fm999g999g999g999') ||';'||chr(10)||
    'IO tim (sec):'||round(p_iowait_delta/1e6,3)                     ||'; '||round(p_iowait_delta/p_executions_delta/1e6,3)||';'||chr(10)||
    'EXEC:........'||p_executions_delta||' PLAN: '||p_plan_hash
    ,1,4000);
  return l_result;
end;
function ordr(p_sql_id varchar2) return number is
  l_result number;
  l_pl_hash number;
begin
  begin
    select PLAN_HASH_VALUE into l_pl_hash from (
      select PLAN_HASH_VALUE
        from dba_hist_sqlstat where snap_id between &start_snap1. and &end_snap1. and dbid = &dbid1. and sql_id=p_sql_id and instance_number between 1 and 256
      union
      select PLAN_HASH_VALUE
        from dba_hist_sqlstat&dblnk. where snap_id between &start_snap2. and &end_snap2. and dbid = &dbid2. and sql_id=p_sql_id and instance_number between 1 and 256);
  exception
    when too_many_rows then l_pl_hash:=-1;
  end;
  
  if l_pl_hash > 0 then
    select 
      sum(&sortcol.)
      into l_result
      from (
      select disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat where snap_id between &start_snap1. and &end_snap1. and dbid = &dbid1. and PLAN_HASH_VALUE=l_pl_hash and instance_number between 1 and 256
      union all
      select disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat&dblnk. where snap_id between &start_snap2. and &end_snap2. and dbid = &dbid2. and PLAN_HASH_VALUE=l_pl_hash and instance_number between 1 and 256
      );
  else
    select 
      sum(&sortcol.)
      into l_result
      from (
      select disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat where snap_id between &start_snap1. and &end_snap1. and dbid = &dbid1. and sql_id=p_sql_id and instance_number between 1 and 256
      union all
      select disk_reads_delta,buffer_gets_delta,cpu_time_delta,iowait_delta,elapsed_time_delta,executions_delta
        from dba_hist_sqlstat&dblnk. where snap_id between &start_snap2. and &end_snap2. and dbid = &dbid2. and sql_id=p_sql_id and instance_number between 1 and 256
      );
  end if;     
  return l_result;
end;
db1 as (select unique  
                --'DB1: '||sn.DBID||', '||version || ', ' || host_name || ', ' || platform_name 
                'DB1: '||sn.DBID||', '||version || ', ' || host_name || --', ' || platform_name || 
                ', B:' || to_char(min(sn.BEGIN_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi') ||
                ', E:' || to_char(max(sn.END_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')
                src_name,
                'DB1' srch
    from dba_hist_database_instance i, 
         dba_hist_snapshot sn 
   where i.dbid = sn.dbid 
     and i.startup_time=sn.startup_time
     and sn.dbid = &dbid1.
     and sn.snap_id between &start_snap1. and &end_snap1.
     and sn.instance_number between 1 and 256),
db2 as (select unique 
                --'DB2: '||sn.DBID||', '||version || ', ' || host_name || ', ' || platform_name 
                'DB2: '||sn.DBID||', '||version || ', ' || host_name || --', ' || platform_name || 
                ', B:' || to_char(min(sn.BEGIN_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi') ||
                ', E:' || to_char(max(sn.END_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')
                src_name,
                'DB2' srch
    from dba_hist_database_instance&dblnk. i, 
         dba_hist_snapshot&dblnk. sn 
   where i.dbid = sn.dbid 
     and i.startup_time=sn.startup_time
     and sn.dbid = &dbid2.
     and sn.snap_id between &start_snap2. and &end_snap2.
     and sn.instance_number between 1 and 256)
select unique t.sql_id, src_name, 
       getstat(t.sql_id,srch) stat,
       cast(substr(sql_text, 1, 4000) as varchar2(4000)) txt,
       ordr(t.sql_id) ordrc
  from (select * from dba_hist_sqltext where dbid = &dbid1.
         union all
        select * from dba_hist_sqltext&dblnk.  where dbid = &dbid2.
       ) t,
                         (select db1.src_name, db1.srch, sql_id
                            from (select sql_id
                                    from dba_hist_sqlstat
                                   where &filter.
                                     and snap_id between &start_snap1. and &end_snap1.
                                     and dbid = &dbid1.
                                     and parsing_schema_name <> 'SYS'
                                     and decode(module, 'performance_info', 0, 1) = 1
                                     and decode(module, 'MMON_SLAVE', 0, 1) = 1
                                     and instance_number between 1 and 256
									 and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                                  minus
                                  select sql_id
                                    from dba_hist_sqlstat&dblnk.
                                   where &filter.
                                     and snap_id between &start_snap2. and &end_snap2.
                                     and dbid = &dbid2.
                                     and parsing_schema_name <> 'SYS'
                                     and decode(module, 'performance_info', 0, 1) = 1
                                     and decode(module, 'MMON_SLAVE', 0, 1) = 1
                                     and instance_number between 1 and 256
									 and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
									), db1
                          union all
                          select db2.src_name, db2.srch, sql_id
                            from (select sql_id
                                    from dba_hist_sqlstat&dblnk.
                                   where &filter.
                                     and snap_id between &start_snap2. and &end_snap2.
                                     and dbid = &dbid2.
                                     and parsing_schema_name <> 'SYS'
                                     and decode(module, 'performance_info', 0, 1) = 1
                                     and decode(module, 'MMON_SLAVE', 0, 1) = 1
                                     and instance_number between 1 and 256
									 and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                                  minus
                                  select sql_id
                                    from dba_hist_sqlstat
                                   where &filter.
                                     and snap_id between &start_snap1. and &end_snap1.
                                     and dbid = &dbid1.
                                     and parsing_schema_name <> 'SYS'
                                     and decode(module, 'performance_info', 0, 1) = 1
                                     and decode(module, 'MMON_SLAVE', 0, 1) = 1
                                     and instance_number between 1 and 256
									 and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0), db2) sqls
 where t.sql_id=sqls.sql_id -- and t.dbid in (&dbid1.,&dbid2.)
 order by ordrc desc,4,2
