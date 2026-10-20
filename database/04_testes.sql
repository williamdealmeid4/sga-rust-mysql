-- Execute no banco separado criado por sga_fbi_testes_completo.sql.
-- Este arquivo modifica somente os dados fictícios do banco de testes.
USE sga_fbi_testes;
SET NAMES utf8mb4;
SET @coord_prova=(SELECT senha_hash FROM usuario WHERE login='coordenador');
SET @sec_prova=(SELECT senha_hash FROM usuario WHERE login='secretario');
CREATE TEMPORARY TABLE resultado_teste (
 numero INT AUTO_INCREMENT PRIMARY KEY, teste VARCHAR(180), resultado VARCHAR(10), sqlstate_erro CHAR(5), codigo_erro INT
);
DELIMITER $$
CREATE PROCEDURE sp_teste_assert(IN p_ok BOOLEAN,IN p_nome VARCHAR(180))
BEGIN
 IF p_ok IS NULL OR NOT p_ok THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=p_nome; END IF;
 INSERT INTO resultado_teste(teste,resultado) VALUES(p_nome,'PASSOU');
END$$
CREATE PROCEDURE sp_teste_erro(IN p_nome VARCHAR(180),IN p_sql TEXT,IN p_estado CHAR(5),IN p_codigo INT)
BEGIN
 DECLARE v_falhou BOOLEAN DEFAULT FALSE; DECLARE v_estado CHAR(5); DECLARE v_codigo INT;
 SET @teste_sql=p_sql;
 PREPARE teste_stmt FROM @teste_sql;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_estado=RETURNED_SQLSTATE,v_codigo=MYSQL_ERRNO; SET v_falhou=TRUE; END;
  EXECUTE teste_stmt;
 END;
 DEALLOCATE PREPARE teste_stmt;
 IF NOT v_falhou OR (p_estado IS NOT NULL AND NOT(v_estado<=>p_estado)) OR (p_codigo IS NOT NULL AND NOT(v_codigo<=>p_codigo)) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=p_nome;
 END IF;
 INSERT INTO resultado_teste(teste,resultado,sqlstate_erro,codigo_erro) VALUES(p_nome,'PASSOU',v_estado,v_codigo);
END$$
DELIMITER ;

CALL sp_teste_assert(DATABASE()='sga_fbi_testes','Banco de testes separado');
CALL sp_teste_assert((SELECT COUNT(*) FROM usuario)=5,'Massa: 5 usuários');
CALL sp_teste_assert((SELECT COUNT(*) FROM usuario WHERE perfil='Coordenador')=2,'Massa: 2 Coordenadores');
CALL sp_teste_assert((SELECT COUNT(*) FROM curso)=3,'Massa: 3 cursos');
CALL sp_teste_assert((SELECT COUNT(*) FROM disciplina)=6,'Massa: 6 disciplinas');
CALL sp_teste_assert((SELECT COUNT(*) FROM professor)=5,'Massa: 5 professores');
CALL sp_teste_assert((SELECT COUNT(*) FROM aluno)=20,'Massa: 20 alunos');
CALL sp_teste_assert((SELECT COUNT(*) FROM turma)=5,'Massa: 5 turmas');
CALL sp_teste_assert((SELECT COUNT(*) FROM matricula)=35,'Massa: 35 matrículas');
CALL sp_teste_assert((SELECT COUNT(DISTINCT senha_hash) FROM usuario)=5,'Senha: salt individual, sem texto puro');
CALL sp_teste_erro('Login com senha incorreta',"CALL sp_LoginUsuario('coordenador','hash_incorreto')",'45000',1644);
CALL sp_teste_erro('Login com usuário inexistente',"CALL sp_LoginUsuario('inexistente',SHA2('Fbi@2026',256))",'45000',1644);
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_boletim)=0,'View sem sessão não revela boletins');
CALL sp_LoginUsuario('coordenador',@coord_prova);
CALL sp_teste_assert(fn_usuario_sessao()=1,'Login válido retorna identidade de sessão');
CALL sp_salvar_aluno(NULL,'TESTE0001','Aluno de teste SQL','12345678901','teste@exemplo.edu.br','2000-01-01',1,'Ativo',1);
UPDATE turma SET vagas=12 WHERE id_turma=1;
CALL sp_teste_erro('RN05: turma lotada',"CALL sp_matricular_aluno(21,1,1)",'45000',1644);
UPDATE turma SET vagas=30 WHERE id_turma=1;
CALL sp_teste_erro('RN06: sem pré-requisito',"CALL sp_matricular_aluno(21,3,1)",'45000',1644);
CALL sp_teste_erro('RN09: aluno Trancado',"CALL sp_matricular_aluno(20,4,1)",'45000',1644);
CALL sp_teste_erro('Unicidade: matrícula duplicada',"CALL sp_matricular_aluno(1,1,1)",'23000',1062);
CALL sp_teste_erro('RN07: nota 11 rejeitada pelo CHECK',"CALL sp_lancar_notas(1,11,8,0,1)",'HY000',3819);
CALL sp_teste_erro('Faltas maiores que total de aulas',"CALL sp_lancar_notas(1,9,9,81,1)",'45000',1644);
CALL sp_teste_assert(fn_calcular_media(7,7,NULL)=7,'RN01: média parcial');
CALL sp_teste_assert(fn_situacao_valores(6.99,7,NULL,0,80)='Em Exame','RN02: média 6,995 não arredonda para aprovação');
CALL sp_teste_assert(fn_situacao_valores(3.99,3.99,NULL,0,80)='Reprovado por Nota','RN02: média menor que 4');
CALL sp_teste_assert(fn_situacao_valores(7,7,NULL,20,80)='Aprovado','RN04: frequência exatamente 75% aprova');
CALL sp_lancar_notas(1,6,6,0,1);
CALL sp_teste_assert((SELECT situacao FROM matricula WHERE id_matricula=1)='Em Exame','RN02: situação Em Exame');
CALL sp_lancar_exame(1,4,1);
CALL sp_teste_assert((SELECT media_final=5 AND situacao='Aprovado' FROM matricula WHERE id_matricula=1),'RN03: exame e média final 5');
CALL sp_teste_erro('Exame bloqueado fora da situação Em Exame',"CALL sp_lancar_exame(1,5,1)",'45000',1644);
CALL sp_lancar_notas(1,9,9,21,1);
CALL sp_teste_assert((SELECT media_final=9 AND situacao='Reprovado por Falta' FROM matricula WHERE id_matricula=1),'RN04: nota 9 com frequência inferior a 75%');
CALL sp_teste_assert(fn_frequencia(1)=73.75,'Função de frequência');
CALL sp_teste_assert(fn_situacao(1)='Reprovado por Falta','Função de situação');
SET @logs_antes=(SELECT COUNT(*) FROM log_nota WHERE id_matricula=1);
CALL sp_lancar_notas(1,8,9,21,1);
CALL sp_teste_assert((SELECT COUNT(*) FROM log_nota WHERE id_matricula=1)=@logs_antes+1,'RN08: exatamente um log para uma nota alterada');
CALL sp_teste_assert((SELECT valor_antigo=9 AND valor_novo=8 AND id_usuario=1 FROM log_nota WHERE id_matricula=1 ORDER BY id_log DESC LIMIT 1),'RN08: valor anterior, novo e responsável');
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_boletim)=35,'Consulta vw_boletim');
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_turmas_lotacao)=5,'Consulta vw_turmas_lotacao');
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_desempenho_turma)=5,'Consulta vw_desempenho_turma');
CALL sp_historico_aluno(1);
CALL sp_teste_erro('Pré-requisitos sem ciclos',"CALL sp_adicionar_pre_requisito(2,3,1)",'45000',1644);
CALL sp_teste_erro('Exclusão preserva histórico com notas',"CALL sp_excluir_cadastro('matricula',1,1)",'45000',1644);
CALL sp_teste_erro('FK preserva aluno com matrículas',"CALL sp_excluir_cadastro('aluno',1,1)",'23000',1451);
CALL sp_LoginUsuario('secretario',@sec_prova);
CALL sp_teste_erro('Secretário sem acesso ao lançamento',"CALL sp_lancar_notas(1,8,8,0,3)",'45000',1644);
CALL sp_teste_erro('Secretário não pode usar ID do Coordenador',"CALL sp_lancar_notas(1,8,8,0,1)",'45000',1644);
CALL sp_teste_erro('Secretário sem acesso ao fechamento',"CALL sp_fechar_semestre('2026.1',3)",'45000',1644);
CALL sp_teste_erro('Secretário sem acesso ao financeiro',"CALL sp_faturamento_curso(3)",'45000',1644);
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_desempenho_turma)=0,'View de desempenho restrita ao Coordenador');
CALL sp_teste_assert((SELECT COUNT(*) FROM vw_usuarios)=0,'View de usuários restrita ao Coordenador');
CALL sp_LoginUsuario('coordenador',@coord_prova);
CALL sp_matricular_aluno(1,3,1);
CALL sp_teste_assert((SELECT COUNT(*) FROM matricula WHERE id_aluno=1 AND id_turma=3)=1,'RN06: aprovação anterior permite matrícula');
CALL sp_teste_erro('Fechamento com pendências não altera turmas',"CALL sp_fechar_semestre('2026.2',1)",'45000',1644);
CALL sp_teste_assert((SELECT COUNT(*) FROM turma WHERE semestre='2026.2' AND encerrada)=0,'Rollback de fechamento com pendências');
CALL sp_salvar_turma(NULL,1,1,'2031.1',30,80,1);
CALL sp_salvar_turma(NULL,2,2,'2031.1',30,80,1);
CALL sp_matricular_aluno(21,7,1);
CALL sp_teste_erro('Fechamento em lote com rollback após primeira turma',"CALL sp_fechar_semestre('2031.1',1)",'45000',1644);
CALL sp_teste_assert((SELECT COUNT(*) FROM turma WHERE semestre='2031.1' AND encerrada)=0,'Transação reverte turma já processada pelo cursor');
CALL sp_fechar_semestre('2026.1',1);
CALL sp_teste_assert((SELECT encerrada FROM turma WHERE id_turma=2)=TRUE,'Encerramento de semestre concluído');
CALL sp_teste_erro('Notas bloqueadas após encerramento',"CALL sp_lancar_notas(2,9,9,0,1)",'45000',1644);
CALL sp_teste_erro('Matrículas bloqueadas após encerramento',"CALL sp_matricular_aluno(21,2,1)",'45000',1644);
CALL sp_LogoutUsuario();
CALL sp_teste_assert(fn_usuario_sessao() IS NULL,'Logout invalida sessão');
SELECT * FROM resultado_teste ORDER BY numero;
SELECT COUNT(*) AS testes_aprovados FROM resultado_teste;
DROP PROCEDURE sp_teste_assert;
DROP PROCEDURE sp_teste_erro;
DROP TEMPORARY TABLE resultado_teste;
