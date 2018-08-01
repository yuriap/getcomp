--local schema
create database link DBAWR1 connect to scott identified by qazwsx using 'localhost:1521/db12r102';
--remote sysdba
grant execute on dbms_session to scott;
GRANT CREATE ANY CONTEXT TO scott;
--remote schema
CREATE OR REPLACE CONTEXT remote_awr_xplan_ctx USING remote_awr_xplan_init;
create or replace procedure remote_awr_xplan_init(p_sql_id varchar2, p_plan_hash varchar2, p_dbid varchar2)
is
begin
  DBMS_SESSION.set_context('remote_awr_xplan_ctx', 'sql_id' , p_sql_id);          
  DBMS_SESSION.set_context('remote_awr_xplan_ctx', 'plan_hash' , p_plan_hash);   
  DBMS_SESSION.set_context('remote_awr_xplan_ctx', 'dbid' , p_dbid);   
end;
/
create or replace view remote_awr_plan as
select plan_table_output 
from table(dbms_xplan.display_awr(SYS_CONTEXT('remote_awr_xplan_ctx', 'sql_id'), 
                                  SYS_CONTEXT('remote_awr_xplan_ctx', 'plan_hash'), 
                                  SYS_CONTEXT('remote_awr_xplan_ctx', 'dbid'), 'ADVANCED -ALIAS'));
								  
create or replace view remote_awr_plan as
select plan_table_output 
from table(dbms_xplan.display_workload_repository(sql_id          => SYS_CONTEXT('remote_awr_xplan_ctx', 'sql_id'), 
                                                  plan_hash_value => SYS_CONTEXT('remote_awr_xplan_ctx', 'plan_hash'), 
                                                  dbid            => SYS_CONTEXT('remote_awr_xplan_ctx', 'dbid'), 
                                                  con_dbid        => SYS_CONTEXT('remote_awr_xplan_ctx', 'dbid'), 
                                                  format          => 'ADVANCED -ALIAS',
                                                  awr_location=>'AWR_PDB')
                                                  );