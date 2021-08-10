
---禁用自动调优
SELECT client_name, status, consumer_group FROM dba_autotask_client ORDER BY client_name; 

BEGIN 
 DBMS_AUTO_TASK_ADMIN.DISABLE( 
 client_name => 'sql tuning advisor', 
 operation => NULL, 
 window_name => NULL); 
END; 
/

BEGIN 
 DBMS_AUTO_TASK_ADMIN.DISABLE( 
 client_name => 'auto space advisor', 
 operation => NULL, 
 window_name => NULL); 
END; 
/


---修改scheduler时间
SQL> select window_name,repeat_interval,duration ,enabled from dba_scheduler_windows

WINDOW_NAME                    REPEAT_INTERVAL                                                                  DURATION                 ENABL
------------------------------ -------------------------------------------------------------------------------- ------------------------ -----
MONDAY_WINDOW                  freq=daily;byday=MON;byhour=22;byminute=0; bysecond=0                            +000 04:00:00            TRUE
TUESDAY_WINDOW                 freq=daily;byday=TUE;byhour=22;byminute=0; bysecond=0                            +000 04:00:00            TRUE
WEDNESDAY_WINDOW               freq=daily;byday=WED;byhour=22;byminute=0; bysecond=0                            +000 04:00:00            TRUE
THURSDAY_WINDOW                freq=daily;byday=THU;byhour=22;byminute=0; bysecond=0                            +000 04:00:00            TRUE
FRIDAY_WINDOW                  freq=daily;byday=FRI;byhour=22;byminute=0; bysecond=0                            +000 04:00:00            TRUE
SATURDAY_WINDOW                freq=daily;byday=SAT;byhour=6;byminute=0; bysecond=0                             +000 20:00:00            TRUE
SUNDAY_WINDOW                  freq=daily;byday=SUN;byhour=6;byminute=0; bysecond=0                             +000 20:00:00            TRUE
WEEKNIGHT_WINDOW               freq=daily;byday=MON,TUE,WED,THU,FRI;byhour=22;byminute=0; bysecond=0            +000 08:00:00            FALSE
WEEKEND_WINDOW                 freq=daily;byday=SAT;byhour=0;byminute=0;bysecond=0                              +002 00:00:00            FALSE


SQL> col REPET for a180;
SQL> select 'EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'''||window_name||''',attribute=>'''||'REPEAT_INTERVAL' ||''',value=>'''||repeat_interval ||''');' repet,DURATION from dba_scheduler_windows;
REPET                                                                                                                                                                                DURATION
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ -----------------------------
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'MONDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=MON;byhour=22;byminute=0; bysecond=0');                                +000 04:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'TUESDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=TUE;byhour=22;byminute=0; bysecond=0');                               +000 04:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'WEDNESDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=WED;byhour=22;byminute=0; bysecond=0');                             +000 04:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'THURSDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=THU;byhour=22;byminute=0; bysecond=0');                              +000 04:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'FRIDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=FRI;byhour=22;byminute=0; bysecond=0');                                +000 04:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'SATURDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=SAT;byhour=6;byminute=0; bysecond=0');                               +000 20:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'SUNDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=SUN;byhour=6;byminute=0; bysecond=0');                                 +000 20:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'WEEKNIGHT_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=MON,TUE,WED,THU,FRI;byhour=22;byminute=0; bysecond=0');             +000 08:00:00
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'WEEKEND_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'freq=daily;byday=SAT;byhour=0;byminute=0;bysecond=0');                                 +002 00:00:00

---1.停止任务
EXEC DBMS_SCHEDULER.DISABLE(name=>'FRIDAY_WINDOW',force=>TRUE);

---2.修改任务的持续时间，单位是分钟
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'FRIDAY_WINDOW',attribute=>'DURATION',value=>numtodsinterval(180, 'minute'));

---3.开始执行时间，BYHOUR=2,表示2点开始执行
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'FRIDAY_WINDOW',attribute=>'REPEAT_INTERVAL',value=>'FREQ=WEEKLY;BYDAY=MON;BYHOUR=2;BYMINUTE=0;BYSECOND=0');
EXEC DBMS_SCHEDULER.SET_ATTRIBUTE(name=>'MONDAY_WINDOW',attribute=>'freq=daily;byday=MON;byhour=22;byminute=0; bysecond=0');
---4.开启任务
EXEC DBMS_SCHEDULER.ENABLE(name=>'FRIDAY_WINDOW');
