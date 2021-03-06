SET TERM ON VER OFF FEED OFF ECHO OFF;
CL COL;
COL row_num FOR 9999999 HEA '#' PRI;

-- list
COL seq FOR 999;
COL dbname_instance_host FOR A50;
COL version FOR A10;
COL captured FOR A8;
SELECT eadam_seq_id seq,
       SUBSTR(dbname||':'||db_unique_name||':'||instance_name||':'||host_name, 1, 50) dbname_instance_host,
       version,
       SUBSTR(capture_time, 1, 8) captured
  FROM dba_hist_xtr_control_s
 ORDER BY 1;

-- parameters
PRO
PRO Parameter 1: eAdam seq_id (required)
COL eadam_seq_id NEW_V eadam_seq_id NOPRI;
SELECT TO_CHAR(MIN(eadam_seq_id)) eadam_seq_id,
       TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD') min_date,
       TO_CHAR(MAX(end_interval_time), 'YYYY-MM-DD') max_date
  FROM dba_hist_snapshot_s
 WHERE eadam_seq_id = &1.;

PRO Parameter 2: Begin date "YYYY-MM-DD": (opt)
COL minimum_snap_id NEW_V minimum_snap_id NOPRI;
COL begin_date NEW_V begin_date FOR A10 NOPRI;
SELECT MIN(snap_id) minimum_snap_id,
       MIN(TO_CHAR(begin_interval_time, 'YYYY-MM-DD')) begin_date
  FROM dba_hist_snapshot_s
 WHERE eadam_seq_id = &&eadam_seq_id.
   AND TO_CHAR(begin_interval_time, 'YYYY-MM-DD') >= NVL(TRIM('&2.'), TO_CHAR(begin_interval_time, 'YYYY-MM-DD'));

PRO Parameter 3: End date "YYYY-MM-DD": (opt)
COL maximum_snap_id NEW_V maximum_snap_id NOPRI;
COL end_date NEW_V end_date FOR A10 NOPRI;
SELECT MAX(snap_id) maximum_snap_id,
       MAX(TO_CHAR(end_interval_time, 'YYYY-MM-DD')) end_date
  FROM dba_hist_snapshot_s
 WHERE eadam_seq_id = &&eadam_seq_id.
   AND TO_CHAR(end_interval_time, 'YYYY-MM-DD') <= NVL(TRIM('&3.'), TO_CHAR(end_interval_time, 'YYYY-MM-DD'));

DEF skip_script = 'sql/eadam36_0f_skip_script.sql ';

/*
PRO Parameter 4: Produce HTML Reports? [ Y | N ] (default Y)
COL html_reports NEW_V html_reports NOPRI FOR A1;
SELECT DECODE(NVL(UPPER(SUBSTR(TRIM('&4.'), 1, 1)), 'Y'), 'Y', NULL, '&&skip_script.') html_reports FROM DUAL;

PRO Parameter 5: Produce TEXT Reports? [ Y | N ] (default Y)
COL text_reports NEW_V text_reports NOPRI FOR A1;
SELECT DECODE(NVL(UPPER(SUBSTR(TRIM('&5.'), 1, 1)), 'Y'), 'Y', NULL, '&&skip_script.') text_reports FROM DUAL;

PRO Parameter 6: Produce CSV Files? [ Y | N ] (default Y)
COL csv_files NEW_V csv_files NOPRI FOR A1;
SELECT DECODE(NVL(UPPER(SUBSTR(TRIM('&6.'), 1, 1)), 'Y'), 'Y', NULL, '&&skip_script.') csv_files FROM DUAL;

PRO Parameter 7: Produce CHART Reports? [ Y | N ] (default Y)
COL chrt_reports NEW_V chrt_reports NOPRI FOR A1;
SELECT DECODE(NVL(UPPER(SUBSTR(TRIM('&7.'), 1, 1)), 'Y'), 'Y', NULL, '&&skip_script.') chrt_reports FROM DUAL;
*/

-- too many people were passing N for no apparent reason
DEF html_reports = '';
DEF text_reports = '';
DEF csv_files = '';
DEF chrt_reports = '';

-- get dbid
COL dbid NEW_V dbid NOPRI;
SELECT TO_CHAR(dbid) dbid FROM dba_hist_xtr_control_s WHERE eadam_seq_id = &&eadam_seq_id.;

-- get database name (up to 10, stop before first '.', no special characters)
COL database_name_short NEW_V database_name_short FOR A10 NOPRI;
SELECT LOWER(SUBSTR(dbname, 1, 10)) database_name_short FROM dba_hist_xtr_control_s WHERE eadam_seq_id = &&eadam_seq_id.;
SELECT SUBSTR('&&database_name_short.', 1, INSTR('&&database_name_short..', '.') - 1) database_name_short FROM DUAL;
SELECT TRANSLATE('&&database_name_short.',
'abcdefghijklmnopqrstuvwxyz0123456789-_ ''`~!@#$%&*()=+[]{}\|;:",.<>/?'||CHR(0)||CHR(9)||CHR(10)||CHR(13)||CHR(38),
'abcdefghijklmnopqrstuvwxyz0123456789-_') database_name_short FROM DUAL;

-- get host name (up to 30, stop before first '.', no special characters)
COL host_name_short NEW_V host_name_short FOR A30 NOPRI;
SELECT LOWER(SUBSTR(host_name, 1, 30)) host_name_short FROM dba_hist_xtr_control_s WHERE eadam_seq_id = &&eadam_seq_id.;
SELECT SUBSTR('&&host_name_short.', 1, INSTR('&&host_name_short..', '.') - 1) host_name_short FROM DUAL;
SELECT TRANSLATE('&&host_name_short.',
'abcdefghijklmnopqrstuvwxyz0123456789-_ ''`~!@#$%&*()=+[]{}\|;:",.<>/?'||CHR(0)||CHR(9)||CHR(10)||CHR(13)||CHR(38),
'abcdefghijklmnopqrstuvwxyz0123456789-_') host_name_short FROM DUAL;

-- get rdbms version
COL db_version NEW_V db_version NOPRI;
SELECT version db_version FROM dba_hist_xtr_control_s WHERE eadam_seq_id = &&eadam_seq_id.;
DEF skip_10g = '';
COL skip_10g NEW_V skip_10g NOPRI;
SELECT version skip_10g FROM dba_hist_xtr_control_s WHERE eadam_seq_id = &&eadam_seq_id. AND version LIKE '10%';

-- get average number of CPUs
COL avg_cpu_count NEW_V avg_cpu_count FOR A3 NOPRI;
SELECT ROUND(AVG(TO_NUMBER(value))) avg_cpu_count FROM gv_system_parameter2_s WHERE eadam_seq_id = &&eadam_seq_id. AND name = 'cpu_count';

-- get total number of CPUs
COL sum_cpu_count NEW_V sum_cpu_count FOR A3 NOPRI;
SELECT SUM(TO_NUMBER(value)) sum_cpu_count FROM gv_system_parameter2_s WHERE eadam_seq_id = &&eadam_seq_id. AND name = 'cpu_count';

-- determine if rac or single instance (null means rac)
COL is_single_instance NEW_V is_single_instance FOR A1 NOPRI;
SELECT CASE COUNT(DISTINCT instance_number) WHEN 1 THEN 'Y' END is_single_instance FROM dba_hist_database_instanc_s WHERE eadam_seq_id = &&eadam_seq_id. AND dbid = &&dbid.;

-- timestamp on filename
COL file_creation_time NEW_V file_creation_time NOPRI FOR A20;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') file_creation_time FROM DUAL;

-- snapshot ranges
COL history_days NEW_V history_days NOPRI;
SELECT TO_DATE('&&end_date.', 'YYYY-MM-DD') - TO_DATE('&&begin_date.', 'YYYY-MM-DD') + 1 history_days FROM DUAL;
COL tool_sysdate NEW_V tool_sysdate NOPRI;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') tool_sysdate FROM DUAL;
COL as_of_date NEW_V as_of_date NOPRI;
SELECT ', as of '||TO_CHAR(SYSDATE, 'Dy Mon DD @HH12:MIAM') as_of_date FROM DUAL;

-- setup
DEF tool_vrsn = 'v1407 (2014-04-21)';
DEF prefix = 'eadam36';
DEF sql_trace_level = '8';
DEF main_table = '';
DEF title = '';
DEF title_no_spaces = '';
DEF title_suffix = '';
DEF common_prefix = '&&prefix._&&eadam_seq_id._&&database_name_short.';
DEF main_report_name = '0001_&&common_prefix._index';
DEF eadam36_log = '0002_&&common_prefix._log';
DEF eadam36_tkprof = '0003_&&common_prefix._tkprof';
DEF main_compressed_filename = '&&common_prefix._&&host_name_short.';
DEF eadam36_log2 = '0004_&&main_compressed_filename._&&file_creation_time.';
DEF eadam36_tracefile_identifier = '&&main_compressed_filename._&&file_creation_time.';
DEF copyright = ' (c) 2014';
DEF top_level_hints = 'NO_MERGE PARALLEL(4)';
DEF sq_fact_hints = 'MATERIALIZE NO_MERGE PARALLEL(4)';
DEF def_max_rows = '1e4';
DEF max_rows = '1e4';
DEF exclusion_list = "(''ANONYMOUS'',''APEX_030200'',''APEX_040000'',''APEX_SSO'',''APPQOSSYS'',''CTXSYS'',''DBSNMP'',''DIP'',''EXFSYS'',''FLOWS_FILES'',''MDSYS'',''OLAPSYS'',''ORACLE_OCM'',''ORDDATA'',''ORDPLUGINS'',''ORDSYS'',''OUTLN'',''OWBSYS'')";
DEF exclusion_list2 = "(''SI_INFORMTN_SCHEMA'',''SQLTXADMIN'',''SQLTXPLAIN'',''SYS'',''SYSMAN'',''SYSTEM'',''TRCANLZR'',''WMSYS'',''XDB'',''XS$NULL'')";
DEF skip_diagnostics = '';
DEF skip_html = '';
DEF skip_text = '';
DEF skip_csv = '';
DEF skip_lch = 'Y';
DEF skip_pch = 'Y';
DEF skip_all = '';
DEF abstract = '';
DEF abstract2 = '';
DEF foot = '';
DEF foot2 = '';
DEF sql_text = '';
DEF chartype = '';
DEF stacked = '';
DEF haxis = '&&db_version. dbname:&&database_name_short. host:&&host_name_short. (avg cpu_count: &&avg_cpu_count.)';
DEF vaxis = '';
DEF vbaseline = '';
DEF tit_01 = '';
DEF tit_02 = '';
DEF tit_03 = '';
DEF tit_04 = '';
DEF tit_05 = '';
DEF tit_06 = '';
DEF tit_07 = '';
DEF tit_08 = '';
DEF tit_09 = '';
DEF tit_10 = '';
DEF tit_11 = '';
DEF tit_12 = '';
DEF tit_13 = '';
DEF tit_14 = '';
DEF tit_15 = '';
DEF wait_class_01 = '';
DEF event_name_01 = '';
DEF wait_class_02 = '';
DEF event_name_02 = '';
DEF wait_class_03 = '';
DEF event_name_03 = '';
DEF wait_class_04 = '';
DEF event_name_04 = '';
DEF wait_class_05 = '';
DEF event_name_05 = '';
DEF wait_class_06 = '';
DEF event_name_06 = '';
DEF wait_class_07 = '';
DEF event_name_07 = '';
DEF wait_class_08 = '';
DEF event_name_08 = '';
DEF wait_class_09 = '';
DEF event_name_09 = '';
DEF wait_class_10 = '';
DEF event_name_10 = '';
DEF wait_class_11 = '';
DEF event_name_11 = '';
DEF wait_class_12 = '';
DEF event_name_12 = '';
DEF exadata = '';
DEF max_col_number = '1';
DEF column_number = '1';
COL recovery NEW_V recovery NOPRI;
SELECT CHR(38)||' recovery' recovery FROM DUAL;
-- this above is to handle event "RMAN backup & recovery I/O"
COL skip_html NEW_V skip_html;
COL skip_text NEW_V skip_text;
COL skip_csv NEW_V skip_csv;
COL skip_lch NEW_V skip_lch;
COL skip_pch NEW_V skip_pch;
COL skip_all NEW_V skip_all;
COL dummy_01 NOPRI;
COL dummy_02 NOPRI;
COL dummy_03 NOPRI;
COL dummy_04 NOPRI;
COL dummy_05 NOPRI;
COL dummy_06 NOPRI;
COL dummy_07 NOPRI;
COL dummy_08 NOPRI;
COL dummy_09 NOPRI;
COL dummy_10 NOPRI;
COL dummy_11 NOPRI;
COL dummy_12 NOPRI;
COL dummy_13 NOPRI;
COL dummy_14 NOPRI;
COL dummy_15 NOPRI;
COL time_stamp NEW_V time_stamp NOPRI FOR A20;
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS') time_stamp FROM DUAL;
COL hh_mm_ss NEW_V hh_mm_ss NOPRI FOR A8;
COL title_no_spaces NEW_V title_no_spaces NOPRI;
COL spool_filename NEW_V spool_filename NOPRI;
COL one_spool_filename NEW_V one_spool_filename NOPRI;
VAR row_count NUMBER;
VAR sql_text CLOB;
VAR sql_text_backup CLOB;
VAR sql_text_backup2 CLOB;
VAR sql_text_display CLOB;
VAR file_seq NUMBER;
EXEC :file_seq := 5;
VAR get_time_t0 NUMBER;
VAR get_time_t1 NUMBER;
-- Exadata
ALTER SESSION SET "_serial_direct_read" = ALWAYS;
ALTER SESSION SET "_small_table_threshold" = 1001;
-- nls
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ".,";
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD/HH24:MI:SS';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD/HH24:MI:SS.FF';
ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD/HH24:MI:SS.FF TZH:TZM';
-- adding to prevent slow access to ASH with non default NLS settings
ALTER SESSION SET NLS_SORT = 'BINARY';
ALTER SESSION SET NLS_COMP = 'BINARY';
-- tracing script in case it takes long to execute so we can diagnose it
ALTER SESSION SET MAX_DUMP_FILE_SIZE = '1G';
ALTER SESSION SET TRACEFILE_IDENTIFIER = "&&eadam36_tracefile_identifier.";
--ALTER SESSION SET STATISTICS_LEVEL = 'ALL';
ALTER SESSION SET EVENTS '10046 TRACE NAME CONTEXT FOREVER, LEVEL &&sql_trace_level.';
SET TERM OFF HEA ON LIN 32767 NEWP NONE PAGES 50 LONG 32000 LONGC 2000 WRA ON TRIMS ON TRIM ON TI OFF TIMI OFF ARRAY 100 NUM 20 SQLBL ON BLO . RECSEP OFF;

PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- log header
SPO &&eadam36_log..txt;
PRO begin log
PRO
DEF;
SPO OFF;

-- main header
SPO &&main_report_name..html;
@@eadam36_0d_html_header.sql
PRO </head>
PRO <body>
PRO <h1><a href="http://www.enkitec.com" target="_blank">Enkitec</a>: Awr DAta Mining tool <em>(<a href="http://www.enkitec.com/products/eadam" target="_blank">eadam</a>)</em></h1>
PRO
PRO <pre>
PRO dbname : &&database_name_short. (&&db_version.)
PRO host   : &&host_name_short.
PRO seq_id : &&eadam_seq_id.
PRO </pre>
PRO
SPO OFF;
