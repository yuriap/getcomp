Rem
rem    Script:         getcomph.sql
rem    Author:         Iurii Pedan
rem    Dated:          July 2016
Rem
Rem    NAME
Rem      getcomph.sql - Compare execution plans from different sets of AWR snapshots
Rem
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    pedany      11/6/17 - version 2.0
Rem                          HTML report format is only supported from this time
Rem
 

set pages 9999
set lines 2000
set trimspool on
set termout off
set echo off
set feedback off
set timing off
set verify off

alter session set nls_numeric_characters='. ';

@comp_params.sql
whenever sqlerror exit failure
spool getcomp_err.txt
declare
  l_cnt number;
begin
  if '&dblnk.' is not null then
    select count(1) into l_cnt from user_db_links where instr('@'||DB_LINK,upper('&dblnk.'))>0;
	if l_cnt=0 then 
	  raise_application_error(-20000, 'No database link <&dblnk.> found.');
	end if;
  end if;
end;
/
spool off
whenever sqlerror continue

set serveroutput on 

set define ~

spool getcomp.html

@_getcomph
/

spool off
set termout on
set verify on
set timing on


set define &

set serveroutput off