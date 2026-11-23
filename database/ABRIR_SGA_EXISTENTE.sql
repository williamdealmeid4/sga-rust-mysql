-- SGA já instalado: execute este arquivo para conferir o banco existente.
-- Não execute novamente sga_fbi_completo.sql neste computador.
USE sga_fbi;
SELECT DATABASE() AS banco, 'SGA instalado e disponível' AS resultado;
SHOW TABLES;
SELECT ROUTINE_NAME AS procedure_sga FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'sga_fbi' AND ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;
