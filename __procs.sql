  g_min number;
  g_max number;

procedure p(p_msg varchar2) is begin dbms_output.put_line(p_msg); end;
procedure prepare_script(p_script in out clob, p_sqlid varchar2, p_plsql boolean default false, p_dbid varchar2 default null, p_inst_id varchar2 default null) is 
  l_scr clob := p_script;
  l_line varchar2(32765);
  l_eof number;
  l_iter number := 1;
begin
  if instr(l_scr,chr(10))=0 then 
    l_scr:=l_scr||chr(10);
    --raise_application_error(-20000,'Put at least one EOL into script.');
  end if;
  --set variable
  p_script:=replace(replace(replace(replace(replace(p_script,'&SQLID.',p_sqlid),'&SQLID',p_sqlid),'&1.',p_sqlid),'&1',p_sqlid),'&VSQL.','gv$sql'); 
  p_script:=replace(replace(replace(replace(p_script,'&INST_ID.',p_inst_id),'&INST_ID',p_inst_id),'&DBID.',p_dbid),'&DBID',p_dbid); 
  --remove sqlplus settings
  l_scr := p_script;
  p_script:=null;
  loop
    l_eof:=instr(l_scr,chr(10));
    l_line:=substr(l_scr,1,l_eof);
    
    if upper(l_line) like 'SET%' or 
       upper(l_line) like 'COL%' or
       upper(l_line) like 'BREAK%' or
       upper(l_line) like 'ALTER SESSION%' or
       upper(l_line) like 'SERVEROUTPUT%' or
       upper(l_line) like 'REM%' or
       upper(l_line) like '--%' 
    then
      null;
    else
      p_script:=p_script||l_line||chr(10);
    end if;
    
    if p_dbid is not null then
      if g_min is null or g_max is null then
        select nvl(min(snap_id),1) , nvl(max(snap_id),1e6)  into g_min, g_max from dba_hist_sqlstat where sql_id=p_sqlid and dbid=p_dbid;
      end if;
      p_script:=replace(replace(p_script,'&start_sn.',g_min),'&end_sn.',g_max);
    end if;
    
    l_scr:=substr(l_scr,l_eof+1);
    l_iter:=l_iter+1;
    exit when l_iter>1000 or dbms_lob.getlength(l_scr)=0;
  end loop;
  if not p_plsql then p_script:=replace(p_script,';'); end if;
end;

procedure print_table_html(p_query in varchar2, 
                           p_width number, 
                           p_summary varchar2, 
                           p_search varchar2 default null, 
                           p_replacement varchar2 default null, 
                           p_style1 varchar2 default 'awrc1', 
                           p_style2  varchar2 default 'awrnc1',
                           p_header number default 0,
                           p_break_col varchar2 default null) is
  l_theCursor   integer default dbms_sql.open_cursor;
  l_columnValue varchar2(32767);
  l_status      integer;
  l_descTbl     dbms_sql.desc_tab2;
  l_colCnt      number;
  l_rn          number := 0;
  l_style       varchar2(100);
  l_break_value varchar2(4000) := null;
  l_break_cnt   number := 1;
begin
  p(HTF.TABLEOPEN(cborder=>0,cattributes=>'width="'||p_width||'" class="tdiff" summary="'||p_summary||'"'));

  dbms_sql.parse(l_theCursor, p_query, dbms_sql.native);
  dbms_sql.describe_columns2(l_theCursor, l_colCnt, l_descTbl);

  for i in 1 .. l_colCnt loop
    dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
  end loop;

  l_status := dbms_sql.execute(l_theCursor);

  --column names
  p(HTF.TABLEROWOPEN);
  for i in 1 .. l_colCnt loop
    p(HTF.TABLEHEADER(cvalue=>l_descTbl(i).col_name,calign=>'left',cattributes=>'class="awrbg" scope="col"'));
  end loop;
  p(HTF.TABLEROWCLOSE);

  while (dbms_sql.fetch_rows(l_theCursor) > 0) loop
    p(HTF.TABLEROWOPEN);
    l_rn := l_rn + 1;
    --coloring for rows for breaking column value
    if p_break_col is null then
      l_style := case when mod(l_rn,2)=0 then p_style1 else p_style2 end;
    else
      for i in 1 .. l_colCnt loop
        dbms_sql.column_value(l_theCursor, i, l_columnValue);
      
        if p_break_col is not null and upper(p_break_col)=upper(l_descTbl(i).col_name) then
          if nvl(l_break_value,'^~') <> nvl(l_columnValue,'^~') then
            l_break_value:=l_columnValue;
            l_break_cnt:=l_break_cnt+1;
          end if;
        end if;      
      
        if p_break_col is not null then
          l_style := case when mod(l_break_cnt,2)=0 then p_style1 else p_style2 end;
        end if; 
      end loop;
    end if;    
    -----------------------------------------------------------------------------
    for i in 1 .. l_colCnt loop
      dbms_sql.column_value(l_theCursor, i, l_columnValue);
      
      l_columnValue:=replace(replace(l_columnValue,chr(13)||chr(10),chr(10)||'<br/>'),chr(10),chr(10)||'<br/>');
      if p_search is not null then
        if instr(l_descTbl(i).col_name,p_search)>0 then
          l_columnValue:=REGEXP_REPLACE(l_columnValue,'(.*)',p_replacement);
          p(HTF.TABLEDATA(cvalue=>l_columnValue,calign=>'left',cattributes=>'class="'|| l_style ||'"'));
        elsif regexp_instr(l_columnValue,p_search)>0 then
          l_columnValue:=REGEXP_REPLACE(l_columnValue,p_search,p_replacement);
          p(HTF.TABLEDATA(cvalue=>l_columnValue,calign=>'left',cattributes=>'class="'|| l_style ||'"'));
        else
          p(HTF.TABLEDATA(cvalue=>replace(l_columnValue,'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"'));
        end if;
      else
        p(HTF.TABLEDATA(cvalue=>replace(l_columnValue,'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"'));
      end if;
    end loop;
    p(HTF.TABLEROWCLOSE);
    if p_header > 0 then
      if mod(l_rn,p_header)=0 then
        p(HTF.TABLEROWOPEN);
        for i in 1 .. l_colCnt loop
          p(HTF.TABLEHEADER(cvalue=>l_descTbl(i).col_name,calign=>'left',cattributes=>'class="awrbg" scope="col"'));
        end loop;
        p(HTF.TABLEROWCLOSE);
      end if;
    end if;
  end loop;
  dbms_sql.close_cursor(l_theCursor);
  p(HTF.TABLECLOSE);
exception
  when others then   
    if DBMS_SQL.IS_OPEN(l_theCursor) then dbms_sql.close_cursor(l_theCursor);end if;
    p(p_query);
    raise_application_error(-20000, 'print_table_html'||chr(10)||sqlerrm||chr(10));
end;
    
procedure print_text_as_table(p_text clob, p_t_header varchar2,p_width number, p_search varchar2 default null, p_replacement varchar2 default null) is
  l_line varchar2(32765);  l_eof number;  l_iter number; l_length number;
  l_text clob;
begin
  p(HTF.TABLEOPEN(cborder=>0,cattributes=>'width="'||p_width||'" class="tdiff" summary="'||p_t_header||'"'));
  if p_t_header<>'#FIRST_LINE#' then
    p(HTF.TABLEROWOPEN);
    p(HTF.TABLEHEADER(cvalue=>replace(p_t_header,' ','&nbsp;'),calign=>'left',cattributes=>'class="awrbg" scope="col"'));
    p(HTF.TABLEROWCLOSE);
  end if;
  
  if instr(p_text,chr(10))=0 then
    l_iter := 1;
    l_length:=dbms_lob.getlength(p_text);
    loop
      l_text := l_text||substr(p_text,l_iter,200)||chr(10);
      l_iter:=l_iter+200;
      exit when l_iter>=l_length;
    end loop;
  else
    l_text := p_text||chr(10);
  end if;
  
  l_iter := 1; 
  loop
    l_eof:=instr(l_text,chr(10));
    l_line:=substr(l_text,1,l_eof);
    if p_t_header='#FIRST_LINE#' and l_iter = 1 then
      p(HTF.TABLEROWOPEN);
      p(HTF.TABLEHEADER(cvalue=>replace(l_line,' ','&nbsp;'),calign=>'left',cattributes=>'class="awrbg" scope="col"'));
      p(HTF.TABLEROWCLOSE);
    else
      p(HTF.TABLEROWOPEN);
      if p_search is not null and regexp_instr(l_line,p_search)>0 then
        l_line:=REGEXP_REPLACE(l_line,p_search,p_replacement);
        p(HTF.TABLEDATA(cvalue=>l_line,calign=>'left',cattributes=>'class="'|| case when mod(l_iter,2)=0 then 'awrc1' else 'awrnc1' end ||'"'));
      else
        p(HTF.TABLEDATA(cvalue=>replace(l_line,' ','&nbsp;'),calign=>'left',cattributes=>'class="'|| case when mod(l_iter,2)=0 then 'awrc1' else 'awrnc1' end ||'"'));
      end if;
      p(HTF.TABLEROWCLOSE);
    end if;
    l_text:=substr(l_text,l_eof+1);  l_iter:=l_iter+1;
    exit when l_iter>1000 or dbms_lob.getlength(l_text)=0;
  end loop;

  p(HTF.TABLECLOSE);
end;