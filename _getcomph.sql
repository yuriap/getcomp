declare
  l_dbid1        number := ~dbid1.;
  l_start_snap1  number := ~start_snap1.+1;
  l_end_snap1    number := ~end_snap1.;
  l_dbid2        number := ~dbid2.;
  l_start_snap2  number := ~start_snap2.+1;
  l_end_snap2    number := ~end_snap2.;
  l_dblink       varchar2(30) := '~dblnk.'; -- example '@somename'
  l_sortcol      varchar2(30) := '~sortcol.';
  l_sortlimit    number := ~sortlimit.;
  l_filter       varchar2(4000) := q'[~filter.]';
  l_embeded      boolean := case when upper('~embeded.')='TRUE' then true else false end;
  
  type t_my_rec is record(
    dbid            number,
    plan_hash_value number,
    src             varchar2(10));
  type t_my_tab_rec is table of t_my_rec index by pls_integer;
  my_rec t_my_tab_rec;  
  type my_arrayofstrings is table of varchar2(1000);
  p1       my_arrayofstrings;
  p2       my_arrayofstrings;
  
  type t_r_db_header is record (
    short_name varchar2(100),
    long_name  varchar2(4000)
  );
  type t_db_header is table of t_r_db_header index by varchar2(10);
  l_db_header t_db_header;
  
  l_single_plan boolean;
  l_all_sqls sys_refcursor;
  l_all_perms sys_refcursor;
  l_sql_id varchar2(30);
  l_next_sql_id varchar2(30);
  l_total  number;
  l_rn     number;
  l_cnt    number;
  l_max_width number;
  i           number;
  l_stat_ln   number := 40;
  r1       varchar2(1000);
  r2       varchar2(1000);
  
  l_text clob;
  l_sql  clob;
  l_css clob:=
q'{
@@awr.css
}';

--^'||q'^

  l_noncomp clob:=
q'{ 
@@__noncomp
}';

--^'||q'^

  l_getqlist  clob:=
q'{
select rownum "#", x.*
  from (select sql_id, sum(&sortcol.) tot_&sortcol., count(unique PLAN_HASH_VALUE) unique_plan_hash
          from (select db2.*
                  from (select sql_id --,CPU_TIME_DELTA,ELAPSED_TIME_DELTA,BUFFER_GETS_DELTA,EXECUTIONS_DELTA
                          from dba_hist_sqlstat
                         where dbid = &dbid1.
                           and snap_id between &start_snap1. and &end_snap1.
                           and parsing_schema_name <> 'SYS'
                           and decode(module, 'performance_info', 0, 1) = 1
                           and decode(module, 'MMON_SLAVE', 0, 1) = 1
                           and &filter.
                           and instance_number between 1 and 256
                           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                        intersect
                        select sql_id --,CPU_TIME_DELTA,ELAPSED_TIME_DELTA,BUFFER_GETS_DELTA,EXECUTIONS_DELTA
                          from dba_hist_sqlstat&dblnk.
                         where dbid = &dbid2.
                           and snap_id between &start_snap2. and &end_snap2.
                           and parsing_schema_name <> 'SYS'
                           and decode(module, 'performance_info', 0, 1) = 1
                           and decode(module, 'MMON_SLAVE', 0, 1) = 1
                           and &filter.
                           and instance_number between 1 and 256
                           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                        ) db1,
                       (select *
                          from dba_hist_sqlstat
                         where dbid = &dbid1. and snap_id between &start_snap1. and &end_snap1.
                           and parsing_schema_name <> 'SYS'
                           and decode(module, 'performance_info', 0, 1) = 1
                           and decode(module, 'MMON_SLAVE', 0, 1) = 1
                           and &filter.
                           and instance_number between 1 and 256
                           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                        union all
                        select *
                          from dba_hist_sqlstat&dblnk.
                         where dbid = &dbid2. and snap_id between &start_snap2. and &end_snap2.
                           and parsing_schema_name <> 'SYS'
                           and decode(module, 'performance_info', 0, 1) = 1
                           and decode(module, 'MMON_SLAVE', 0, 1) = 1
                           and &filter.
                           and instance_number between 1 and 256
                           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                        ) db2
                 where db1.sql_id = db2.sql_id)
         group by sql_id having sum(&sortcol.) > &sortlimit.
         order by tot_&sortcol. desc) x
}';
--^'||q'^
  l_sqlstat_data  clob:=
q'{
select unique 
       src Source,instance_number inst,dbid,snap_id,plan_hash_value plan_hash,PARSING_USER_ID,parsing_schema_name parsing_schema,module,action
     from 
       (
        select 'DB1' src, x.* from dba_hist_sqlstat x 
         where sql_id='&l_sql_id'
           and dbid=&dbid1. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256
           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
        union all
        select 'DB2' src, x.* from dba_hist_sqlstat&dblnk. x
         where sql_id='&l_sql_id'
           and dbid=&dbid2. and snap_id between &start_snap2. and &end_snap2. and instance_number between 1 and 256
           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
       )
     order by dbid,snap_id,instance_number,plan_hash_value,PARSING_USER_ID,module,action
}';
--^'||q'^
  l_ash_data  clob:=
q'{
select unique src source, dbid,snap_id,sql_id,TOP_LEVEL_SQL_ID,sql_plan_hash_value,user_id,program,module,action,client_id,top_call,end_call       
    from 
      (
       select 'DB1' src, x.*,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id) top_call,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=PLSQL_OBJECT_ID and subprogram_id=PLSQL_SUBPROGRAM_ID) end_call     
         from dba_hist_active_sess_history x
        where (sql_id='&l_sql_id' or TOP_LEVEL_SQL_ID='&l_sql_id')
          and (dbid=&dbid1. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256)
          --and rownum<11
       union all
       select 'DB2' src, x.*,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id) top_call,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=PLSQL_OBJECT_ID and subprogram_id=PLSQL_SUBPROGRAM_ID) end_call
         from dba_hist_active_sess_history&dblnk. x
        where (sql_id='&l_sql_id' or TOP_LEVEL_SQL_ID='&l_sql_id')
          and (dbid=&dbid2. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256)
          --and rownum<11
      )
    order by 6,dbid,sql_plan_hash_value,user_id,module,action
}';
--^'||q'^
  l_wait_profile clob :=
q'{
with locals as ( 
                 select x.*, count(1)*10 cntl from (
                 select nvl(wait_class, '_') wait_class, nvl(event, session_state) event
                   from dba_hist_active_sess_history
                  where dbid = &dbid1.
                    and snap_id between &start_snap1. and &end_snap1.
                    and SQL_PLAN_HASH_VALUE=decode(&plan_hash1.,0,SQL_PLAN_HASH_VALUE,&plan_hash1.)
                    and (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id')
                    and instance_number between 1 and 256) x
                  group by wait_class, event),
                  remotes as ( 
                 select x.*, count(1)*10 cntr from (
                 select nvl(wait_class, '_') wait_class, nvl(event, session_state) event
                   from dba_hist_active_sess_history&dblnk.
                  where dbid = &dbid2.
                    and snap_id between &start_snap2. and &end_snap2.
                    and SQL_PLAN_HASH_VALUE=decode(&plan_hash2.,0,SQL_PLAN_HASH_VALUE,&plan_hash2.)
                    and (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id')
                    and instance_number between 1 and 256) x
                  group by wait_class, event)
                 select decode(wait_class,'_','N/A',wait_class) wait_class,event,cntl db1_tim,cntr db2_tim,round(100*(cntr-cntl)/decode(cntr,0,1,cntr),2) delta
                 from locals full outer join remotes using (wait_class,event)
                 order by 1 nulls first,2
}';  
--^'||q'^  
  l_ash_plan clob :=
q'{
with db1 as (select rownum n, x.* from (
select sql_plan_hash_value,sql_plan_line_id,sql_plan_operation,sql_plan_options,nvl(event, 'CPU') ev, count(1) * 10 line
              from dba_hist_active_sess_history
             where (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id') and dbid=&dbid1.
               and instance_number between 1 and 256
               and session_type='FOREGROUND'
               and snap_id between &start_snap1. and &end_snap1.
               and SQL_PLAN_HASH_VALUE=&plan_hash1.
             group by sql_plan_hash_value,
                      sql_plan_line_id,
                      sql_plan_operation,
                      sql_plan_options,
                      nvl(event, 'CPU')
             order by sql_plan_hash_value, sql_plan_line_id nulls first, sql_plan_operation, sql_plan_options, nvl(event, 'CPU'))x),
db2 as (select rownum n, x.* from (
select sql_plan_hash_value,sql_plan_line_id,sql_plan_operation,sql_plan_options,nvl(event, 'CPU') ev, count(1) * 10 line
              from dba_hist_active_sess_history&dblnk.
             where (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id') and dbid=&dbid2.
               and instance_number between 1 and 256
               and session_type='FOREGROUND'
               and snap_id between &start_snap2. and &end_snap2.
               and SQL_PLAN_HASH_VALUE=&plan_hash2.
             group by sql_plan_hash_value,
                      sql_plan_line_id,
                      sql_plan_operation,
                      sql_plan_options,
                      nvl(event, 'CPU')
             order by sql_plan_hash_value, sql_plan_line_id nulls first, sql_plan_operation, sql_plan_options, nvl(event, 'CPU'))x)
select 
  a.sql_plan_hash_value plan_hash_db1,a.sql_plan_line_id line_db1,a.sql_plan_operation op_db1,a.sql_plan_options opt_db1,a.ev event_db1,a.line tim_db1,
  b.sql_plan_hash_value plan_hash_db2,b.sql_plan_line_id line_db2,b.sql_plan_operation op_db2,b.sql_plan_options opt_db2,b.ev event_db2,b.line tim_db2
from db1 a full outer join db2 b on (a.n=b.n)
}';

--^'||q'^

  l_ash_span clob :=
q'{
with db1 as (select rownum n, 'DB1' src, x.* from (
            select to_char(trunc(sample_time, 'hh'),'YYYY-MON-DD HH24') sample_time, round(avg(c)) avg_cnt, max(c) max_cnt
              from (select sample_time,sql_id, count(1) c
                      from dba_hist_active_sess_history
                     where dbid = &dbid1.
                       and instance_number between 1 and 256
                       and session_type='FOREGROUND'
                       and (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id')
                       and snap_id between &start_snap1. and &end_snap1.
                       and SQL_PLAN_HASH_VALUE=decode(&plan_hash1.,0,SQL_PLAN_HASH_VALUE,&plan_hash1.)
                     group by sample_time,sql_id)
             group by trunc(sample_time, 'hh')
             order by 1
             )x),
db2 as (select rownum n, 'DB2' src, x.* from (
            select to_char(trunc(sample_time, 'hh'),'YYYY-MON-DD HH24') sample_time, round(avg(c)) avg_cnt, max(c)max_cnt
              from (select sample_time,sql_id, count(1) c
                      from dba_hist_active_sess_history&dblnk.
                     where dbid = &dbid2.
                       and instance_number between 1 and 256
                       and session_type='FOREGROUND'
                       and (sql_id = '&l_sql_id' or TOP_LEVEL_SQL_ID = '&l_sql_id')
                       and snap_id between &start_snap2. and &end_snap2.
                       and SQL_PLAN_HASH_VALUE=decode(&plan_hash2.,0,SQL_PLAN_HASH_VALUE,&plan_hash2.)
                     group by sample_time,sql_id)
             group by trunc(sample_time, 'hh')
             order by 1)x)
select
   a.src source, a.sample_time "Hour",a.avg_cnt "Avg number of sess",a.max_cnt "Max number of sess",
   b.src source, b.sample_time "Hour",b.avg_cnt "Avg number of sess",b.max_cnt "Max number of sess"
from db1 a full outer join db2 b on (a.n=b.n)
}';
--^'||q'^
  l_sysmetr clob :=
q'{
with a as (select * from dba_hist_sysmetric_history&dblnk. where dbid=&dbid. and snap_id between &start_snap. and &end_snap. and instance_number=&inst_id.)
select * 
from
(select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'SREADTIM' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Average Synchronous Single-Block Read Latency')
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'READS' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Physical Reads Per Sec')
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'WRITES' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Physical Writes Per Sec')   
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'REDO' metric_name1,round(value/1024/1024, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Redo Generated Per Sec')   
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'IOPS' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'I/O Requests per Second') 
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'MBPS' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'I/O Megabytes per Second')  
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'DBCPU' metric_name1,round(value/100, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'CPU Usage Per Sec')  
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'HOSTCPU' metric_name1,round(value/100, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Host CPU Usage Per Sec')    
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'EXECS' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Executions Per Sec')
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'NETW' metric_name1,round(value/1024/1024, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'Network Traffic Volume Per Sec')
union all
select to_char(end_time,'yyyy-mm-dd hh24:mi:ss') end_time, 'CALLS' metric_name1,round(value, 3) val1, metric_unit metric1
  from a
 where metric_name in ( 'User Calls Per Sec')    
) pivot
(max(val1)val,max(metric1)metr for metric_name1 in 
  ('SREADTIM' as SREADTIM, 
   'READS' as READS, 
   'WRITES' WRITES, 
   'REDO' as REDO,
   'IOPS' as IOPS,
   'MBPS' as MBPS,
   'DBCPU' as DBCPU,
   'HOSTCPU' as HOSTCPU,
   'EXECS' as EXECS,
   'NETW' as NETW,
   'CALLS' as CALLS   ))
order by 1,2 desc
}';
--^'||q'^
  cursor c_title1 is
    select 
      DB_NAME, sn.DBID,version,host_name,
      to_char(max(i.STARTUP_TIME)over(),'YYYY/MM/DD HH24:mi:ss')STARTUP_TIME,
      to_char(min(sn.BEGIN_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')BEGIN_INTERVAL_TIME,
      to_char(max(sn.END_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')END_INTERVAL_TIME
     from dba_hist_database_instance i, 
          dba_hist_snapshot sn 
    where i.dbid = sn.dbid 
      and i.startup_time=sn.startup_time
      and sn.dbid = l_dbid1
      and sn.snap_id between l_start_snap1 and l_end_snap1
      and sn.instance_number between 1 and 256;
  r_title1 c_title1%rowtype;
  
  cursor c_title2 is
    select 
      DB_NAME, sn.DBID,version,host_name,
      to_char(max(i.STARTUP_TIME)over(),'YYYY/MM/DD HH24:mi:ss')STARTUP_TIME,
      to_char(min(sn.BEGIN_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')BEGIN_INTERVAL_TIME,
      to_char(max(sn.END_INTERVAL_TIME) over (),'YYYY/MM/DD HH24:mi')END_INTERVAL_TIME
$IF '~dblnk.' is not null $THEN       
     from dba_hist_database_instance~dblnk. i, 
          dba_hist_snapshot~dblnk. sn 
$ELSE   
     from dba_hist_database_instance i, 
          dba_hist_snapshot sn 
$END      
    where i.dbid = sn.dbid 
      and i.startup_time=sn.startup_time
      and sn.dbid = l_dbid2
      and sn.snap_id between l_start_snap2 and l_end_snap2
      and sn.instance_number between 1 and 256;
  r_title2 c_title2%rowtype;      
  
  cursor c_getsqlperm(p_sql_id varchar2) is
    select x.* 
      from (select unique src, dbid, plan_hash_value
              from 
              (select 'DB1' src, x.* from dba_hist_sqlstat x 
                where sql_id=p_sql_id
                  and dbid=l_dbid1 and snap_id between l_start_snap1 and l_end_snap1 and instance_number between 1 and 256
                  and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                union all
               select 'DB2' src, x.* 
$IF '~dblnk.' is not null $THEN   
                 from dba_hist_sqlstat~dblnk. x
$ELSE
                 from dba_hist_sqlstat x
$END                 
                where sql_id=p_sql_id
                  and dbid=l_dbid2 and snap_id between l_start_snap2 and l_end_snap2 and instance_number between 1 and 256
                  and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0)) x
                order by src, dbid, plan_hash_value;
  r_getsqlperm c_getsqlperm%rowtype;
--^'||q'^  
  cursor c_sqlstat1(p_sql_id varchar2, p_plan_hash number, p_dbid number, p_start_snap number, p_end_snap number) is
    select 
        s.sql_id
      , s.plan_hash_value
      , s.dbid
      , sum(s.EXECUTIONS_DELTA) EXECUTIONS_DELTA
      , (round(sum(s.ELAPSED_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as ela_poe
      , (round(sum(s.BUFFER_GETS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as LIO_poe
      , (round(sum(s.CPU_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CPU_poe
      , (round(sum(s.IOWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as IOWAIT_poe
      , (round(sum(s.ccwait_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CCWAIT_poe
      , (round(sum(s.APWAIT_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as APWAIT_poe
      , (round(sum(s.CLWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CLWAIT_poe
      , (round(sum(s.DISK_READS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as reads_poe
      , (round(sum(s.DIRECT_WRITES_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as dwrites_poe
      , (round(sum(s.ROWS_PROCESSED_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as Rows_poe
      , ROUND(sum(ELAPSED_TIME_DELTA)/1000000,3) ELA_DELTA_SEC
      , ROUND(sum(CPU_TIME_DELTA)/1000000,3) CPU_DELTA_SEC
      , ROUND(sum(IOWAIT_DELTA)/1000000,3) IOWAIT_DELTA_SEC
      , ROUND(sum(ccwait_delta)/1000000,3) ccwait_delta_SEC
      , ROUND(sum(APWAIT_delta)/1000000,3) APWAIT_delta_SEC
      , ROUND(sum(CLWAIT_DELTA)/1000000,3) CLWAIT_DELTA_SEC
      ,sum(DISK_READS_DELTA)DISK_READS_DELTA
      ,sum(DIRECT_WRITES_DELTA)DISK_WRITES_DELTA
      ,sum(BUFFER_GETS_DELTA)BUFFER_GETS_DELTA
      ,sum(ROWS_PROCESSED_DELTA)ROWS_PROCESSED_DELTA
      ,sum(PHYSICAL_READ_REQUESTS_DELTA)PHY_READ_REQ_DELTA
      ,sum(PHYSICAL_WRITE_REQUESTS_DELTA)PHY_WRITE_REQ_DELTA
      ,round(sum(BUFFER_GETS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) LIO_PER_ROW
      ,round(sum(DISK_READS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) IO_PER_ROW
      ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, 1,0,1, sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
      ,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
      ,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
    from dba_hist_sqlstat s
    where
        s.sql_id = p_sql_id
    and s.instance_number between 1 and 256
    and s.dbid=p_dbid
    and s.snap_id between p_start_snap and p_end_snap
    and s.plan_hash_value=p_plan_hash
    group by s.dbid,s.plan_hash_value,s.sql_id;
  r_stats1 c_sqlstat1%rowtype;
  
  cursor c_sqlstat2(p_sql_id varchar2, p_plan_hash number, p_dbid number, p_start_snap number, p_end_snap number) is
    select 
        s.sql_id
      , s.plan_hash_value
      , s.dbid
      , sum(s.EXECUTIONS_DELTA) EXECUTIONS_DELTA
      , (round(sum(s.ELAPSED_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as ela_poe
      , (round(sum(s.BUFFER_GETS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as LIO_poe
      , (round(sum(s.CPU_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CPU_poe
      , (round(sum(s.IOWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as IOWAIT_poe
      , (round(sum(s.ccwait_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CCWAIT_poe
      , (round(sum(s.APWAIT_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as APWAIT_poe
      , (round(sum(s.CLWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CLWAIT_poe
      , (round(sum(s.DISK_READS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as reads_poe
      , (round(sum(s.DIRECT_WRITES_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as dwrites_poe
      , (round(sum(s.ROWS_PROCESSED_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as Rows_poe
      , ROUND(sum(ELAPSED_TIME_DELTA)/1000000,3) ELA_DELTA_SEC
      , ROUND(sum(CPU_TIME_DELTA)/1000000,3) CPU_DELTA_SEC
      , ROUND(sum(IOWAIT_DELTA)/1000000,3) IOWAIT_DELTA_SEC
      , ROUND(sum(ccwait_delta)/1000000,3) ccwait_delta_SEC
      , ROUND(sum(APWAIT_delta)/1000000,3) APWAIT_delta_SEC
      , ROUND(sum(CLWAIT_DELTA)/1000000,3) CLWAIT_DELTA_SEC
      ,sum(DISK_READS_DELTA)DISK_READS_DELTA
      ,sum(DIRECT_WRITES_DELTA)DISK_WRITES_DELTA
      ,sum(BUFFER_GETS_DELTA)BUFFER_GETS_DELTA
      ,sum(ROWS_PROCESSED_DELTA)ROWS_PROCESSED_DELTA
      ,sum(PHYSICAL_READ_REQUESTS_DELTA)PHY_READ_REQ_DELTA
      ,sum(PHYSICAL_WRITE_REQUESTS_DELTA)PHY_WRITE_REQ_DELTA
      ,round(sum(BUFFER_GETS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) LIO_PER_ROW
      ,round(sum(DISK_READS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) IO_PER_ROW
      ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, 1,0,1, sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
      ,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
      ,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
$IF '~dblnk.' is not null $THEN   
    from dba_hist_sqlstat~dblnk. s
$ELSE
    from dba_hist_sqlstat s
$END    
    where
        s.sql_id = p_sql_id
    and s.instance_number between 1 and 256
    and s.dbid=p_dbid
    and s.snap_id between p_start_snap and p_end_snap
    and s.plan_hash_value=p_plan_hash
    group by s.dbid,s.plan_hash_value,s.sql_id;
  r_stats2 c_sqlstat2%rowtype; 

  type t_sqls is table of varchar2(100) index by pls_integer;
  l_sqls t_sqls;
  
--^'||q'^
  
@@__procs
--^'||q'^  
  procedure pr1(p_msg varchar2) is begin l_text:=l_text||p_msg||chr(10); end;
  procedure pr(length1 number,length2 number, par1 varchar2, par2 varchar2, par3 varchar2 default null) 
  is 
    --length1 number := 50;
    --length2 number := 50;
    delim1 varchar2(10) := '*';
    delim2 varchar2(10) := '';
  begin 
    pr1(rpad(par1, length1, ' ') || delim1 ||rpad(par2, length2, ' ')|| delim2 ||rpad(par3, length1, ' '));
  end;  
  
  procedure get_sql_stat(p_src varchar2, p_sql_id varchar2, p_plan_hash number, p_dbid number, p_start_snap number, p_end_snap number, p_data in out c_sqlstat1%rowtype)
  is
  begin
    if p_src='DB1' then
      open c_sqlstat1(p_sql_id,p_plan_hash,p_dbid,p_start_snap,p_end_snap);
      fetch c_sqlstat1 into p_data;
      close c_sqlstat1;
    elsif p_src='DB2' then
      open c_sqlstat2(p_sql_id,p_plan_hash,p_dbid,p_start_snap,p_end_snap);
      fetch c_sqlstat2 into p_data;
      close c_sqlstat2;  
    end if;
  end;
  
  procedure get_plan(p_src varchar2, p_sql_id varchar2, p_plan_hash varchar2, p_dbid number, p_data in out my_arrayofstrings)
  is
  begin
    if p_src='DB1' then 
      select replace(replace(plan_table_output,chr(13)),chr(10)) bulk collect
        into p_data
        from table(dbms_xplan.display_awr(p_sql_id, p_plan_hash, p_dbid, 'ADVANCED -ALIAS'));--, con_id => 0));
    end if;
    if p_src='DB2' then  
$IF '~dblnk.' is not null $THEN
      remote_awr_xplan_init~dblnk.(p_sql_id, p_plan_hash, p_dbid);
      select replace(replace(plan_table_output,chr(13)),chr(10)) bulk collect
        into p_data
        from remote_awr_plan~dblnk.;    
$ELSE
      select replace(replace(plan_table_output,chr(13)),chr(10)) bulk collect
        into p_data
        from table(dbms_xplan.display_awr(p_sql_id, p_plan_hash, p_dbid, 'ADVANCED -ALIAS'));--, con_id => 0));
$END
    end if;
  end;
--^'||q'^
procedure prepare_script_comp(p_script in out clob) is 
  l_scr clob := p_script;
  l_line varchar2(32765);
  l_eof number;
  l_iter number := 1;
begin
  l_scr:=l_scr||chr(10);
  --set variable
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dbid1.',l_dbid1),'&dbid1',l_dbid1),'&start_snap1.',l_start_snap1),'&start_snap1',l_start_snap1),'&end_snap1.',l_end_snap1),'&end_snap1',l_end_snap1); 
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dbid2.',l_dbid2),'&dbid2',l_dbid2),'&start_snap2.',l_start_snap2),'&start_snap2',l_start_snap2),'&end_snap2.',l_end_snap2),'&end_snap2',l_end_snap2); 
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dblnk.',l_dblink),'&dblnk',l_dblink),'&sortcol.',l_sortcol),'&sortcol',l_sortcol),'&sortlimit.',l_sortlimit),'&sortlimit',l_sortlimit); 
  p_script:=replace(replace(p_script,'&filter.',l_filter),'&filter',l_filter); 
--  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&.',),'&',),'&.',),'&',),'&.',''),'&',''); 

  --if not p_plsql then p_script:=replace(p_script,';'); end if;
end;
begin

--^'||q'^

if not l_embeded then 
   p(HTF.HTMLOPEN);
   p(HTF.HEADOPEN);
   p(HTF.TITLE('AWR SQL comparison report'));   

   p('<style type="text/css">');
   p(l_css);
   p('</style>');
   p(HTF.HEADCLOSE);
   p(HTF.BODYOPEN(cattributes=>'class="awr"'));
end if;
   
   p(HTF.header (1,'AWR SQL comparison report',cattributes=>'class="awr"'));
   p(HTF.BR);
   p(HTF.BR);
   p(HTF.header (2,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Table of contents',cname=>'tblofcont',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#parameters',ctext=>'Parameters',cattributes=>'class="awr"')));
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#db_desc',ctext=>'Databases description',cattributes=>'class="awr"')));
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_list',ctext=>'SQL list',cattributes=>'class="awr"')));
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr',ctext=>'System metrics',cattributes=>'class="awr"')));
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#noncomp',ctext=>'Non-comparable queries',cattributes=>'class="awr"')));

   p(HTF.BR);
   p(HTF.BR); 
  

   p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Parameters',cname=>'parameters',cattributes=>'class="awr"'),cattributes=>'class="awr"'));   
   l_text:='Report input parameters:'||chr(10);
   l_text:=l_text||'DB1: DBID: '||l_dbid1||'; snap_id between '||(l_start_snap1-1)||' and '||l_end_snap1||chr(10);
   l_text:=l_text||'DB2: DBID: '||l_dbid2||'; snap_id between '||(l_start_snap2-1)||' and '||l_end_snap2||chr(10);
   l_text:=l_text||'DB Link: <'||l_dblink||'>'||chr(10);
   l_text:=l_text||'Sort column: '||l_sortcol||chr(10);
   l_text:=l_text||'Limit: '||l_sortlimit||chr(10);
   l_text:=l_text||'Filter: '||l_filter||chr(10);
   
   print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>400);
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
   p(HTF.BR);
   p(HTF.BR); 
--^'||q'^
   open c_title1;
   fetch c_title1 into r_title1;
   close c_title1;
   open c_title2;
   fetch c_title2 into r_title2;
   close c_title2;
   
   l_db_header('DB1').short_name:=r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Snaps: '||(l_start_snap1-1)||'; '||l_end_snap1;
   l_db_header('DB1').long_name :='DB name: '||r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Host:'||r_title1.host_name||'; Ver:'||r_title1.version||'; Snaps: '||(l_start_snap1-1)||':'||r_title1.BEGIN_INTERVAL_TIME||'; '||l_end_snap1||':'||r_title1.END_INTERVAL_TIME||'; Started: '||r_title1.STARTUP_TIME;
   l_db_header('DB2').short_name:=r_title2.DB_NAME||' DBID:'||r_title2.DBID||'; Snaps: '||(l_start_snap2-1)||'; '||l_end_snap2;
   l_db_header('DB2').long_name :='DB name: '||r_title2.DB_NAME||' DBID:'||r_title2.DBID||'; Host:'||r_title2.host_name||'; Ver:'||r_title2.version||'; Snaps: '||(l_start_snap2-1)||':'||r_title2.BEGIN_INTERVAL_TIME||'; '||l_end_snap2||':'||r_title2.END_INTERVAL_TIME||'; Started: '||r_title2.STARTUP_TIME;

   p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Databases description',cname=>'db_desc',cattributes=>'class="awr"'),cattributes=>'class="awr"'));   
   l_text:='Description:'||chr(10);
   l_text:=l_text||'DB1:'||chr(10);
   l_text:=l_text||'--------------------------------------------------------------------------------------------------------------------------------------------------------------------------'||chr(10);
   l_text:=l_text||l_db_header('DB1').long_name||chr(10);
   l_text:=l_text||'==========================================================================================================================================================================='||chr(10);
   l_text:=l_text||'DB2:'||chr(10);
   l_text:=l_text||'---------------------------------------------------------------------------------------------------------------------------------------------------------------------------'||chr(10);
   l_text:=l_text||l_db_header('DB2').long_name||chr(10);
   l_text:=l_text||'==========================================================================================================================================================================='||chr(10);
   
   print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>400);
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
   p(HTF.BR);
   p(HTF.BR);    
   
   --SQL list
   p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'SQL list',cname=>'sql_list',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR);
   prepare_script_comp(l_getqlist);
   --p(l_getqlist);
   print_table_html(l_getqlist,600,'SQL list',p_search=>'SQL_ID',p_replacement=>HTF.ANCHOR (curl=>'#sql_\1',ctext=>'\1',cattributes=>'class="awr1"'));
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
   p(HTF.BR);
   p(HTF.BR);     
--^'||q'^
   
   --getting sqls list
   open l_all_sqls for l_getqlist;
   <<query_list_creating>>
   loop
     fetch l_all_sqls into l_rn, l_sql_id, l_total, l_cnt; --l_total, l_cnt is not used so far
     exit when l_all_sqls%notfound;   
     l_sqls(l_rn):=l_sql_id;
   end loop query_list_creating;
   close l_all_sqls;
   
   --loop through all sqls
   --open l_all_sqls for l_getqlist;
   
   <<query_list_loop>>
   for n in 1..l_sqls.count
   loop
     --fetch l_all_sqls into l_rn, l_sql_id, l_total;
     --exit when l_all_sqls%notfound;
     
     l_rn:=n;
     l_sql_id:=l_sqls(l_rn);
     
     if l_sqls.exists(l_rn+1) then l_next_sql_id:=l_sqls(l_rn+1); else l_next_sql_id:=null; end if;
     
     --get list of all plans
     my_rec.delete;
     l_cnt:=1;
     open c_getsqlperm(l_sql_id);
     loop
       fetch c_getsqlperm into my_rec(l_cnt).src, my_rec(l_cnt).dbid, my_rec(l_cnt).plan_hash_value;
       exit when c_getsqlperm%notfound;
       --p(my_rec(l_cnt).src||';'||my_rec(l_cnt).dbid||';'||my_rec(l_cnt).plan_hash_value);
       l_cnt:=l_cnt+1;     
     end loop;
     close c_getsqlperm;
     
     p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'#'||l_rn||' Comparison of '||l_sql_id,cname=>'sql_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
     p(HTF.BR);
     p(HTF.BR); 
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sqlst_'||l_sql_id,ctext=>'SQL stat data',cattributes=>'class="awr"')));
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_'||l_sql_id,ctext=>'ASH data',cattributes=>'class="awr"')));
     p(HTF.BR); 
     p(HTF.BR); 
     --loop through all pairs ofplans to compare     
      <<comp_outer>>
     for a in 1 .. my_rec.count 
     loop
       <<comp_inner>>
       for b in (case when my_rec.count=1 then 1 else a + 1 end) .. my_rec.count 
       loop  
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Comparison: '||my_rec(a).src||': '||l_db_header(my_rec(a).src).short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with '||my_rec(b).src||': '||l_db_header(my_rec(b).src).short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cattributes=>'class="awr"')));
       end loop comp_inner;
     end loop comp_outer;      
--^'||q'^     
     p(HTF.BR); 
     p(HTF.BR); 
     if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
     p(HTF.BR);
     p(HTF.BR);  

     p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' SQL stat data for '||l_sql_id,cname=>'sqlst_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
     p(HTF.BR);
     l_sql := replace(l_sqlstat_data,'&l_sql_id',l_sql_id);
     prepare_script_comp(l_sql);
     print_table_html(l_sql,1500,'SQL stat data',p_style1 =>'awrncbbt',p_style2 =>'awrcbbt');
     p(HTF.BR);
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
     if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
     p(HTF.BR);
     p(HTF.BR);  
     p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' ASH data for '||l_sql_id,cname=>'ash_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
     p(HTF.BR);
     l_sql := replace(l_ash_data,'&l_sql_id',l_sql_id);
     prepare_script_comp(l_sql);
     print_table_html(l_sql,1500,'ASH data',p_style1 =>'awrncbbt',p_style2 =>'awrcbbt');
     p(HTF.BR);  
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
     p(HTF.BR);
     if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
     p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
     p(HTF.BR);
     p(HTF.BR); 
     
--^'||q'^
     
     --loop through all pairs ofplans to compare     
      <<comp_outer>>
     for a in 1 .. my_rec.count 
     loop
       <<comp_inner>>
       for b in (case when my_rec.count=1 then 1 else a + 1 end) .. my_rec.count 
       loop
         l_max_width:=0;
         --p('Now comparing: '||l_db_header('DB1').short_name||';'||my_rec(a).plan_hash_value||' with '||l_db_header('DB2').short_name||';'||my_rec(b).plan_hash_value);p(HTF.BR);

         p(HTF.header (5,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Now comparing: '||my_rec(a).src||': '||l_db_header(my_rec(a).src).short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with '||my_rec(b).src||': '||l_db_header(my_rec(b).src).short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cname=>'cmp_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR); 
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#stat_'||a||'_'||b||'_'||l_sql_id,ctext=>'Statistics comparison',cattributes=>'class="awr"')));
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#wait_'||a||'_'||b||'_'||l_sql_id,ctext=>'Wait profile',cattributes=>'class="awr"')));
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_plan_'||a||'_'||b||'_'||l_sql_id,ctext=>'ASH plan statistics',cattributes=>'class="awr"')));
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_span_'||a||'_'||b||'_'||l_sql_id,ctext=>'ASH time span',cattributes=>'class="awr"')));
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#pl_'||a||'_'||b||'_'||l_sql_id,ctext=>'Plans comparison',cattributes=>'class="awr"')));
         p(HTF.BR); 
         p(HTF.BR); 
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR); 
         p(HTF.BR); 
         --load stats
         get_sql_stat(my_rec(a).src,l_sql_id,my_rec(a).plan_hash_value,my_rec(a).dbid,l_start_snap1,l_end_snap1,r_stats1);
         get_sql_stat(my_rec(b).src,l_sql_id,my_rec(b).plan_hash_value,my_rec(b).dbid,l_start_snap2,l_end_snap2,r_stats2);       
         
         --load plans
         get_plan(my_rec(a).src,l_sql_id, my_rec(a).plan_hash_value, my_rec(a).dbid,p1);
--^'||q'^         
         l_single_plan := true;
         if a<>b and my_rec(a).plan_hash_value<>my_rec(b).plan_hash_value and my_rec(a).plan_hash_value<>0 and my_rec(b).plan_hash_value<>0 then
           l_single_plan := false;
           get_plan(my_rec(b).src,l_sql_id, my_rec(b).plan_hash_value, my_rec(b).dbid,p2);
           --couple of plans, width
           i := greatest(p1.count, p2.count);
           for j in 1 .. p1.count loop
             if length(p1(j)) > l_max_width then
               l_max_width := length(p1(j));
             end if;
           end loop;
           for j in 1 .. p2.count loop
             if length(p2(j)) > l_max_width then
               l_max_width := length(p2(j));
             end if;
           end loop;           
         else
           --single plan, width
           i := p1.count;
           for j in 1 .. p1.count loop
             if length(p1(j)) > l_max_width then
               l_max_width := length(p1(j));
             end if;
           end loop;
           --l_max_width:=ceil(l_max_width/2);
         end if;
         
         if l_max_width < 50 then l_max_width:= 50; end if;
--^'; l_script1 clob := q'^         
         l_text:=null;   
         pr(l_max_width,l_stat_ln,'Metric             Value',                          'Metric             Value',    'Delta, %            Delta to ELA/EXEC, %');
         pr(l_max_width,l_stat_ln,'EXECS:             '||r_stats1.EXECUTIONS_DELTA,    'EXECS:             '||r_stats2.EXECUTIONS_DELTA,    round(100*((r_stats2.EXECUTIONS_DELTA-r_stats1.EXECUTIONS_DELTA)        /(case when r_stats2.EXECUTIONS_DELTA=0 then case when r_stats1.EXECUTIONS_DELTA=0 then 1 else r_stats1.EXECUTIONS_DELTA end else r_stats2.EXECUTIONS_DELTA end)),2)||'%');
         pr(l_max_width,l_stat_ln,'ELA/EXEC(MS):      '||r_stats1.ela_poe,             'ELA/EXEC(MS):      '||r_stats2.ela_poe,             round(100*((r_stats2.ela_poe-r_stats1.ela_poe)                          /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'LIO/EXEC:          '||r_stats1.LIO_poe,             'LIO/EXEC:          '||r_stats2.LIO_poe,             round(100*((r_stats2.LIO_poe-r_stats1.LIO_poe)                          /(case when r_stats2.LIO_poe=0 then case when r_stats1.LIO_poe=0 then 1 else r_stats1.LIO_poe end else r_stats2.LIO_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CPU/EXEC(MS):      '||r_stats1.CPU_poe,             'CPU/EXEC(MS):      '||r_stats2.CPU_poe,             rpad(round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                     /(case when r_stats2.CPU_poe=0 then case when r_stats1.CPU_poe=0 then 1 else r_stats1.CPU_poe end else r_stats2.CPU_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                          /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'IOWAIT/EXEC(MS):   '||r_stats1.IOWAIT_poe,          'IOWAIT/EXEC(MS):   '||r_stats2.IOWAIT_poe,          rpad(round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)               /(case when r_stats2.IOWAIT_poe=0 then case when r_stats1.IOWAIT_poe=0 then 1 else r_stats1.IOWAIT_poe end else r_stats2.IOWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)                    /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CCWAIT/EXEC(MS):   '||r_stats1.CCWAIT_poe,          'CCWAIT/EXEC(MS):   '||r_stats2.CCWAIT_poe,          rpad(round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)               /(case when r_stats2.CCWAIT_poe=0 then case when r_stats1.CCWAIT_poe=0 then 1 else r_stats1.CCWAIT_poe end else r_stats2.CCWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)                    /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'APWAIT/EXEC(MS):   '||r_stats1.APWAIT_poe,          'APWAIT/EXEC(MS):   '||r_stats2.APWAIT_poe,          rpad(round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)               /(case when r_stats2.APWAIT_poe=0 then case when r_stats1.APWAIT_poe=0 then 1 else r_stats1.APWAIT_poe end else r_stats2.APWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)                    /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CLWAIT/EXEC(MS):   '||r_stats1.CLWAIT_poe,          'CLWAIT/EXEC(MS):   '||r_stats2.CLWAIT_poe,          rpad(round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)               /(case when r_stats2.CLWAIT_poe=0 then case when r_stats1.CLWAIT_poe=0 then 1 else r_stats1.CLWAIT_poe end else r_stats2.CLWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)                    /(case when r_stats2.ela_poe=0 then case when r_stats1.ela_poe=0 then 1 else r_stats1.ela_poe end else r_stats2.ela_poe end)),2)||'%');
         
         pr(l_max_width,l_stat_ln,'READS/EXEC:        '||r_stats1.reads_poe,           'READS/EXEC:        '||r_stats2.reads_poe,           round(100*((r_stats2.reads_poe-r_stats1.reads_poe)                      /(case when r_stats2.reads_poe=0 then case when r_stats1.reads_poe=0 then 1 else r_stats1.reads_poe end else r_stats2.reads_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'WRITES/EXEC:       '||r_stats1.dwrites_poe,         'WRITES/EXEC:       '||r_stats2.dwrites_poe,         round(100*((r_stats2.dwrites_poe-r_stats1.dwrites_poe)                  /(case when r_stats2.dwrites_poe=0 then case when r_stats1.dwrites_poe=0 then 1 else r_stats1.dwrites_poe end else r_stats2.dwrites_poe end)),2)||'%');      
         
         pr(l_max_width,l_stat_ln,'ROWS/EXEC:         '||r_stats1.Rows_poe,            'ROWS/EXEC:         '||r_stats2.Rows_poe,            round(100*((r_stats2.Rows_poe-r_stats1.Rows_poe)                        /(case when r_stats2.Rows_poe=0 then case when r_stats1.Rows_poe=0 then 1 else r_stats1.Rows_poe end else r_stats2.Rows_poe end)),2)||'%');
         pr(l_max_width,l_stat_ln,'ELA(SEC):          '||r_stats1.ELA_DELTA_SEC,       'ELA(SEC):          '||r_stats2.ELA_DELTA_SEC,       round(100*((r_stats2.ELA_DELTA_SEC-r_stats1.ELA_DELTA_SEC)              /(case when r_stats2.ELA_DELTA_SEC=0 then case when r_stats1.ELA_DELTA_SEC=0 then 1 else r_stats1.ELA_DELTA_SEC end else r_stats2.ELA_DELTA_SEC end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CPU(SEC):          '||r_stats1.CPU_DELTA_SEC,       'CPU(SEC):          '||r_stats2.CPU_DELTA_SEC,       round(100*((r_stats2.CPU_DELTA_SEC-r_stats1.CPU_DELTA_SEC)              /(case when r_stats2.CPU_DELTA_SEC=0 then case when r_stats1.CPU_DELTA_SEC=0 then 1 else r_stats1.CPU_DELTA_SEC end else r_stats2.CPU_DELTA_SEC end)),2)||'%');
   
         pr(l_max_width,l_stat_ln,'IOWAIT(SEC):       '||r_stats1.IOWAIT_DELTA_SEC,    'IOWAIT(SEC):       '||r_stats2.IOWAIT_DELTA_SEC,    round(100*((r_stats2.IOWAIT_DELTA_SEC-r_stats1.IOWAIT_DELTA_SEC)        /(case when r_stats2.IOWAIT_DELTA_SEC=0 then case when r_stats1.IOWAIT_DELTA_SEC=0 then 1 else r_stats1.IOWAIT_DELTA_SEC end else r_stats2.IOWAIT_DELTA_SEC end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CCWAIT(SEC):       '||r_stats1.CCWAIT_DELTA_SEC,    'CCWAIT(SEC):       '||r_stats2.CCWAIT_DELTA_SEC,    round(100*((r_stats2.CCWAIT_DELTA_SEC-r_stats1.CCWAIT_DELTA_SEC)        /(case when r_stats2.CCWAIT_DELTA_SEC=0 then case when r_stats1.CCWAIT_DELTA_SEC=0 then 1 else r_stats1.CCWAIT_DELTA_SEC end else r_stats2.CCWAIT_DELTA_SEC end)),2)||'%');
         pr(l_max_width,l_stat_ln,'APWAIT(SEC):       '||r_stats1.APWAIT_DELTA_SEC,    'APWAIT(SEC):       '||r_stats2.APWAIT_DELTA_SEC,    round(100*((r_stats2.APWAIT_DELTA_SEC-r_stats1.APWAIT_DELTA_SEC)        /(case when r_stats2.APWAIT_DELTA_SEC=0 then case when r_stats1.APWAIT_DELTA_SEC=0 then 1 else r_stats1.APWAIT_DELTA_SEC end else r_stats2.APWAIT_DELTA_SEC end)),2)||'%');
         pr(l_max_width,l_stat_ln,'CLWAIT(SEC):       '||r_stats1.CLWAIT_DELTA_SEC,    'CLWAIT(SEC):       '||r_stats2.CLWAIT_DELTA_SEC,    round(100*((r_stats2.CLWAIT_DELTA_SEC-r_stats1.CLWAIT_DELTA_SEC)        /(case when r_stats2.CLWAIT_DELTA_SEC=0 then case when r_stats1.CLWAIT_DELTA_SEC=0 then 1 else r_stats1.CLWAIT_DELTA_SEC end else r_stats2.CLWAIT_DELTA_SEC end)),2)||'%');
         
         pr(l_max_width,l_stat_ln,'READS:             '||r_stats1.DISK_READS_DELTA,    'READS:             '||r_stats2.DISK_READS_DELTA,    round(100*((r_stats2.DISK_READS_DELTA-r_stats1.DISK_READS_DELTA)        /(case when r_stats2.DISK_READS_DELTA=0 then case when r_stats1.DISK_READS_DELTA=0 then 1 else r_stats1.DISK_READS_DELTA end else r_stats2.DISK_READS_DELTA end)),2)||'%');
         pr(l_max_width,l_stat_ln,'DIR WRITES:        '||r_stats1.DISK_WRITES_DELTA,   'DIR WRITES:        '||r_stats2.DISK_WRITES_DELTA,   round(100*((r_stats2.DISK_WRITES_DELTA-r_stats1.DISK_WRITES_DELTA)      /(case when r_stats2.DISK_WRITES_DELTA=0 then case when r_stats1.DISK_WRITES_DELTA=0 then 1 else r_stats1.DISK_WRITES_DELTA end else r_stats2.DISK_WRITES_DELTA end)),2)||'%');      
   
         pr(l_max_width,l_stat_ln,'READ REQ:          '||r_stats1.PHY_READ_REQ_DELTA,  'READ REQ:          '||r_stats2.PHY_READ_REQ_DELTA,  round(100*((r_stats2.PHY_READ_REQ_DELTA-r_stats1.PHY_READ_REQ_DELTA)    /(case when r_stats2.PHY_READ_REQ_DELTA=0 then case when r_stats1.PHY_READ_REQ_DELTA=0 then 1 else r_stats1.PHY_READ_REQ_DELTA end else r_stats2.PHY_READ_REQ_DELTA end)),2)||'%');
         pr(l_max_width,l_stat_ln,'WRITE REQ:         '||r_stats1.PHY_WRITE_REQ_DELTA, 'WRITE REQ:         '||r_stats2.PHY_WRITE_REQ_DELTA, round(100*((r_stats2.PHY_WRITE_REQ_DELTA-r_stats1.PHY_WRITE_REQ_DELTA)  /(case when r_stats2.PHY_WRITE_REQ_DELTA=0 then case when r_stats1.PHY_WRITE_REQ_DELTA=0 then 1 else r_stats1.PHY_WRITE_REQ_DELTA end else r_stats2.PHY_WRITE_REQ_DELTA end)),2)||'%');      
   
         
         pr(l_max_width,l_stat_ln,'LIO:               '||r_stats1.BUFFER_GETS_DELTA,   'LIO:               '||r_stats2.BUFFER_GETS_DELTA,   round(100*((r_stats2.BUFFER_GETS_DELTA-r_stats1.BUFFER_GETS_DELTA)      /(case when r_stats2.BUFFER_GETS_DELTA=0 then case when r_stats1.BUFFER_GETS_DELTA=0 then 1 else r_stats1.BUFFER_GETS_DELTA end else r_stats2.BUFFER_GETS_DELTA end)),2)||'%');
         pr(l_max_width,l_stat_ln,'ROWS:              '||r_stats1.ROWS_PROCESSED_DELTA,'ROWS:              '||r_stats2.ROWS_PROCESSED_DELTA,round(100*((r_stats2.ROWS_PROCESSED_DELTA-r_stats1.ROWS_PROCESSED_DELTA)/(case when r_stats2.ROWS_PROCESSED_DELTA=0 then case when r_stats1.ROWS_PROCESSED_DELTA=0 then 1 else r_stats1.ROWS_PROCESSED_DELTA end else r_stats2.ROWS_PROCESSED_DELTA end)),2)||'%');
         pr(l_max_width,l_stat_ln,'LIO/ROW:           '||r_stats1.LIO_PER_ROW,         'LIO/ROW:           '||r_stats2.LIO_PER_ROW,         round(100*((r_stats2.LIO_PER_ROW-r_stats1.LIO_PER_ROW)                  /(case when r_stats2.LIO_PER_ROW=0 then case when r_stats1.LIO_PER_ROW=0 then 1 else r_stats1.LIO_PER_ROW end else r_stats2.LIO_PER_ROW end)),2)||'%');
         pr(l_max_width,l_stat_ln,'PIO/ROW:           '||r_stats1.IO_PER_ROW,          'PIO/ROW:           '||r_stats2.IO_PER_ROW,          round(100*((r_stats2.IO_PER_ROW-r_stats1.IO_PER_ROW)                    /(case when r_stats2.IO_PER_ROW=0 then case when r_stats1.IO_PER_ROW=0 then 1 else r_stats1.IO_PER_ROW end else r_stats2.IO_PER_ROW end)),2)||'%');
         pr(l_max_width,l_stat_ln,'AVG IO (MS):       '||r_stats1.awg_IO_tim,          'AVG IO (MS):       '||r_stats2.awg_IO_tim,          round(100*((r_stats2.awg_IO_tim-r_stats1.awg_IO_tim)                    /(case when r_stats2.awg_IO_tim=0 then case when r_stats1.awg_IO_tim=0 then 1 else r_stats1.awg_IO_tim end else r_stats2.awg_IO_tim end)),2)||'%');      
         pr(l_max_width,l_stat_ln,'IOWT/EXEC(MS)5ms:  '||r_stats1.io_wait_pe_5ms,      'IOWT/EXEC(MS)5ms:  '||r_stats2.io_wait_pe_5ms,      round(100*((r_stats2.io_wait_pe_5ms-r_stats1.io_wait_pe_5ms)            /(case when r_stats2.io_wait_pe_5ms=0 then case when r_stats1.io_wait_pe_5ms=0 then 1 else r_stats1.io_wait_pe_5ms end else r_stats2.io_wait_pe_5ms end)),2)||'%');      
         pr(l_max_width,l_stat_ln,'IOWAIT(SEC)5ms:    '||r_stats1.io_wait_5ms,         'IOWAIT(SEC)5ms:    '||r_stats2.io_wait_5ms,         round(100*((r_stats2.io_wait_5ms-r_stats1.io_wait_5ms)                  /(case when r_stats2.io_wait_5ms=0 then case when r_stats1.io_wait_5ms=0 then 1 else r_stats1.io_wait_5ms end else r_stats2.io_wait_5ms end)),2)||'%');      
         
--^'||q'^

         --Statistics comparison
         p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Statistics comparison for '||l_sql_id,cname=>'stat_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR);
         print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>800);
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         p(HTF.BR);
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.BR);          
         
         --Wait profile
         p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Wait profile (approx), sec for '||l_sql_id,cname=>'wait_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR);
         l_sql:=l_wait_profile;
         prepare_script_comp(l_sql);
         l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
         print_table_html(l_sql,800,'Wait profile');
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         p(HTF.BR);      
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.BR);  
         
 --^'||q'^        
         --ASH plan statistics
         p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' ASH plan statistics '||l_sql_id,cname=>'ash_plan_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR);
         if my_rec(a).plan_hash_value=0 or my_rec(b).plan_hash_value=0 then
           p('There is no plan available for PLAN_HASH=0.');
           p(HTF.BR);
         else 
           l_sql:=l_ash_plan;
           prepare_script_comp(l_sql);
           l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
           print_table_html(l_sql,1500,'ASH plan statistics');
         end if;
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         p(HTF.BR);      
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.BR);  
         
         
         --ASH time span
         p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' ASH time span '||l_sql_id,cname=>'ash_span_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR);
         l_sql:=l_ash_span;
         prepare_script_comp(l_sql);
         l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
         
         print_table_html(l_sql,1500,'ASH time span');
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         p(HTF.BR);      
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.BR);        
--^'||q'^
         l_text:=null; 
         --plans
         if l_single_plan then
           if my_rec(a).plan_hash_value<>0 then 
             pr1(rpad('-',l_max_width+1,'-'));
             pr1('ATTENTION: single plan available only');
             pr1(rpad('-',l_max_width+1,'-'));
           end if;
         else
           pr1(rpad('-',l_max_width*2+1,'-'));
         end if;
         if my_rec(a).plan_hash_value=0 then
           pr1('ATTENTION: no plan available, plan_hash_value=0');
           pr1('-----------------------------------------------');
           select substr(sql_text,1,4000) into l_sql from dba_hist_sqltext where sql_id = l_sql_id and dbid in ( l_dbid1, l_dbid2 ) and rownum<2;
           pr1(l_sql);
           pr1(rpad('-',l_max_width+1,'-'));
         end if;
      
         <<print_plan_comparison>>
         for j in 1 .. i loop
           if p1.exists(j) then
             r1:=rpad(nvl(rtrim(replace(p1(j),chr(9),' ')),' '), l_max_width, ' ');
           else
             r1 := rpad('.', l_max_width, ' ');
           end if;
           if p2.exists(j) and not l_single_plan then
             r2 := p2(j);
           else
             r2 := null;
           end if;
           if REGEXP_REPLACE(trim(ltrim(r1,'.')),'\s+','')=REGEXP_REPLACE(trim(r2),'\s+','') then
             pr1(r1 || '+' || r2);
           else
             pr1(r1 || case when r2 is null then '*' else '-' || r2 end);
           end if;
         end loop print_plan_comparison;
--^'||q'^         
         --Plans comparison
         p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Plans comparison for '||l_sql_id,cname=>'pl_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
         p(HTF.BR);      
         print_text_as_table(p_text=>l_text,p_t_header=>'',p_width=>3000);
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
         p(HTF.BR);
         if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
         p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
         p(HTF.BR);
         p(HTF.BR);          
       end loop comp_inner;
     end loop comp_outer;
   end loop query_list_loop;
   --close l_all_sqls;
   
   p(HTF.BR);
   p(HTF.BR);  
   p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'System metrics',cname=>'sysmetr',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR);
   
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr1',ctext=>'System metrics DB1',cattributes=>'class="awr"')));
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr2',ctext=>'System metrics DB2',cattributes=>'class="awr"')));

   p(HTF.BR);  
   p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'System metrics for DB1',cname=>'sysmetr1',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR);   
   
   --db1 sysmetrics
   for i in (select unique INSTANCE_NUMBER from dba_hist_database_instance where dbid=l_dbid1 order by 1)
   loop
     p('Instance number: '||i.INSTANCE_NUMBER);
     --with a as (select * from dba_hist_sysmetric_history&dblnk. where dbid=&dbid. and snap_id between &start_snap. and &end_snap. and instance_number=&inst_id.)
     l_sql:=replace(l_sysmetr,'&dblnk.','');
     l_sql:=replace(replace(replace(replace(l_sql,'&dbid.',l_dbid1),'&start_snap.',l_start_snap1),'&end_snap.',l_end_snap1),'&inst_id.',i.INSTANCE_NUMBER); 
     print_table_html(l_sql,3000,'System metrics');--,p_style1 =>'awrncbbt',p_style2 =>'awrcbbt');
   end loop;   
   
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr',ctext=>'Back to System metrics',cattributes=>'class="awr"')));   
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
   p(HTF.BR);   
   
   p(HTF.BR);  
   p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'System metrics for DB2',cname=>'sysmetr2',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR);  
--^'||q'^   
   --db2 sysmetrics
   for i in (select unique INSTANCE_NUMBER from dba_hist_database_instance where dbid=l_dbid2 order by 1)
   loop
     p('Instance number: '||i.INSTANCE_NUMBER);
     --with a as (select * from dba_hist_sysmetric_history&dblnk. where dbid=&dbid. and snap_id between &start_snap. and &end_snap. and instance_number=&inst_id.)
     l_sql:=replace(l_sysmetr,'&dblnk.',l_dblink);
     l_sql:=replace(replace(replace(replace(l_sql,'&dbid.',l_dbid2),'&start_snap.',l_start_snap2),'&end_snap.',l_end_snap2),'&inst_id.',i.INSTANCE_NUMBER); 
     print_table_html(l_sql,3000,'System metrics');--,p_style1 =>'awrncbbt',p_style2 =>'awrcbbt');
   end loop;
   
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr',ctext=>'Back to System metrics',cattributes=>'class="awr"')));     
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));

   
   --Non-comparable queries
   p(HTF.BR);  
   p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Non-comparable queries',cname=>'noncomp',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
   p(HTF.BR); 
   p(HTF.BR);
   prepare_script_comp(l_noncomp);
   --p(l_noncomp);
   print_table_html(l_noncomp,2000,'Non-comparable queries');
   p(HTF.BR);
   p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
   p(HTF.BR);
   p(HTF.BR);   
   
   p(HTF.BR);
   p(HTF.BR);   
if not l_embeded then    
   p((HTF.BODYCLOSE));
   p((HTF.HTMLCLOSE));
end if;   
end;