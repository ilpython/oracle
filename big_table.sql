-- for 10g
--==============================================
-- Create a test table for Oracle 10g
-- File : cr_big_tb_10g.sql
-- Author : Robinson
--==============================================
  
prompt
prompt Create a big table from all_objects
prompt ======================================
CREATE TABLE big_table
AS
SELECT ROWNUM id, a.*
FROM all_objects a
WHERE 1=0;
   
prompt
prompt Modify table to nologgming mode
prompt ==========================
ALTER TABLE big_table NOLOGGING;
   
prompt
prompt Please input rows number to fill into big_table
prompt ============================================
DECLARE
        l_cnt NUMBER;
        l_rows NUMBER := &1;
BEGIN
        INSERT /*+ append */
        INTO big_table
                SELECT rownum, a.*
                FROM all_objects a;
        l_cnt := SQL%ROWCOUNT;
        COMMIT;
        WHILE (l_cnt < l_rows)
        LOOP
                INSERT /*+ APPEND */
                INTO big_table
                        SELECT rownum + l_cnt
                             ,owner
                             ,object_name
                             ,subobject_name
                             ,object_id
                             ,data_object_id
                             ,object_type
                             ,created
                             ,last_ddl_time
                             ,TIMESTAMP
                             ,status
                             ,temporary
                             ,generated
                             ,secondary
                        FROM big_table
                        WHERE rownum <= l_rows - l_cnt;
                l_cnt := l_cnt + SQL%ROWCOUNT;
                COMMIT;
        END LOOP;
END;
/
   
prompt
prompt Add primary key for big table
prompt =====================================
ALTER TABLE big_table ADD CONSTRAINT
big_table_pk PRIMARY KEY (id);
   
prompt
prompt Gather statistics for big_table
prompt =====================================
BEGIN
        dbms_stats.gather_table_stats(ownname => USER,
                                     tabname => 'BIG_TABLE',
                                     method_opt => 'for all indexed columns',
                                     cascade => TRUE);
END;
/
   
prompt
prompt check total rows for big_table
prompt ====================================

SELECT COUNT(*) FROM big_table;


--- for 11g
--==============================================
-- Create a test table for Oracle 11g
-- File : cr_big_tb_11g.sql
-- Author : Robinson
--==============================================
  
prompt
prompt Create a big table from all_objects
prompt ======================================
CREATE TABLE big_table
AS
SELECT ROWNUM id, a.*
FROM all_objects a
WHERE 1=0;
   
prompt
prompt Modify table to nologgming mode
prompt ==========================
ALTER TABLE big_table NOLOGGING;
   
prompt
prompt Please input rows number to fill into big_table
prompt ============================================
DECLARE
        l_cnt NUMBER;
        l_rows NUMBER := &1;
BEGIN
        INSERT /*+ append */
        INTO big_table
                SELECT rownum, a.*
                FROM all_objects a;
        l_cnt := SQL%ROWCOUNT;
        COMMIT;
        WHILE (l_cnt < l_rows)
        LOOP
                INSERT /*+ APPEND */
                INTO big_table
                        SELECT rownum + l_cnt
                             ,owner
                             ,object_name
                             ,subobject_name
                             ,object_id
                             ,data_object_id
                             ,object_type
                             ,created
                             ,last_ddl_time
                             ,TIMESTAMP
                             ,status
                             ,temporary
                             ,generated
                             ,secondary
                             ,namespace
                             ,edition_name
                        FROM big_table
                        WHERE rownum <= l_rows - l_cnt;
                l_cnt := l_cnt + SQL%ROWCOUNT;
                COMMIT;
        END LOOP;
END;
/
   
prompt
prompt Add primary key for big table
prompt =====================================
ALTER TABLE big_table ADD CONSTRAINT
big_table_pk PRIMARY KEY (id);
   
prompt
prompt Gather statistics for big_table
prompt =====================================
BEGIN
        dbms_stats.gather_table_stats(ownname => USER,
                                     tabname => 'BIG_TABLE',
                                     method_opt => 'for all indexed columns',
                                     cascade => TRUE);
END;
/
   
prompt
prompt check total rows for big_table
prompt ====================================

SELECT COUNT(*) FROM big_table;

--说明
1、该脚本根据Tom大师的原代码big_table整理而成。
2、Oracle 11g all_objects 比Oracle 10g 多出两列，因此使用了2个不同的版本。
3、big_table的id列为唯一值，并在之上创建了primary key。 
