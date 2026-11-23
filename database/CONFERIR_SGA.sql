-- Consultas de conferência: não alteram dados. Execute com sua conexão administrativa no Workbench.
USE sga_fbi;
SELECT DATABASE() AS banco, VERSION() AS versao_mysql;
SELECT ROUTINE_NAME,ROUTINE_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='sga_fbi' ORDER BY ROUTINE_TYPE,ROUTINE_NAME;
SELECT TRIGGER_NAME,EVENT_MANIPULATION,EVENT_OBJECT_TABLE FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='sga_fbi';
SHOW FULL TABLES WHERE Table_type='VIEW';
SELECT id_aluno,ra,nome,data_nascimento,TIMESTAMPDIFF(YEAR,data_nascimento,CURDATE()) AS idade,status,id_curso FROM aluno ORDER BY id_aluno DESC;
SELECT id_matricula,id_aluno,id_turma,data_matricula,situacao FROM matricula ORDER BY id_matricula DESC;
SHOW CREATE PROCEDURE sp_salvar_aluno;
SHOW CREATE PROCEDURE sp_excluir_cadastro;
