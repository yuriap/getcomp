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
  l_single_sql_report number := case when instr(upper(l_filter), 'SQL_ID=')>0 
                                      and l_dbid1=l_dbid2 
                                      and l_start_snap1=l_start_snap2 
                                      and l_end_snap1=l_end_snap2 
                                      and l_dblink is null 
                                      then 1 else 0 end;
  
  g_plan_format varchar2(100):='ADVANCED -ALIAS';
  type t_my_rec is record(
    dbid            number,
    plan_hash_value number,
    src             varchar2(10),
    start_snap      number,
    end_snap        number);
  type t_my_tab_rec is table of t_my_rec index by pls_integer;
  my_rec t_my_tab_rec;  
  type my_arrayofstrings is table of varchar2(1000);
  p1       my_arrayofstrings := my_arrayofstrings();
  p2       my_arrayofstrings := my_arrayofstrings();
  p11      my_arrayofstrings;
  p21      my_arrayofstrings;  
  
  type t_section is table of my_arrayofstrings index by varchar2(100);
  l_sec1 t_section;
  l_sec2 t_section;  
  l_plan_sections_all my_arrayofstrings := my_arrayofstrings('SQL_ID',
                                                             'Plan hash value:',
                                                             'Query Block Name / Object Alias (identified by operation id):',
                                                             'Outline Data',
                                                             'Remote SQL Information (identified by operation id):',
                                                             'Peeked Binds (identified by position):',
                                                             'Note');  
  l_curr_section number; 
  l_plan_sections my_arrayofstrings := my_arrayofstrings();
  type t_available_sections is table of number index by varchar2(100);
  l_available_sections t_available_sections;
  
  l_tab1   my_arrayofstrings;
  l_tab2   my_arrayofstrings;

  r1       varchar2(1000);
  r2       varchar2(1000);
  l_fst1   varchar2(100):='<span`class="nm"><b>';
  l_fst2   varchar2(100):='</b></span>';
  l_s_tag  varchar2(2)  := '<`';
  l_e_tag  varchar2(2)  := '`>';
  l_max_ind number;
  
  type t_r_db_header is record (
    short_name varchar2(100),
    long_name  varchar2(4000)
  );
  type t_db_header is table of t_r_db_header index by varchar2(10);
  type t_t_db_header is table of t_db_header index by pls_integer;
  l_db_header t_t_db_header;
  
  l_crsr sys_refcursor;
  l_plsql_output clob;
  
  l_single_plan boolean;
  l_all_sqls sys_refcursor;
  l_all_perms sys_refcursor;
  l_sql_id varchar2(30);
  l_next_sql_id varchar2(30);
  l_total  number;
  l_rn     number;
  l_cnt    number;
  l_pair_num  number;
  l_max_width number;
  l_plan_rowcnt number;
  l_stat_ln   number := 40;
  
  l_1_2_change number;
  l_1_2_change_tot number;
  
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
select SQLN "Top N", sql_id, tot_&sortcol., unique_plan_hash "Unique plans number", run_1_2_change "Ela/Exec change, %", decode(SQLN,1,run_1_2_avg_change,null) "Total Elapsed change, %" from (
select rownum SQLN, x.sql_id, x.tot_&sortcol., x.unique_plan_hash, 
       round(100*((db2_ee-db1_ee)/(case when db1_ee=0 then case when db2_ee=0 then 1 else db2_ee end else db1_ee end)),2) run_1_2_change,
       --round(100*avg((db2_ee-db1_ee)/(case when db1_ee=0 then case when db2_ee=0 then 1 else db2_ee end else db1_ee end))over(),2) run_1_2_avg_change
       round(100*(sum(db2_ela)over()-sum(db1_ela)over())/(case when sum(db1_ela)over()=0 then case when sum(db2_ela)over()=0 then 1 else sum(db2_ela)over() end else sum(db1_ela)over() end),2) run_1_2_avg_change
  from (select sql_id, sum(&sortcol.) tot_&sortcol., count(unique PLAN_HASH_VALUE) unique_plan_hash,
               sum(db1_ela)/decode(sum(db1_exe),0,1,sum(db1_exe)) db1_ee,
               sum(db1_ela) db1_ela,
               sum(db2_ela)/decode(sum(db2_exe),0,1,sum(db2_exe)) db2_ee,
               sum(db2_ela) db2_ela
          from (select db2.*,
                       decode(db,1,ELAPSED_TIME_DELTA,0) db1_ela, decode(db,1,EXECUTIONS_DELTA,0) db1_exe,
                       decode(db,2,ELAPSED_TIME_DELTA,0) db2_ela, decode(db,2,EXECUTIONS_DELTA,0) db2_exe
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
                       (select 1 db, s.sql_id, s.PLAN_HASH_VALUE, s.CPU_TIME_DELTA, s.ELAPSED_TIME_DELTA, s.BUFFER_GETS_DELTA, s.EXECUTIONS_DELTA
                          from dba_hist_sqlstat s
                         where dbid = &dbid1. and snap_id between &start_snap1. and &end_snap1.
                           and parsing_schema_name <> 'SYS'
                           and decode(module, 'performance_info', 0, 1) = 1
                           and decode(module, 'MMON_SLAVE', 0, 1) = 1
                           and &filter.
                           and instance_number between 1 and 256
                           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                        union all
                        select 2 db, s.sql_id, s.PLAN_HASH_VALUE, s.CPU_TIME_DELTA, s.ELAPSED_TIME_DELTA, s.BUFFER_GETS_DELTA, s.EXECUTIONS_DELTA
                          from dba_hist_sqlstat&dblnk. s
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
         order by tot_&sortcol. desc) x)
}';

--^'||q'^

  l_sqlstat_data  clob:=
    case when l_single_sql_report=0 then
q'{
select  
       src Source, min(snap_id) min_snap, max(snap_id) max_snap, count(1) cnt, plan_hash_value plan_hash, PARSING_USER_ID, parsing_schema_name parsing_schema, module,action
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
     group by src, plan_hash_value, parsing_user_id, parsing_schema_name, module, action
     order by 1,2,3
}'
else
q'{
select  
       min(snap_id) min_snap, max(snap_id) max_snap, count(1) cnt, plan_hash_value plan_hash, PARSING_USER_ID, parsing_schema_name parsing_schema, module,action
     from 
       (
        select x.* from dba_hist_sqlstat x 
         where sql_id='&l_sql_id'
           and dbid=&dbid1. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256
           and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
       )
     group by plan_hash_value, parsing_user_id, parsing_schema_name, module, action
     order by 1,2
}'
end;

--^'||q'^

  l_ash_data  clob:=
    case when l_single_sql_report=0 then  
q'{
select src source, min(snap_id) min_snap, max(snap_id) max_snap, count(1) cnt, sql_id, TOP_LEVEL_SQL_ID, sql_plan_hash_value, user_id, program, module, action, client_id, top_call, end_call       
    from 
      (
       select 'DB1' src, x.*,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id) top_call,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=PLSQL_OBJECT_ID and subprogram_id=PLSQL_SUBPROGRAM_ID) end_call     
         from dba_hist_active_sess_history x
        where (sql_id='&l_sql_id' or TOP_LEVEL_SQL_ID='&l_sql_id')
          and (dbid=&dbid1. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256)
       union all
       select 'DB2' src, x.*,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id) top_call,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=PLSQL_OBJECT_ID and subprogram_id=PLSQL_SUBPROGRAM_ID) end_call
         from dba_hist_active_sess_history&dblnk. x
        where (sql_id='&l_sql_id' or TOP_LEVEL_SQL_ID='&l_sql_id')
          and (dbid=&dbid2. and snap_id between &start_snap2. and &end_snap2. and instance_number between 1 and 256)
      )
    group by src, sql_id,TOP_LEVEL_SQL_ID,sql_plan_hash_value,user_id,program,module,action,client_id,top_call,end_call
    order by 1,2,3
}'
else
q'{
select min(snap_id) min_snap, max(snap_id) max_snap, count(1) cnt, sql_id, TOP_LEVEL_SQL_ID, sql_plan_hash_value, user_id, program, module, action, client_id, top_call, end_call       
    from 
      (
       select 'DB1' src, x.*,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id) top_call,
              (select owner || '; ' || object_type || '; ' || object_name || decode(PROCEDURE_NAME, null, null, '.' || PROCEDURE_NAME) from dba_procedures where object_id=PLSQL_OBJECT_ID and subprogram_id=PLSQL_SUBPROGRAM_ID) end_call     
         from dba_hist_active_sess_history x
        where (sql_id='&l_sql_id' or TOP_LEVEL_SQL_ID='&l_sql_id')
          and (dbid=&dbid1. and snap_id between &start_snap1. and &end_snap1. and instance_number between 1 and 256)
      )
    group by sql_id,TOP_LEVEL_SQL_ID,sql_plan_hash_value,user_id,program,module,action,client_id,top_call,end_call
    order by 1,2
}'
end;


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
            select to_char(trunc(sample_time, 'hh'),'YYYY-MON-DD HH24') tim, round(avg(c)) avg_cnt, max(c) max_cnt
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
             order by trunc(sample_time, 'hh')
             )x),
db2 as (select rownum n, 'DB2' src, x.* from (
            select to_char(trunc(sample_time, 'hh'),'YYYY-MON-DD HH24') tim, round(avg(c)) avg_cnt, max(c)max_cnt
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
             order by trunc(sample_time, 'hh'))x)
select
   a.src source, a.tim "Hour",a.avg_cnt "Avg number of sess",a.max_cnt "Max number of sess",
   b.src source, b.tim "Hour",b.avg_cnt "Avg number of sess",b.max_cnt "Max number of sess"
from db1 a full outer join db2 b on (a.n=b.n)
order by a.n nulls last, b.n nulls last
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

  cursor c_title1(p_dbid1 number, p_start_snap1 number, p_end_snap1 number) is
    select 
      DB_NAME, sn.DBID,version,host_name,
      to_char(max(i.STARTUP_TIME),'YYYY/MM/DD HH24:mi:ss')STARTUP_TIME,
      to_char(min(sn.BEGIN_INTERVAL_TIME),'YYYY/MM/DD HH24:mi')BEGIN_INTERVAL_TIME,
      to_char(max(sn.END_INTERVAL_TIME),'YYYY/MM/DD HH24:mi')END_INTERVAL_TIME,
      min(snap_id) mi_snap_id, max(snap_id) ma_snap_id
     from dba_hist_database_instance i, 
          dba_hist_snapshot sn 
    where i.dbid = sn.dbid 
      and i.startup_time=sn.startup_time
      and sn.instance_number=i.instance_number
      and sn.dbid = p_dbid1
      and sn.snap_id between p_start_snap1 and p_end_snap1
      and sn.instance_number between 1 and 256
    group by DB_NAME, sn.DBID,version,host_name
    order by 6;
  r_title1 c_title1%rowtype;
  
  cursor c_title2(p_dbid2 number, p_start_snap2 number, p_end_snap2 number) is
    select unique
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
      and sn.instance_number=i.instance_number
      and sn.dbid = p_dbid2
      and sn.snap_id between p_start_snap2 and p_end_snap2
      and sn.instance_number between 1 and 256;
  r_title2 c_title2%rowtype;      
  
  cursor c_getsqlperm(p_sql_id varchar2) is
    select src, dbid, plan_hash_value, mi, ma 
      from (select src, dbid, plan_hash_value, version, min(snap_id) mi, max(snap_id) ma
              from 
              (select 'DB1' src, x.*, i.version from dba_hist_sqlstat x, dba_hist_database_instance i, dba_hist_snapshot sn  
                where i.dbid = sn.dbid 
                  and i.startup_time=sn.startup_time
                  and x.dbid=sn.dbid and sn.snap_id=x.snap_id
                  and x.instance_number=sn.instance_number and sn.instance_number=i.instance_number
                  and sql_id=p_sql_id
                  and x.dbid=l_dbid1 and x.snap_id between l_start_snap1 and l_end_snap1 and x.instance_number between 1 and 256
                  and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
                union all
               select 'DB2' src, x.*, i.version 
$IF '~dblnk.' is not null $THEN   
                 from dba_hist_sqlstat~dblnk. x, dba_hist_database_instance~dblnk. i, dba_hist_snapshot~dblnk. sn
$ELSE
                 from dba_hist_sqlstat x, dba_hist_database_instance i, dba_hist_snapshot sn
$END                 
                where i.dbid = sn.dbid 
                  and i.startup_time=sn.startup_time
                  and x.dbid=sn.dbid and sn.snap_id=x.snap_id
                  and x.instance_number=sn.instance_number and sn.instance_number=i.instance_number
                  and sql_id=p_sql_id
                  and x.dbid=l_dbid2 and x.snap_id between l_start_snap2 and l_end_snap2 and x.instance_number between 1 and 256
                  and CPU_TIME_DELTA+ELAPSED_TIME_DELTA+BUFFER_GETS_DELTA+EXECUTIONS_DELTA>0
$IF '~dblnk.' is null $THEN  
                  and l_single_sql_report = 0 -- when analyzing a single sql in a local DB, do not mess with excessive plan comparison from DB2.
$END                                  
                  ) group by src, dbid, version, plan_hash_value
                  ) x
                order by src, dbid, version, plan_hash_value;
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
      ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
      ,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
      ,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
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
      ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
      ,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
      ,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
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
  
   l_time number;
   l_cpu_tim number;
   l_tot_time number:=0;
   l_tot_cpu_tim number:=0;   
   
   l_timing boolean := true;  
  
--^'||q'^
  
@@__procs

--^'||q'^  

  procedure stim is
  begin
    if l_timing then
      l_time:=DBMS_UTILITY.GET_TIME;
      l_cpu_tim:=DBMS_UTILITY.GET_CPU_TIME;
    end if;
  end;
  procedure etim(p_final boolean default false, p_marker varchar2 default null) is
  begin
    if l_timing then
      l_time:=DBMS_UTILITY.GET_TIME-l_time;l_tot_time:=l_tot_time+l_time;
      l_cpu_tim:=DBMS_UTILITY.GET_CPU_TIME-l_cpu_tim;l_tot_cpu_tim:=l_tot_cpu_tim+l_cpu_tim;
      p(HTF.header (6,cheader=>case when p_marker is not null then p_marker ||': ' else null end || 'Elapsed (sec): '||to_char(round((l_time)/100,2))||'; CPU (sec): '||to_char(round((l_cpu_tim)/100,2)),cattributes=>'class="awr"'));
      if p_final then
        p(HTF.header (6,cheader=>'TOTAL: Elapsed (sec): '||to_char(round((l_tot_time)/100,2))||'; CPU (sec): '||to_char(round((l_tot_cpu_tim)/100,2)),cattributes=>'class="awr"'));
      end if;
    end if;
  end;
   
  procedure pr1(p_msg varchar2) is begin l_text:=l_text||p_msg||chr(10); end;
  procedure pr2(p_msg varchar2, p_match varchar2) is begin l_text:=l_text||'~~*'||p_match||'*~~'||p_msg||chr(10); end;
  procedure pr(length1 number,length2 number, par1 varchar2, par2 varchar2, par3 varchar2 default null) 
  is 
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
$IF DBMS_DB_VERSION.ver_le_12 $THEN --R12
        from table(dbms_xplan.display_awr(p_sql_id, p_plan_hash, p_dbid, g_plan_format));
$ELSE   --R18 multi tenant
        from table(dbms_xplan.display_workload_repository(sql_id=>p_sql_id, plan_hash_value=>p_plan_hash, dbid=>p_dbid, con_dbid=>p_dbid, format=>g_plan_format, awr_location=>'AWR_PDB'));
$END        
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
$IF DBMS_DB_VERSION.ver_le_12 $THEN --R12
        from table(dbms_xplan.display_awr(p_sql_id, p_plan_hash, p_dbid, g_plan_format));
$ELSE   --R18 multi tenant
        from table(dbms_xplan.display_workload_repository(sql_id=>p_sql_id, plan_hash_value=>p_plan_hash, dbid=>p_dbid, con_dbid=>p_dbid, format=>g_plan_format, awr_location=>'AWR_PDB'));
$END
$END
    end if;
--p('count_plan: '||p_plan_hash||':'||p_data.count);
  end;
  
--^'||q'^

procedure prepare_script_comp(p_script in out clob, p_dbid1 number, p_dbid2 number, p_start_snap1 number, p_end_snap1 number, p_start_snap2 number, p_end_snap2 number) is 
  l_scr clob := p_script;
  l_line varchar2(32765);
  l_eof number;
  l_iter number := 1;
begin
  l_scr:=l_scr||chr(10);
  --set variable
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dbid1.',p_dbid1),'&dbid1',p_dbid1),'&start_snap1.',p_start_snap1),'&start_snap1',p_start_snap1),'&end_snap1.',p_end_snap1),'&end_snap1',l_end_snap1); 
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dbid2.',p_dbid2),'&dbid2',p_dbid2),'&start_snap2.',p_start_snap2),'&start_snap2',p_start_snap2),'&end_snap2.',p_end_snap2),'&end_snap2',l_end_snap2); 
  p_script:=replace(replace(replace(replace(replace(replace(p_script,'&dblnk.',l_dblink),'&dblnk',l_dblink),'&sortcol.',l_sortcol),'&sortcol',l_sortcol),'&sortlimit.',l_sortlimit),'&sortlimit',l_sortlimit); 
  p_script:=replace(replace(p_script,'&filter.',l_filter),'&filter',l_filter); 
end;

procedure to_table_for_comparison(p_list IN OUT VARCHAR2, p_tab out my_arrayofstrings, p_start_tag varchar2 default null, p_end_tag varchar2 default null)
IS
  l_string       VARCHAR2(32767) := p_list;
  l_comma_index  PLS_INTEGER;
  l_index        PLS_INTEGER := 1;
  l_sep            varchar2(1) := ',';
  l_trailing_space number;
BEGIN
  p_tab := my_arrayofstrings();
  if instr(p_list,'|') > 0 then l_sep := '|';end if;
  if instr(p_list,'Plan hash value') > 0 then l_sep := ':';end if;
  l_trailing_space:=nvl(length(l_string),0)-nvl(length(trim(l_string)),0);
  if substr(trim(l_string),nvl(length(trim(l_string)),0))=l_sep then null; else l_string:=l_string||l_sep; end if;
  p_list:= null;
  LOOP
    l_comma_index := INSTR(l_string, l_sep, l_index);
    EXIT WHEN l_comma_index = 0;
    p_tab.EXTEND;
    p_tab(p_tab.COUNT) := '~`'||p_tab.COUNT||'`~'||p_start_tag || trim(SUBSTR(l_string, l_index, l_comma_index - l_index)) || p_end_tag;    
    p_list:=p_list|| replace(SUBSTR(l_string, l_index, l_comma_index - l_index),trim(SUBSTR(l_string, l_index, l_comma_index - l_index)),p_tab(p_tab.COUNT)) ||l_sep;
    l_index := l_comma_index + 1;
  END LOOP;
  if l_sep <> '|' then 
    p_list:=rtrim(p_list,l_sep); 
  else
    p_list:=p_list||rpad(' ',l_trailing_space, ' ');
  end if;
  l_trailing_space:=nvl(length(p_list),0)-nvl(length(trim(p_list)),0);
END;

begin

--^'||q'^

  if not l_embeded then 
    stim();
    p(HTF.HTMLOPEN);
    p(HTF.HEADOPEN);
    p(HTF.TITLE('AWR SQL comparison report'));   

    p('<style type="text/css">');
    p(l_css);
    p('</style>');
    p(HTF.HEADCLOSE);
    p(HTF.BODYOPEN(cattributes=>'class="awr"'));
   
    p(HTF.header (1,'AWR SQL comparison report',cattributes=>'class="awr"'));
    if l_single_sql_report=1 then p(HTF.header (6,cheader=>'Single SQL report')); end if;
    
    p(HTF.header (2,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Table of contents',cname=>'tblofcont',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
    p(HTF.BR);
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#parameters',ctext=>'Parameters',cattributes=>'class="awr"')));
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#db_desc',ctext=>'Databases description',cattributes=>'class="awr"')));
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_list',ctext=>'SQL list',cattributes=>'class="awr"')));
   
    if l_single_sql_report=0 then   
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sysmetr',ctext=>'System metrics',cattributes=>'class="awr"')));
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#noncomp',ctext=>'Non-comparable queries',cattributes=>'class="awr"')));
    end if; --l_single_sql_report=0
  
    p(HTF.BR);
    p(HTF.BR); 

    p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Parameters',cname=>'parameters',cattributes=>'class="awr"'),cattributes=>'class="awr"'));   
    l_text:='Report input parameters:'||chr(10);
    if l_single_sql_report=0 then
      --generic report
      l_text:=l_text||'DB1: DBID: '||l_dbid1||'; snap_id between '||(l_start_snap1-1)||' and '||l_end_snap1||chr(10);
      l_text:=l_text||'DB2: DBID: '||l_dbid2||'; snap_id between '||(l_start_snap2-1)||' and '||l_end_snap2||chr(10);
      l_text:=l_text||'DB Link: <'||l_dblink||'>'||chr(10);
      l_text:=l_text||'Sort column: '||l_sortcol||chr(10);
      l_text:=l_text||'Limit: '||l_sortlimit||chr(10);
      l_text:=l_text||'Filter: '||l_filter||chr(10);
    else
      --single sql report
      l_text:=l_text||'DB: DBID: '||l_dbid1||'; snap_id between '||(l_start_snap1-1)||' and '||l_end_snap1||chr(10);
      l_text:=l_text||'Filter: '||l_filter||chr(10);      
    end if;
    print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>400);
    p(HTF.BR);
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
    p(HTF.BR);
    p(HTF.BR); 
    etim();
  end if; --if not l_embeded then

--^'||q'^

  if not l_embeded then   
    stim();
    p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Databases description',cname=>'db_desc',cattributes=>'class="awr"'),cattributes=>'class="awr"'));   

    l_text:='Description:'||chr(10);
    if l_single_sql_report=0 then
      --generic report
  
      open c_title1(l_dbid1,l_start_snap1,l_end_snap1);
      fetch c_title1 into r_title1; close c_title1;
      
      --do not change the following line
      l_text:=l_text||'DB1:'||chr(10);
      l_text:=l_text||'DB name: '||r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Host:'||r_title1.host_name||'; Ver:'||r_title1.version||'; Snaps: '||l_start_snap1||':'||r_title1.BEGIN_INTERVAL_TIME||'; '||l_end_snap1||':'||r_title1.END_INTERVAL_TIME||'; Started: '||r_title1.STARTUP_TIME||chr(10);
      
      open c_title2(l_dbid2,l_start_snap2,l_end_snap2);
      fetch c_title2 into r_title2; close c_title2;
      
      --do not change the following line
      l_text:=l_text||'DB2:'||chr(10);
      l_text:=l_text||'DB name: '||r_title2.DB_NAME||' DBID:'||r_title2.DBID||'; Host:'||r_title2.host_name||'; Ver:'||r_title2.version||'; Snaps: '||l_start_snap2||':'||r_title2.BEGIN_INTERVAL_TIME||'; '||l_end_snap2||':'||r_title2.END_INTERVAL_TIME||'; Started: '||r_title2.STARTUP_TIME||chr(10);  
    else
      --single SQL
      l_cnt:=1;
      open c_title1(l_dbid1,l_start_snap1,l_end_snap1);
      loop
        fetch c_title1 into r_title1; 
        exit when c_title1%notfound;
        l_text:=l_text||'DB'||l_cnt||':'||chr(10);
        l_text:=l_text||'DB name: '||r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Host:'||r_title1.host_name||'; Ver:'||r_title1.version||'; Snaps: '||r_title1.mi_snap_id||':'||r_title1.BEGIN_INTERVAL_TIME||'; '||r_title1.ma_snap_id||':'||r_title1.END_INTERVAL_TIME||'; Started: '||r_title1.STARTUP_TIME||chr(10);
        l_cnt:=l_cnt+1;
      end loop; 
      close c_title1;
    end if;
    
    print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>400);
    
    p(HTF.BR);
    
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
    p(HTF.BR);
    p(HTF.BR);    
   
    --SQL list
    p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'SQL list',cname=>'sql_list',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
    p(HTF.BR);
    etim();
  end if; --if not l_embeded then    
  
  prepare_script_comp(l_getqlist, l_dbid1, l_dbid2, l_start_snap1, l_end_snap1, l_start_snap2, l_end_snap2);
  
  if not l_embeded then  
    stim();  
    print_table_html(l_getqlist,600,'SQL list',p_search=>'SQL_ID',p_replacement=>HTF.ANCHOR (curl=>'#sql_\1',ctext=>'\1',cattributes=>'class="awr1"'));
    p(HTF.BR);
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
    p(HTF.BR);
    etim();
    p(HTF.BR);     
  end if; --if not l_embeded then   
   
--^'||q'^

  --getting sqls list
  open l_all_sqls for l_getqlist;
  <<query_list_creating>>
  loop
    fetch l_all_sqls into l_rn, l_sql_id, l_total, l_cnt, l_1_2_change, l_1_2_change_tot; --l_total, l_cnt is not used so far
    exit when l_all_sqls%notfound;   
    l_sqls(l_rn):=l_sql_id;
  end loop query_list_creating;
  close l_all_sqls;

--==============================================================         
--^'; l_script1 clob := q'^         
--==============================================================
  
  <<query_list_loop>>
  for n in 1..l_sqls.count
  loop
     
    l_rn:=n;
    l_sql_id:=l_sqls(l_rn);
     
    if l_sqls.exists(l_rn+1) then l_next_sql_id:=l_sqls(l_rn+1); else l_next_sql_id:=null; end if;
     
    --get list of all plans
    my_rec.delete;
    l_cnt:=1; --comparison index
    open c_getsqlperm(l_sql_id);
    loop
      fetch c_getsqlperm into my_rec(l_cnt).src, my_rec(l_cnt).dbid, my_rec(l_cnt).plan_hash_value, my_rec(l_cnt).start_snap, my_rec(l_cnt).end_snap;
      exit when c_getsqlperm%notfound;
      l_cnt:=l_cnt+1;     
    end loop;
    close c_getsqlperm;
    
    if not l_embeded then    
      p(HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'#'||l_rn||' Comparison of '||l_sql_id,cname=>'sql_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
      p(HTF.BR);
      p(HTF.BR);
    end if; --if not l_embeded then
    
    if not l_embeded then  
      stim();   
      l_sql:=q'[select x.sql_text text from dba_hist_sqltext x where sql_id=']'||l_sql_id||q'[' and rownum=1]'||chr(10);
      open l_crsr for l_sql;
      fetch l_crsr into l_plsql_output;
      if l_crsr%found then
        print_text_as_table(p_text=>l_plsql_output,p_t_header=>'SQL text',p_width=>1000);
      else
        print_text_as_table(p_text=>'No SQL data found.',p_t_header=>'SQL text',p_width=>500);
      end if;   
      close l_crsr;
   
      p(HTF.BR);
      p(HTF.BR);
      
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sqlst_'||l_sql_id,ctext=>'SQL stat data',cattributes=>'class="awr"')));
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_'||l_sql_id,ctext=>'ASH data',cattributes=>'class="awr"')));
      p(HTF.BR); 
      etim();
      p(HTF.BR); 
    end if; --if not l_embeded then      
    
    --loop through all pairs of plans to compare   
    stim(); 
    l_pair_num:=1; --comparison index l_cnt
    <<comp_outer>>
    for a in 1 .. my_rec.count 
    loop
      <<comp_inner>>
      for b in (case when my_rec.count=1 then 1 else a + 1 end) .. my_rec.count 
      loop  
        open c_title1(my_rec(a).dbid,my_rec(a).start_snap, my_rec(a).end_snap);
        fetch c_title1 into r_title1; close c_title1;
        open c_title2(my_rec(b).dbid,my_rec(b).start_snap, my_rec(b).end_snap);
        fetch c_title2 into r_title2; close c_title2;
        
        l_db_header(l_pair_num)('DB1').short_name:=r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Snaps: '||(my_rec(a).start_snap)||'; '||my_rec(a).end_snap;
        l_db_header(l_pair_num)('DB1').long_name :='DB name: '||r_title1.DB_NAME||' DBID:'||r_title1.DBID||'; Host:'||r_title1.host_name||'; Ver:'||r_title1.version||'; Snaps: '||(my_rec(a).start_snap)||':'||r_title1.BEGIN_INTERVAL_TIME||'; '||my_rec(a).end_snap||':'||r_title1.END_INTERVAL_TIME||'; Started: '||r_title1.STARTUP_TIME;
        
        l_db_header(l_pair_num)('DB2').short_name:=r_title2.DB_NAME||' DBID:'||r_title2.DBID||'; Snaps: '||(my_rec(b).start_snap)||'; '||my_rec(b).end_snap;
        l_db_header(l_pair_num)('DB2').long_name :='DB name: '||r_title2.DB_NAME||' DBID:'||r_title2.DBID||'; Host:'||r_title2.host_name||'; Ver:'||r_title2.version||'; Snaps: '||(my_rec(b).start_snap)||':'||r_title2.BEGIN_INTERVAL_TIME||'; '||my_rec(b).end_snap||':'||r_title2.END_INTERVAL_TIME||'; Started: '||r_title2.STARTUP_TIME;      
        
        
        if l_single_sql_report=0 then
          --generic report
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Comparison: '||my_rec(a).src||': '||l_db_header(l_pair_num)(my_rec(a).src).short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with '||my_rec(b).src||': '||l_db_header(l_pair_num)(my_rec(b).src).short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cattributes=>'class="awr"')));
        else
          --single SQL
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Comparison: DB1: '||l_db_header(l_pair_num)('DB1').short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with DB2: '||l_db_header(l_pair_num)('DB2').short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cattributes=>'class="awr"')));
        end if;
        
        l_pair_num:=l_pair_num+1;
      end loop comp_inner;
    end loop comp_outer;      
    etim(); 
--^'||q'^     

    if not l_embeded then 
      stim();
      p(HTF.BR); 
      p(HTF.BR); 
      if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
      p(HTF.BR);
      p(HTF.BR);  

      p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' SQL stat data for '||l_sql_id,cname=>'sqlst_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
      p(HTF.BR);
      l_sql := replace(l_sqlstat_data,'&l_sql_id',l_sql_id);
      prepare_script_comp(l_sql, l_dbid1, l_dbid2, l_start_snap1, l_end_snap1, l_start_snap2, l_end_snap2);
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
      prepare_script_comp(l_sql, l_dbid1, l_dbid2, l_start_snap1, l_end_snap1, l_start_snap2, l_end_snap2);
      print_table_html(l_sql,1500,'ASH data',p_style1 =>'awrncbbt',p_style2 =>'awrcbbt');
      p(HTF.BR);  
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
      p(HTF.BR);
      if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
      p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
      p(HTF.BR);
      etim();
      p(HTF.BR); 
    end if; --if not l_embeded then 
     
--^'||q'^   

    --loop through all pairs ofplans to compare    
    l_pair_num:=1;    
    <<comp_outer>>
    for a in 1 .. my_rec.count 
    loop
      <<comp_inner>>
      for b in (case when my_rec.count=1 then 1 else a + 1 end) .. my_rec.count 
      loop
       
        if l_single_sql_report=0 then
          --generic report
          p(HTF.header (5,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Now comparing: '||my_rec(a).src||': '||l_db_header(l_pair_num)(my_rec(a).src).short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with '||my_rec(b).src||': '||l_db_header(l_pair_num)(my_rec(b).src).short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cname=>'cmp_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
        else
          --single SQL
          p(HTF.header (5,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Now comparing: DB1: '||l_db_header(l_pair_num)('DB1').short_name||'; PLAN_HASH: '||my_rec(a).plan_hash_value||' with DB2: '||l_db_header(l_pair_num)('DB2').short_name||'; PLAN_HASH: '||my_rec(b).plan_hash_value,cname=>'cmp_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
        end if;
        
        p(HTF.BR); 
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#stat_'||a||'_'||b||'_'||l_sql_id,ctext=>'Statistics comparison',cattributes=>'class="awr"')));
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#wait_'||a||'_'||b||'_'||l_sql_id,ctext=>'Wait profile',cattributes=>'class="awr"')));
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_plan_'||a||'_'||b||'_'||l_sql_id,ctext=>'ASH plan statistics',cattributes=>'class="awr"')));
        if not l_embeded then
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#ash_span_'||a||'_'||b||'_'||l_sql_id,ctext=>'ASH time span',cattributes=>'class="awr"')));
        end if;
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#pl_'||a||'_'||b||'_'||l_sql_id,ctext=>'Plans comparison',cattributes=>'class="awr"')));
        p(HTF.BR); 
        p(HTF.BR); 
        
        l_text:='Databases description:'||chr(10);
        l_text:=l_text||'DB1:'||l_db_header(l_pair_num)('DB1').long_name||chr(10);
        l_text:=l_text||'DB2:'||l_db_header(l_pair_num)('DB2').long_name||chr(10);
   
        print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>400);
        p(HTF.BR);
        p(HTF.BR);    
        
        
        if not l_embeded then         
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
          if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
          p(HTF.BR); 
          p(HTF.BR); 
        end if; --if not l_embeded then 
        
        stim(); 
        --load stats
        get_sql_stat(my_rec(a).src,l_sql_id,my_rec(a).plan_hash_value,my_rec(a).dbid,my_rec(a).start_snap, my_rec(a).end_snap,r_stats1);
        get_sql_stat(my_rec(b).src,l_sql_id,my_rec(b).plan_hash_value,my_rec(b).dbid,my_rec(b).start_snap, my_rec(b).end_snap,r_stats2);       
         
        --load plans
        get_plan(my_rec(a).src,l_sql_id, my_rec(a).plan_hash_value, my_rec(a).dbid,p11);
--p('p11:'||p11.count);
        etim(p_marker=>'Plans extract');
--^'||q'^         
        stim();
        l_max_width:=0;
        l_single_plan := true;
        if a<>b and my_rec(a).plan_hash_value<>my_rec(b).plan_hash_value and my_rec(a).plan_hash_value<>0 and my_rec(b).plan_hash_value<>0 then
          l_single_plan := false;
          get_plan(my_rec(b).src,l_sql_id, my_rec(b).plan_hash_value, my_rec(b).dbid,p21);
--p('p21:'||p21.count);       
          --couple of plans, width
          --
          for j in 1 .. p11.count loop
            if length(p11(j)) > l_max_width then
              l_max_width := length(p11(j));
            end if;
          end loop;
          for j in 1 .. p21.count loop
            if length(p21(j)) > l_max_width then
              l_max_width := length(p21(j));
            end if;
          end loop;    
          
          --aligning sections
          p1.delete;
          p2.delete;
          l_available_sections.delete;
          l_plan_sections.delete;
          
          for i in 1..p11.count loop
            for j in 1..l_plan_sections_all.count loop
              if instr(p11(i),l_plan_sections_all(j))>0 then 
                l_available_sections(l_plan_sections_all(j)):=1; 
              end if;
            end loop;
          end loop;  

          for i in 1..p21.count loop
            for j in 1..l_plan_sections_all.count loop
              if instr(p21(i),l_plan_sections_all(j))>0 then 
                l_available_sections(l_plan_sections_all(j)):=1; 
              end if;
            end loop;
          end loop;  

          for j in 1..l_plan_sections_all.count loop
            if l_available_sections.exists(l_plan_sections_all(j)) then 
              l_plan_sections.extend;
              l_plan_sections(l_plan_sections.count):=l_plan_sections_all(j);
            end if;
          end loop;
  
          for i in 1..l_plan_sections.count loop
            l_sec1(l_plan_sections(i)):=my_arrayofstrings();
            l_sec2(l_plan_sections(i)):=my_arrayofstrings();
          end loop;

          l_cnt := 1;l_curr_section:=1;
          for i in 1..p11.count loop
            if instr(p11(i),l_plan_sections(l_cnt))>0 then l_curr_section:=l_cnt; if l_cnt<l_plan_sections.count then l_cnt:=l_cnt+1; end if; end if;
            l_sec1(l_plan_sections(l_curr_section)).extend;
            l_sec1(l_plan_sections(l_curr_section))(l_sec1(l_plan_sections(l_curr_section)).count):=p11(i);
          end loop;
          
          l_cnt := 1;l_curr_section:=1;
          for i in 1..p21.count loop
            if instr(p21(i),l_plan_sections(l_cnt))>0 then l_curr_section:=l_cnt; if l_cnt<l_plan_sections.count then l_cnt:=l_cnt+1; end if; end if;
            l_sec2(l_plan_sections(l_curr_section)).extend;
            l_sec2(l_plan_sections(l_curr_section))(l_sec2(l_plan_sections(l_curr_section)).count):=p21(i);
          end loop;
     
          for a in 1..l_plan_sections.count loop
            for i in 1..greatest(l_sec1(l_plan_sections(a)).count,l_sec2(l_plan_sections(a)).count) loop
              p1.extend;
              if l_sec1(l_plan_sections(a)).exists(i) then
                p1(p1.count) := l_sec1(l_plan_sections(a))(i);
              else
                p1(p1.count):=' ';
              end if;
              p2.extend;
              if l_sec2(l_plan_sections(a)).exists(i) then
                p2(p2.count) := l_sec2(l_plan_sections(a))(i);
              else
                p2(p2.count):=' ';
              end if;      
            end loop;
          end loop;
          l_plan_rowcnt := greatest(p11.count, p21.count);
        else
          --single plan, width
          for j in 1 .. p11.count loop
            if length(p11(j)) > l_max_width then
              l_max_width := length(p11(j));
            end if;
          end loop;
          p1:=p11;
          l_plan_rowcnt := p1.count;
        end if;
--p('l_plan_rowcnt:'||l_plan_rowcnt);         
        if l_max_width < 50 then l_max_width:= 50; end if;
        etim(p_marker=>'Stat calc');
--^'||q'^         
        
        l_text:=null;   
        pr(l_max_width,l_stat_ln,'Metric             Value',                          'Metric             Value',    'Delta, %            Delta to ELA/EXEC, %');
        pr(l_max_width,l_stat_ln,'EXECS:             '||r_stats1.EXECUTIONS_DELTA,    'EXECS:             '||r_stats2.EXECUTIONS_DELTA,    round(100*((r_stats2.EXECUTIONS_DELTA-r_stats1.EXECUTIONS_DELTA)        /(case when r_stats1.EXECUTIONS_DELTA=0 then case when r_stats2.EXECUTIONS_DELTA=0 then 1 else r_stats2.EXECUTIONS_DELTA end else r_stats1.EXECUTIONS_DELTA end)),2)||'%');
        pr(l_max_width,l_stat_ln,'ELA/EXEC(MS):      '||r_stats1.ela_poe,             'ELA/EXEC(MS):      '||r_stats2.ela_poe,             round(100*((r_stats2.ela_poe-r_stats1.ela_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'LIO/EXEC:          '||r_stats1.LIO_poe,             'LIO/EXEC:          '||r_stats2.LIO_poe,             round(100*((r_stats2.LIO_poe-r_stats1.LIO_poe)                          /(case when r_stats1.LIO_poe=0 then case when r_stats2.LIO_poe=0 then 1 else r_stats2.LIO_poe end else r_stats1.LIO_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CPU/EXEC(MS):      '||r_stats1.CPU_poe,             'CPU/EXEC(MS):      '||r_stats2.CPU_poe,             rpad(round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                     /(case when r_stats1.CPU_poe=0 then case when r_stats2.CPU_poe=0 then 1 else r_stats2.CPU_poe end else r_stats1.CPU_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'IOWAIT/EXEC(MS):   '||r_stats1.IOWAIT_poe,          'IOWAIT/EXEC(MS):   '||r_stats2.IOWAIT_poe,          rpad(round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)               /(case when r_stats1.IOWAIT_poe=0 then case when r_stats2.IOWAIT_poe=0 then 1 else r_stats2.IOWAIT_poe end else r_stats1.IOWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CCWAIT/EXEC(MS):   '||r_stats1.CCWAIT_poe,          'CCWAIT/EXEC(MS):   '||r_stats2.CCWAIT_poe,          rpad(round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)               /(case when r_stats1.CCWAIT_poe=0 then case when r_stats2.CCWAIT_poe=0 then 1 else r_stats2.CCWAIT_poe end else r_stats1.CCWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'APWAIT/EXEC(MS):   '||r_stats1.APWAIT_poe,          'APWAIT/EXEC(MS):   '||r_stats2.APWAIT_poe,          rpad(round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)               /(case when r_stats1.APWAIT_poe=0 then case when r_stats2.APWAIT_poe=0 then 1 else r_stats2.APWAIT_poe end else r_stats1.APWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CLWAIT/EXEC(MS):   '||r_stats1.CLWAIT_poe,          'CLWAIT/EXEC(MS):   '||r_stats2.CLWAIT_poe,          rpad(round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)               /(case when r_stats1.CLWAIT_poe=0 then case when r_stats2.CLWAIT_poe=0 then 1 else r_stats2.CLWAIT_poe end else r_stats1.CLWAIT_poe end)),2)||'%',20,' ')||
            round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
         
        pr(l_max_width,l_stat_ln,'READS/EXEC:        '||r_stats1.reads_poe,           'READS/EXEC:        '||r_stats2.reads_poe,           round(100*((r_stats2.reads_poe-r_stats1.reads_poe)                      /(case when r_stats1.reads_poe=0 then case when r_stats2.reads_poe=0 then 1 else r_stats2.reads_poe end else r_stats1.reads_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'WRITES/EXEC:       '||r_stats1.dwrites_poe,         'WRITES/EXEC:       '||r_stats2.dwrites_poe,         round(100*((r_stats2.dwrites_poe-r_stats1.dwrites_poe)                  /(case when r_stats1.dwrites_poe=0 then case when r_stats2.dwrites_poe=0 then 1 else r_stats2.dwrites_poe end else r_stats1.dwrites_poe end)),2)||'%');      
         
        pr(l_max_width,l_stat_ln,'ROWS/EXEC:         '||r_stats1.Rows_poe,            'ROWS/EXEC:         '||r_stats2.Rows_poe,            round(100*((r_stats2.Rows_poe-r_stats1.Rows_poe)                        /(case when r_stats1.Rows_poe=0 then case when r_stats2.Rows_poe=0 then 1 else r_stats2.Rows_poe end else r_stats1.Rows_poe end)),2)||'%');
        pr(l_max_width,l_stat_ln,'ELA(SEC):          '||r_stats1.ELA_DELTA_SEC,       'ELA(SEC):          '||r_stats2.ELA_DELTA_SEC,       round(100*((r_stats2.ELA_DELTA_SEC-r_stats1.ELA_DELTA_SEC)              /(case when r_stats1.ELA_DELTA_SEC=0 then case when r_stats2.ELA_DELTA_SEC=0 then 1 else r_stats2.ELA_DELTA_SEC end else r_stats1.ELA_DELTA_SEC end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CPU(SEC):          '||r_stats1.CPU_DELTA_SEC,       'CPU(SEC):          '||r_stats2.CPU_DELTA_SEC,       round(100*((r_stats2.CPU_DELTA_SEC-r_stats1.CPU_DELTA_SEC)              /(case when r_stats1.CPU_DELTA_SEC=0 then case when r_stats2.CPU_DELTA_SEC=0 then 1 else r_stats2.CPU_DELTA_SEC end else r_stats1.CPU_DELTA_SEC end)),2)||'%');
  
        pr(l_max_width,l_stat_ln,'IOWAIT(SEC):       '||r_stats1.IOWAIT_DELTA_SEC,    'IOWAIT(SEC):       '||r_stats2.IOWAIT_DELTA_SEC,    round(100*((r_stats2.IOWAIT_DELTA_SEC-r_stats1.IOWAIT_DELTA_SEC)        /(case when r_stats1.IOWAIT_DELTA_SEC=0 then case when r_stats2.IOWAIT_DELTA_SEC=0 then 1 else r_stats2.IOWAIT_DELTA_SEC end else r_stats1.IOWAIT_DELTA_SEC end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CCWAIT(SEC):       '||r_stats1.CCWAIT_DELTA_SEC,    'CCWAIT(SEC):       '||r_stats2.CCWAIT_DELTA_SEC,    round(100*((r_stats2.CCWAIT_DELTA_SEC-r_stats1.CCWAIT_DELTA_SEC)        /(case when r_stats1.CCWAIT_DELTA_SEC=0 then case when r_stats2.CCWAIT_DELTA_SEC=0 then 1 else r_stats2.CCWAIT_DELTA_SEC end else r_stats1.CCWAIT_DELTA_SEC end)),2)||'%');
        pr(l_max_width,l_stat_ln,'APWAIT(SEC):       '||r_stats1.APWAIT_DELTA_SEC,    'APWAIT(SEC):       '||r_stats2.APWAIT_DELTA_SEC,    round(100*((r_stats2.APWAIT_DELTA_SEC-r_stats1.APWAIT_DELTA_SEC)        /(case when r_stats1.APWAIT_DELTA_SEC=0 then case when r_stats2.APWAIT_DELTA_SEC=0 then 1 else r_stats2.APWAIT_DELTA_SEC end else r_stats1.APWAIT_DELTA_SEC end)),2)||'%');
        pr(l_max_width,l_stat_ln,'CLWAIT(SEC):       '||r_stats1.CLWAIT_DELTA_SEC,    'CLWAIT(SEC):       '||r_stats2.CLWAIT_DELTA_SEC,    round(100*((r_stats2.CLWAIT_DELTA_SEC-r_stats1.CLWAIT_DELTA_SEC)        /(case when r_stats1.CLWAIT_DELTA_SEC=0 then case when r_stats2.CLWAIT_DELTA_SEC=0 then 1 else r_stats2.CLWAIT_DELTA_SEC end else r_stats1.CLWAIT_DELTA_SEC end)),2)||'%');
         
        pr(l_max_width,l_stat_ln,'READS:             '||r_stats1.DISK_READS_DELTA,    'READS:             '||r_stats2.DISK_READS_DELTA,    round(100*((r_stats2.DISK_READS_DELTA-r_stats1.DISK_READS_DELTA)        /(case when r_stats1.DISK_READS_DELTA=0 then case when r_stats2.DISK_READS_DELTA=0 then 1 else r_stats2.DISK_READS_DELTA end else r_stats1.DISK_READS_DELTA end)),2)||'%');
        pr(l_max_width,l_stat_ln,'DIR WRITES:        '||r_stats1.DISK_WRITES_DELTA,   'DIR WRITES:        '||r_stats2.DISK_WRITES_DELTA,   round(100*((r_stats2.DISK_WRITES_DELTA-r_stats1.DISK_WRITES_DELTA)      /(case when r_stats1.DISK_WRITES_DELTA=0 then case when r_stats2.DISK_WRITES_DELTA=0 then 1 else r_stats2.DISK_WRITES_DELTA end else r_stats1.DISK_WRITES_DELTA end)),2)||'%');      
   
        pr(l_max_width,l_stat_ln,'READ REQ:          '||r_stats1.PHY_READ_REQ_DELTA,  'READ REQ:          '||r_stats2.PHY_READ_REQ_DELTA,  round(100*((r_stats2.PHY_READ_REQ_DELTA-r_stats1.PHY_READ_REQ_DELTA)    /(case when r_stats1.PHY_READ_REQ_DELTA=0 then case when r_stats2.PHY_READ_REQ_DELTA=0 then 1 else r_stats2.PHY_READ_REQ_DELTA end else r_stats1.PHY_READ_REQ_DELTA end)),2)||'%');
        pr(l_max_width,l_stat_ln,'WRITE REQ:         '||r_stats1.PHY_WRITE_REQ_DELTA, 'WRITE REQ:         '||r_stats2.PHY_WRITE_REQ_DELTA, round(100*((r_stats2.PHY_WRITE_REQ_DELTA-r_stats1.PHY_WRITE_REQ_DELTA)  /(case when r_stats1.PHY_WRITE_REQ_DELTA=0 then case when r_stats2.PHY_WRITE_REQ_DELTA=0 then 1 else r_stats2.PHY_WRITE_REQ_DELTA end else r_stats1.PHY_WRITE_REQ_DELTA end)),2)||'%');      
   
         
        pr(l_max_width,l_stat_ln,'LIO:               '||r_stats1.BUFFER_GETS_DELTA,   'LIO:               '||r_stats2.BUFFER_GETS_DELTA,   round(100*((r_stats2.BUFFER_GETS_DELTA-r_stats1.BUFFER_GETS_DELTA)      /(case when r_stats1.BUFFER_GETS_DELTA=0 then case when r_stats2.BUFFER_GETS_DELTA=0 then 1 else r_stats2.BUFFER_GETS_DELTA end else r_stats1.BUFFER_GETS_DELTA end)),2)||'%');
        pr(l_max_width,l_stat_ln,'ROWS:              '||r_stats1.ROWS_PROCESSED_DELTA,'ROWS:              '||r_stats2.ROWS_PROCESSED_DELTA,round(100*((r_stats2.ROWS_PROCESSED_DELTA-r_stats1.ROWS_PROCESSED_DELTA)/(case when r_stats1.ROWS_PROCESSED_DELTA=0 then case when r_stats2.ROWS_PROCESSED_DELTA=0 then 1 else r_stats2.ROWS_PROCESSED_DELTA end else r_stats1.ROWS_PROCESSED_DELTA end)),2)||'%');
        pr(l_max_width,l_stat_ln,'LIO/ROW:           '||r_stats1.LIO_PER_ROW,         'LIO/ROW:           '||r_stats2.LIO_PER_ROW,         round(100*((r_stats2.LIO_PER_ROW-r_stats1.LIO_PER_ROW)                  /(case when r_stats1.LIO_PER_ROW=0 then case when r_stats2.LIO_PER_ROW=0 then 1 else r_stats2.LIO_PER_ROW end else r_stats1.LIO_PER_ROW end)),2)||'%');
        pr(l_max_width,l_stat_ln,'PIO/ROW:           '||r_stats1.IO_PER_ROW,          'PIO/ROW:           '||r_stats2.IO_PER_ROW,          round(100*((r_stats2.IO_PER_ROW-r_stats1.IO_PER_ROW)                    /(case when r_stats1.IO_PER_ROW=0 then case when r_stats2.IO_PER_ROW=0 then 1 else r_stats2.IO_PER_ROW end else r_stats1.IO_PER_ROW end)),2)||'%');
        pr(l_max_width,l_stat_ln,'AVG IO (MS):       '||r_stats1.awg_IO_tim,          'AVG IO (MS):       '||r_stats2.awg_IO_tim,          round(100*((r_stats2.awg_IO_tim-r_stats1.awg_IO_tim)                    /(case when r_stats1.awg_IO_tim=0 then case when r_stats2.awg_IO_tim=0 then 1 else r_stats2.awg_IO_tim end else r_stats1.awg_IO_tim end)),2)||'%');      
        pr(l_max_width,l_stat_ln,'IOWT/EXEC(MS)5ms:  '||r_stats1.io_wait_pe_5ms,      'IOWT/EXEC(MS)5ms:  '||r_stats2.io_wait_pe_5ms,      round(100*((r_stats2.io_wait_pe_5ms-r_stats1.io_wait_pe_5ms)            /(case when r_stats1.io_wait_pe_5ms=0 then case when r_stats2.io_wait_pe_5ms=0 then 1 else r_stats2.io_wait_pe_5ms end else r_stats1.io_wait_pe_5ms end)),2)||'%');      
        pr(l_max_width,l_stat_ln,'IOWAIT(SEC)5ms:    '||r_stats1.io_wait_5ms,         'IOWAIT(SEC)5ms:    '||r_stats2.io_wait_5ms,         round(100*((r_stats2.io_wait_5ms-r_stats1.io_wait_5ms)                  /(case when r_stats1.io_wait_5ms=0 then case when r_stats2.io_wait_5ms=0 then 1 else r_stats2.io_wait_5ms end else r_stats1.io_wait_5ms end)),2)||'%');      
         
--^'||q'^

        --Statistics comparison
        stim();
        p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Statistics comparison for '||l_sql_id,cname=>'stat_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
        p(HTF.BR);
        print_text_as_table(p_text=>l_text,p_t_header=>'#FIRST_LINE#',p_width=>800);
        p(HTF.BR);
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
        p(HTF.BR);
        if not l_embeded then
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
          p(HTF.BR);
        end if; --if not l_embeded then
        if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
        p(HTF.BR);
        etim();
        p(HTF.BR);          
         
        --Wait profile
        if not l_embeded then
        stim();
          p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Wait profile (approx), sec for '||l_sql_id,cname=>'wait_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
          p(HTF.BR);
          l_sql:=l_wait_profile;
          prepare_script_comp(l_sql, my_rec(a).dbid, my_rec(b).dbid, my_rec(a).start_snap, my_rec(a).end_snap, my_rec(b).start_snap, my_rec(b).end_snap);
          l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
          print_table_html(l_sql,800,'Wait profile');
          p(HTF.BR);
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
          p(HTF.BR);
          if not l_embeded then
            p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
            p(HTF.BR);      
          end if; --if not l_embeded then
          if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
          p(HTF.BR);
          etim();
          p(HTF.BR);  
        end if; --if not l_embeded then
         
 --^'||q'^        
 
        --ASH plan statistics
        if not l_embeded then
          stim();
          p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' ASH plan statistics '||l_sql_id,cname=>'ash_plan_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
          p(HTF.BR);
          if my_rec(a).plan_hash_value=0 or my_rec(b).plan_hash_value=0 then
            p('There is no plan available for PLAN_HASH=0.');
            p(HTF.BR);
          else 
            l_sql:=l_ash_plan;
            prepare_script_comp(l_sql, my_rec(a).dbid, my_rec(b).dbid, my_rec(a).start_snap, my_rec(a).end_snap, my_rec(b).start_snap, my_rec(b).end_snap);
            l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
            print_table_html(l_sql,1500,'ASH plan statistics');
          end if;
          p(HTF.BR);
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
          p(HTF.BR);
          if not l_embeded then
            p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
            p(HTF.BR);      
          end if; --if not l_embeded then
          if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
          p(HTF.BR);
          etim();
          p(HTF.BR);  
        end if; --if not l_embeded then
         
        --ASH time span
        if not l_embeded then
          stim();
          p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' ASH time span '||l_sql_id,cname=>'ash_span_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
          p(HTF.BR);
          l_sql:=l_ash_span;
          prepare_script_comp(l_sql, my_rec(a).dbid, my_rec(b).dbid, my_rec(a).start_snap, my_rec(a).end_snap, my_rec(b).start_snap, my_rec(b).end_snap);
          l_sql:=replace(replace(replace(l_sql,'&l_sql_id',l_sql_id),'&plan_hash1.',my_rec(a).plan_hash_value),'&plan_hash2.',my_rec(b).plan_hash_value);
          print_table_html(l_sql,1500,'ASH time span');
          p(HTF.BR);
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
          p(HTF.BR);
          etim();
        end if; --if not l_embeded then
        if not l_embeded then
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
          p(HTF.BR);      
        end if; --if not l_embeded then
        if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
        p(HTF.BR);
        p(HTF.BR);    
         
--^'||q'^
        
        --plans
        stim();
        l_text:=null; 
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
        end if;
--p('l_plan_rowcnt:'||l_plan_rowcnt);      
        <<print_plan_comparison>>
        for j in 1 .. l_plan_rowcnt loop
        
          if p2.exists(j) and not l_single_plan then
            r2 := p2(j);
          else
            r2 := null;
          end if;        
          if p1.exists(j) then
            r1:=rpad(nvl(rtrim(replace(p1(j),chr(9),' ')),' '), l_max_width, ' ');
          else
            if r2 is not null then
              r1 := rpad(' ', l_max_width, ' ');
            end if;
          end if;

          if l_single_plan then
            pr2(r1 || '*', '*');
          else
            if REGEXP_REPLACE(trim(ltrim(r1,'.')),'\s+','')=REGEXP_REPLACE(trim(r2),'\s+','') or (trim(TRANSLATE(r1,'-',' ')) is null and trim(TRANSLATE(r2,'-',' ')) is null) then
              pr2(r1 || '+' || r2, '+');
            else
              --coloring different words
              if r2 is not null then
                to_table_for_comparison(r1,l_tab1,l_s_tag,l_e_tag);
                to_table_for_comparison(r2,l_tab2,l_s_tag,l_e_tag);
                l_max_ind:=greatest(l_tab1.count,l_tab2.count);
                for q in 1..l_max_ind loop
                  if l_tab1.exists(q) and l_tab2.exists(q) then               
                    if nvl(l_tab1(q),'#$%')<>nvl(l_tab2(q),'#$%') then
--p('-----------------------------');
--p(q);
--p('l_tab1(q):'||l_tab1(q));p('r1 1:'||r1);
--p('l_tab2(q):'||l_tab2(q));p('r2 1:'||r2);                        
--if q=1 then p('TRANSLATE l_tab1(q):'||trim(TRANSLATE(replace(replace(l_tab1(q),l_s_tag),l_e_tag),'-',' '))); end if;
                      if l_tab1(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null
                      then
                        r1:=replace(r1,l_tab1(q),l_fst1||replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
--p('r1 2:'||r1);                   
                      end if;   
--if q=1 then p('TRANSLATE l_tab2(q):'||trim(TRANSLATE(replace(replace(l_tab2(q),l_s_tag),l_e_tag),'-',' '))); end if;                
                      if l_tab2(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null 
                      then
                        r2:=replace(r2,l_tab2(q),l_fst1||replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
--p('r2 2:'||r2);                       
                      end if;
                    end if;
                  end if;
                  if l_tab1.exists(q) and not l_tab2.exists(q) then
                    if l_tab1(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null 
                    then
                      r1:=replace(r1,l_tab1(q),l_fst1||replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
                    end if;              
                  end if;
                  if not l_tab1.exists(q) and l_tab2.exists(q) then
                    if l_tab2(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null 
                    then
                      r2:=replace(r2,l_tab2(q),l_fst1||replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
                    end if;              
                  end if;  
                end loop;   
                for q in 1..l_max_ind loop
                  r1 := replace(replace(replace(r1,'~`'||q||'`~'),l_s_tag),l_e_tag);                  
                  r2 := replace(replace(replace(r2,'~`'||q||'`~'),l_s_tag),l_e_tag);   
                end loop;               
              end if; 
              pr2(r1 || case when r2 is null then '*' else '-' || r2 end, case when r2 is null then '*' else '-' end);
            end if;
          end if;
        end loop print_plan_comparison;

--^'||q'^         

        --Plans comparison
        p(HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>' Plans comparison for '||l_sql_id,cname=>'pl_'||a||'_'||b||'_'||l_sql_id,cattributes=>'class="awr"'),cattributes=>'class="awr"'));
        p(HTF.BR);  
--p('l_max_width:'||l_max_width);		
        print_text_as_table(p_text => l_text, p_t_header => '', p_width => 3000, p_comparison => true);
        p(HTF.BR);
        p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#cmp_'||a||'_'||b||'_'||l_sql_id,ctext=>'Back to current comparison start',cattributes=>'class="awr"')));
        p(HTF.BR);
        if not l_embeded then        
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_sql_id,ctext=>'Back to SQL: '||l_sql_id,cattributes=>'class="awr"')));
          p(HTF.BR);
          if l_next_sql_id is not null then p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#sql_'||l_next_sql_id,ctext=>'Goto next SQL: '||l_next_sql_id,cattributes=>'class="awr"'))); end if;
          p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
          p(HTF.BR);
          p(HTF.BR);          
        end if; --if not l_embeded then          
        etim();
        l_pair_num:=l_pair_num+1;
      end loop comp_inner;
    end loop comp_outer;
  end loop query_list_loop;
  stim(); 
  if l_single_sql_report=0 then   
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
    prepare_script_comp(l_noncomp, l_dbid1, l_dbid2, l_start_snap1, l_end_snap1, l_start_snap2, l_end_snap2);
    print_table_html(l_noncomp,2000,'Non-comparable queries');
    p(HTF.BR);
    p(HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
    p(HTF.BR);
    p(HTF.BR);   
  end if; --l_single_sql_report=0
  etim(true);
  if not l_embeded then    
    p('End of Report');
    p((HTF.BODYCLOSE));
    p((HTF.HTMLCLOSE));
  end if;  --if not l_embeded then 
end;