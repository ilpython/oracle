授权
SQL> grant select_catalog_role to app;

保存rowid信息
create table t_test_split as select /*+parallel(4)*/rowid sou_rowid,rownum rn,(select current_scn from v$database) scn from big_table;

A.批量导出部分
#----------------------------------------------------------

1.生成环境配置信息
#vi expdp_env_conf.sh
#!/bin/bash
. ~/.bash_profile
#############set var################
#导出路径
expdp_dir=pump_dir
#实例名
oracle_sid=orcl
#大字段表所属用户
owner=app
#大字段表名
table_name=big_table
#第一步创建的中间表
mid_tab_name=t_test_split
#数据拆分的份数
split_count=10
#并发进程数(无需和数据拆分份数相同，如可将数据拆分成100份，但导出进程最大并发10个
#做完一批在做下一批)
parallel=10
#############set var################

export ORACLE_SID=${oracle_sid}
#define func
#编写一个传入一个SQL，返回SQL查询结果的函数
function getValueBySQL()
{
val=`sqlplus -s / as sysdba<< EOF
set heading off;
set pagesize 0;
set feedback off;
set verify off;
set echo off;
$1;
exit;
EOF`
echo "${val}"
}
#获得实际导数路径
expdp_real_dir=`getValueBySQL "select DIRECTORY_PATH from dba_directories where DIRECTORY_NAME = upper('${expdp_dir}')"`
#每份数据包含多少行数据，如100万行数据分成10份，每份就是10万行
per_cnt=`getValueBySQL "select ceil(count(*)/${split_count}) from ${owner}.${mid_tab_name}"`
#获得SCN号
scn=`getValueBySQL "select to_char(scn) from ${owner}.${mid_tab_name} where rownum=1"`

2.导出主脚本
#!/bin/sh
#初始化环境变量
. ~/.bash_profile
. ./expdp_env_conf.sh
#开始导出数据
echo "`date "+%Y%m%d %T"` expdp data start"

split_num=0
while [[ ${split_num} -lt ${split_count} ]]
do
#查看有没有导出进程，最大只允许发起环境变量中定义的paralle个导出进程
para_cnt=`ps -ef|grep expdp|grep -v ".sh"|grep -v grep|wc -l`
if [ ${para_cnt} -lt ${parallel} ]; then
#del par file
if [ -f  "${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.par" ]; then
rm -f ${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.par
fi
#create par file
cat>${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.par<<eof
USERID=' / as sysdba'
DIRECTORY=${expdp_dir}
CONTENT=DATA_ONLY
CLUSTER=N
DUMPFILE=expdp_big_tab_${table_name}_${split_num}.dmp
LOGFILE=expdp_big_tab_${table_name}_${split_num}.log
TABLES=${owner}.${table_name}
FLASHBACK_SCN=${scn}
QUERY='${owner}.${table_name}:"where rowid in (select sou_rowid from ${owner}.${mid_tab_name} where rn between (${split_num}*${per_cnt}+1) and (${split_num}+1)*${per_cnt})"'
eof
#del dmp file
if [ -f "${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.dmp" ]; then
rm -f ${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.dmp
fi
#exec expdp
par_file=${expdp_real_dir}/expdp_big_tab_${table_name}_${split_num}.par
#这里必须要创建一个子shell，不然无法实现并发导数，如果不创建子shell，直接在主进程拉起导数，则主shell进程需要等待当前发起的导数命令完成才会继续往下执行从而循环发起其他导数进程
sh expdp_exec.sh ${par_file} &
#exec expdp don't build process immediate.It will not be accurate when exec "ps -ef|grep expdp". so sleep 2s;
sleep 2
let "split_num += 1"
else
sleep 10
fi
done
echo "`date "+%Y%m%d %T"` expdp data done"

3.导出子脚本
#!/bin/sh
. ./expdp_env_conf.sh
par_file=$1
expdp parfile=${par_file}
#每一个导数子进程完成以后生成一个.done后缀的文件，用来告诉导入进程导出已完成，导入进程可以做导入了
done_file_name=`ls "${par_file}"|sed 's/.par/.done/g'`
cat /dev/null>${done_file_name}

4.执行导出
nohup sh expdp_lob_tab.sh>expdp_lob_tab.sh.out &

B.批量导入部分
#----------------------------------------------------------

1.生成环境配置信息
#cat impdp_env_conf.sh
#!/bin/sh
. ~/.bash_profile
#set var
#imp directory
impdp_dir=pump_dir
oracle_sid=orcl
owner=scott
table_name=big_table
split_count=10
#导入时是无法并行的，当一个导入进程发起后，其他导入进程会等待获取表锁，这里设置为2即可
parallel=2

export ORACLE_SID=${oracle_sid}
#define func
#select value by sql
function getValueBySQL()
{
val=`sqlplus -s / as sysdba<< EOF
set heading off
set pagesize 0;
set feedback off;
set verify off;
set echo off;
$1;
exit;
EOF`
echo "${val}"
}

impdp_real_dir=`getValueBySQL "select DIRECTORY_PATH from dba_directories where DIRECTORY_NAME = upper('${impdp_dir}')"`
home_dir=`pwd`

2.导入主脚本
#!/bin/sh
. ./impdp_env_conf.sh

echo "`date "+%Y%m%d %T"` impdp data start"

split_num=0
while [[ ${split_num} -lt ${split_count} ]]
do
cd ${impdp_real_dir}
para_cnt=`ps -ef|grep impdp|grep -v ".sh"|grep -v grep|wc -l`
if [ ${para_cnt} -lt ${parallel} ]; then
impdp_file=`ls *.done 2>/dev/null|head -1|sed 's/.done/.dmp/g'`
if [ -f "${impdp_file}" ]; then
par_file=`ls ${impdp_file}|sed 's/expdp_/impdp_/g'|sed 's/.dmp/.par/g'`
log_file=`ls ${impdp_file}|sed 's/expdp_/impdp_/g'|sed 's/.dmp/.log/g'`
#del par file
if [ -f "${par_file}" ]; then
rm -f ${par_file}
fi
#create par file
cat>${par_file}<<eof
USERID=' / as sysdba'
DIRECTORY=${impdp_dir}
CONTENT=DATA_ONLY  <<<<根据实际情况修改
DUMPFILE=${impdp_file}
LOGFILE=${log_file}
TABLE_EXISTS_ACTION = APPEND
REMAP_SCHEMA=app:scott	<<<<根据实际情况修改
REMAP_TABLESPACE=tbs_app:example	<<<<根据实际情况修改
eof
#exec impdp
cd ${home_dir}
sh impdp_exec.sh ${par_file} &
#exec impdp don't build process immediate.It will not be accurate when exec "ps -ef|grep impdp". so sleep 2s;
sleep 2
let "split_num += 1"
else
echo "waiting for expdp data done"
sleep 10
fi
else
sleep 10
fi
done
echo "`date "+%Y%m%d %T"` impdp data done"

3.导入子脚本
#!/bin/sh
. ./impdp_env_conf.sh
par_file=$1
cd ${impdp_real_dir}
#导入过程中将导出已完成的子进程标记文件改名为.done.impdping的后缀文件，以免重复导入
exp_done_file_name=`ls "${par_file}"|sed 's/impdp_/expdp_/g'|sed 's/.par/.done/g'`
imping_file_name=`ls "${par_file}"|sed 's/impdp_/expdp_/g'|sed 's/.par/.done.impdping/g'`
mv ${exp_done_file_name} ${imping_file_name}
impdp parfile=${par_file}
#导入完成以后将导入过程中的标记文件改名为.done.impdp.finish，用来标记导入已完成
imp_done_file_name=`ls "${par_file}"|sed 's/impdp_/expdp_/g'|sed 's/.par/.done.impdp.finish/g'`
mv ${imping_file_name} ${imp_done_file_name}

4.正式导入
nohup sh impdp_big_tab.sh>impdp_big_tab.sh.out &

---含有lob字段的大表要评估导出前数据需要的表空间大小。
SELECT owner,SUM(D.initial_extent)/1024/1024 initial_extent FROM DBA_SEGMENTS D,dba_lobs l where D.SEGMENT_NAME=L.SEGMENT_NAME and D.OWNER='&user' and D.SEGMENT_NAME='&table';

---大表切片
SELECT rownum || ', ' || ' rowid between ' || chr(39) ||
       dbms_rowid.rowid_create(1, DOI, lo_fno, lo_block, 0) || chr(39) ||
       ' and  ' || chr(39) ||
       dbms_rowid.rowid_create(1, DOI, hi_fno, hi_block, 1000000) ||
       chr(39) data
  FROM (SELECT DISTINCT DOI,
                        grp,
                        first_value(relative_fno) over(PARTITION BY DOI, grp ORDER BY relative_fno, block_id rows BETWEEN unbounded preceding AND unbounded following) lo_fno,
                        first_value(block_id) over(PARTITION BY DOI, grp ORDER BY relative_fno, block_id rows BETWEEN unbounded preceding AND unbounded following) lo_block,
                        last_value(relative_fno) over(PARTITION BY DOI, grp ORDER BY relative_fno, block_id rows BETWEEN unbounded preceding AND unbounded following) hi_fno,
                        last_value(block_id + blocks - 1) over(PARTITION BY DOI, grp ORDER BY relative_fno, block_id rows BETWEEN unbounded preceding AND unbounded following) hi_block,
                        SUM(blocks) over(PARTITION BY DOI, grp) sum_blocks,
                        SUBOBJECT_NAME
          FROM (SELECT obj.OBJECT_ID,
                       obj.SUBOBJECT_NAME,
                       obj.DATA_OBJECT_ID AS DOI,
                       ext.relative_fno,
                       ext.block_id,
                       SUM(blocks) over() SUM,
                       SUM(blocks) over(ORDER BY DATA_OBJECT_ID, relative_fno, block_id) - 0.01 sum_fno,
                       TRUNC((SUM(blocks) over(ORDER BY DATA_OBJECT_ID,
                                               relative_fno,
                                               block_id) - 0.01) /
                             (SUM(blocks) over() / &cnt)) grp,
                       ext.blocks
                  FROM dba_extents ext, dba_objects obj
                 WHERE ext.segment_name = '&object_name'
                   AND ext.owner = '&owner'
                   AND obj.owner = ext.owner
                   AND obj.object_name = ext.segment_name
                   AND obj.DATA_OBJECT_ID IS NOT NULL
                 ORDER BY DATA_OBJECT_ID, relative_fno, block_id)
         ORDER BY DOI, grp);
