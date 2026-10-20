USE sga_fbi;
-- Não cria usuário nem contém senha de acesso ao servidor.
CREATE ROLE IF NOT EXISTS 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_LoginUsuario TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_LogoutUsuario TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_matricular_aluno TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_lancar_notas TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_lancar_exame TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_historico_aluno TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_fechar_semestre TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_adicionar_pre_requisito TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_remover_pre_requisito TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_aluno TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_curso TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_disciplina TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_professor TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_turma TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_usuario TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_excluir_cadastro TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_faturamento_curso TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_boletim TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_turmas_lotacao TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_desempenho_turma TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_alunos TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_cursos TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_disciplinas TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_pre_requisitos TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_professores TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_usuarios TO 'sga_fbi_aplicacao';
GRANT SELECT ON sga_fbi.vw_auditoria_notas TO 'sga_fbi_aplicacao';

-- A conta da aplicação deve ser dedicada e nunca receber DML direto nas tabelas.
-- Exemplo para o administrador personalizar (não executado automaticamente):
-- CREATE USER 'sga_app'@'localhost' IDENTIFIED BY 'SUBSTITUA_POR_UMA_SENHA_FORTE';
-- GRANT 'sga_fbi_aplicacao' TO 'sga_app'@'localhost';
-- SET DEFAULT ROLE 'sga_fbi_aplicacao' TO 'sga_app'@'localhost';

GRANT EXECUTE ON PROCEDURE sga_fbi.sp_CredencialLogin TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_UsarSessao TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_atualizar_avaliacao TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_disciplina_requisitos TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_dados_sistema TO 'sga_fbi_aplicacao';
