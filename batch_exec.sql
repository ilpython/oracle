---单表批量更新字段
方法1：
set serveroutput on
DECLARE
  CURSOR CUR IS
    SELECT ROWID AS ROW_ID FROM APP.BIG_TABLE ;
  V_COUNTER NUMBER;
BEGIN
  V_COUNTER := 0;
  FOR ROW IN CUR LOOP
    update app.big_table set subobject_name=owner where rowid = row.row_id;
    V_COUNTER := V_COUNTER + 1;
    IF (V_COUNTER >= 10000) THEN
      dbms_output.put_line('update:'||V_COUNTER);
      COMMIT;
      V_COUNTER := 0;
    END IF;
  END LOOP;
  COMMIT;
END;
/

方法2：
declare
maxrows number default 10000;
v_rowid dbms_sql.Urowid_Table;
v_owner dbms_sql.varchar2_table;
v_object_name dbms_sql.varchar2_table;
cursor cur_t2 is
select /*+ parallel(T1,16) */ t1.object_name,T1.rowid row_id from app.big_table t1 order by T1.rowid;
v_counter number;
begin
v_counter := 0;
open cur_t2;
LOOP
EXIT WHEN cur_t2%NOTFOUND;
FETCH cur_t2 bulk collect into v_object_name,v_rowid limit maxrows;
forall i in 1 .. v_rowid.count
update app.big_table set subobject_name='TAB_'||substr(v_object_name(i),2,8) where rowid=v_rowid(i);
commit;
end loop;
end;
/

---两表更新
declare
maxrows number default 10000;
v_rowid dbms_sql.Urowid_Table;
v_owner dbms_sql.varchar2_table;
v_object_name dbms_sql.varchar2_table;
cursor cur_t2 is
select /*+ use_hash(T1,T2) parallel(T1,16) */
T2.owner, T2.object_name,T1.rowid row_id
from app.big_table t1, dba_objects T2
where T1.object_id=T2.object_id
order by T1.rowid;
v_counter number;
begin
v_counter := 0;
open cur_t2;
LOOP
EXIT WHEN cur_t2%NOTFOUND;
FETCH cur_t2 bulk collect into v_owner,v_object_name,v_rowid limit maxrows;
forall i in 1 .. v_rowid.count
update app.big_table set subobject_name=v_owner(i)||'-'||substr(v_object_name(i),2,8) where rowid=v_rowid(i);
commit;
end loop;
end;
/

----批量删除
declare  
   cursor mycursor is SELECT  ROWID FROM app.big_table where subobject_name like '%SYS%' order by rowid;
   type rowid_table_type is  table  of rowid index by pls_integer;
   v_rowid   rowid_table_type;
BEGIN
   open mycursor;
   loop
     fetch   mycursor bulk collect into v_rowid  limit 5000;
     exit when v_rowid.count=0;
     forall i in v_rowid.first..v_rowid.last
        delete from app.big_table where rowid=v_rowid(i);
     commit;
   end loop;
   close mycursor;
END;
/


-------------
-----insert
declare
TYPE ARRAY IS TABLE OF big_table%ROWTYPE;
l_data ARRAY;
CURSOR c IS SELECT * FROM big_table;
BEGIN
    OPEN c;
    LOOP
    FETCH c BULK COLLECT INTO l_data LIMIT 5000;
   
    FORALL i IN 1..l_data.COUNT
    INSERT /*+append*/ INTO big_table VALUES l_data(i);
    commit;
    EXIT WHEN c%NOTFOUND;
    END LOOP;
    CLOSE c;

-----delete
DECLARE  
 CURSOR mycursor IS SELECT rowid FROM t WHERE OO=XX ;  
 TYPE rowid_table_type IS TABLE OF rowid index  by  pls_integer;  
 v_rowid rowid_table_type;  
BEGIN  
  OPEN mycursor;  
  LOOP  
    FETCH mycursor BULK COLLECT INTO v_rowid LIMIT 5000;  
    EXIT WHEN v_rowid.count=0;  
    FORALL i IN v_rowid.FIRST..v_rowid.LAST  
      DELETE t WHERE rowid=v_rowid(i);  
    COMMIT;  
  END LOOP;  
  CLOSE mycursor;  
END;  
/  

-----update
DECLARE  
 CURSOR mycursor IS SELECT t_pk FROM t WHERE OO=XX ;  
 TYPE num_tab_t IS TABLE OF NUMBER(38);
 pk_tab NUM_TAB_T;
BEGIN  
  OPEN mycursor;  
  LOOP  
    FETCH mycursor BULK COLLECT INTO pk_tab LIMIT 5000;  
    EXIT WHEN pk_tab.count=0;  
    FORALL i IN pk_tab.FIRST..v_rowid.LAST  
      UPDATE t
            SET    name=name||’bulk’
            WHERE  t_pk = pk_tab(i);
    COMMIT;  
  END LOOP;  
  CLOSE mycursor;  
END;  
/  
