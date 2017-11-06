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
set termout on
set echo off
set feedback off
set timing off
set verify off

alter session set nls_numeric_characters='. ';

@comp_params.sql

set serveroutput on 

set define ~

spool getcomp.html

@_getcomph

spool off
set termout on
set verify on
set timing on


set define &