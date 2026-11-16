-- Read-only installation guard: requires MariaDB >=10.11 and no existing NST tables.
-- A scalar-subquery error stops txAdmin before DDL when a condition fails.
-- Inspect VERSION() and existing nst_* tables if this step is rejected.
-- Use the upgrade guide for existing NST installations, never the fresh recipe.
SET @nst_installation_requires_mariadb_10_11_and_empty_nst_schema = (
  SELECT CASE WHEN VERSION() LIKE '%MariaDB%'
    AND (CAST(SUBSTRING_INDEX(REPLACE(VERSION(),'5.5.5-',''),'.',1) AS UNSIGNED)>10
      OR (CAST(SUBSTRING_INDEX(REPLACE(VERSION(),'5.5.5-',''),'.',1) AS UNSIGNED)=10
        AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(VERSION(),'5.5.5-',''),'.',2),'.',-1) AS UNSIGNED)>=11))
    AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND LEFT(table_name,4)='nst_')
  THEN 1 ELSE (SELECT rejected FROM (SELECT 1 AS rejected UNION ALL SELECT 2 AS rejected) AS nst_reject_nonempty_or_unsupported_database) END
);
