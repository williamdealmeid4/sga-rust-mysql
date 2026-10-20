-- Extensão para tornar o faturamento operacional: valores lançados pelo Coordenador.
-- Não remove nem substitui dados acadêmicos.
USE sga_fbi;
CREATE TABLE cobranca (
 id_cobranca INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 id_aluno INT UNSIGNED NOT NULL,id_curso INT UNSIGNED NOT NULL,
 descricao VARCHAR(150) NOT NULL,valor DECIMAL(12,2) NOT NULL,vencimento DATE NOT NULL,
 status VARCHAR(15) NOT NULL DEFAULT 'Pendente',data_pagamento DATE NULL,
 id_usuario INT UNSIGNED NOT NULL,criada_em DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
 CONSTRAINT fk_cobranca_aluno FOREIGN KEY(id_aluno) REFERENCES aluno(id_aluno),
 CONSTRAINT fk_cobranca_curso FOREIGN KEY(id_curso) REFERENCES curso(id_curso),
 CONSTRAINT fk_cobranca_usuario FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario),
 CONSTRAINT ck_cobranca_valor CHECK(valor>0 AND valor<=1000000),
 CONSTRAINT ck_cobranca_descricao CHECK(CHAR_LENGTH(TRIM(descricao))>0),
 CONSTRAINT ck_cobranca_status CHECK(status IN('Pendente','Pago','Cancelado')),
 CONSTRAINT ck_cobranca_pagamento CHECK((status='Pago' AND data_pagamento IS NOT NULL) OR(status<>'Pago' AND data_pagamento IS NULL))
) ENGINE=InnoDB;
CREATE TABLE log_financeiro (
 id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,id_cobranca INT UNSIGNED NOT NULL,
 acao VARCHAR(15) NOT NULL,anterior JSON NULL,novo JSON NULL,
 id_usuario INT UNSIGNED NOT NULL,data_hora DATETIME(6) NOT NULL DEFAULT(UTC_TIMESTAMP(6)),
 CONSTRAINT fk_log_fin_usuario FOREIGN KEY(id_usuario) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;
DELIMITER $$
CREATE TRIGGER trg_audita_cobranca_insert AFTER INSERT ON cobranca FOR EACH ROW
BEGIN
 INSERT INTO log_financeiro(id_cobranca,acao,novo,id_usuario) VALUES(NEW.id_cobranca,'Criar',JSON_OBJECT('valor',NEW.valor,'status',NEW.status,'pagamento',NEW.data_pagamento),NEW.id_usuario);
END$$
CREATE TRIGGER trg_audita_cobranca_update AFTER UPDATE ON cobranca FOR EACH ROW
BEGIN
 INSERT INTO log_financeiro(id_cobranca,acao,anterior,novo,id_usuario) VALUES(NEW.id_cobranca,'Alterar',JSON_OBJECT('descricao',OLD.descricao,'valor',OLD.valor,'vencimento',OLD.vencimento,'status',OLD.status,'pagamento',OLD.data_pagamento),JSON_OBJECT('descricao',NEW.descricao,'valor',NEW.valor,'vencimento',NEW.vencimento,'status',NEW.status,'pagamento',NEW.data_pagamento),NEW.id_usuario);
END$$
CREATE PROCEDURE sp_salvar_cobranca(IN p_id INT UNSIGNED,IN p_aluno INT UNSIGNED,IN p_descricao VARCHAR(150),IN p_valor DECIMAL(12,2),IN p_vencimento DATE,IN p_status VARCHAR(15),IN p_pagamento DATE,IN p_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id,v_curso,v_aluno INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;CALL sp_exigir_perfil(p_usuario,TRUE);
 IF p_pagamento>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pagamento não pode estar no futuro.';END IF;
 IF p_id IS NULL THEN
  SELECT id_curso INTO v_curso FROM aluno WHERE id_aluno=p_aluno;
  INSERT INTO cobranca(id_aluno,id_curso,descricao,valor,vencimento,status,data_pagamento,id_usuario) VALUES(p_aluno,v_curso,p_descricao,p_valor,p_vencimento,p_status,p_pagamento,p_usuario);
  SET v_id=LAST_INSERT_ID();
 ELSE
  SELECT id_aluno INTO v_aluno FROM cobranca WHERE id_cobranca=p_id FOR UPDATE;
  IF v_aluno IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cobrança inexistente.';END IF;
  IF v_aluno<>p_aluno THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='O aluno da cobrança não pode ser alterado.';END IF;
  UPDATE cobranca SET descricao=p_descricao,valor=p_valor,vencimento=p_vencimento,status=p_status,data_pagamento=p_pagamento,id_usuario=p_usuario WHERE id_cobranca=p_id;
  SET v_id=p_id;
 END IF;
 COMMIT;SELECT v_id AS id_cobranca;
END$$
CREATE PROCEDURE sp_excluir_cobranca(IN p_id INT UNSIGNED,IN p_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(15);DECLARE v_old JSON;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK;RESIGNAL;END;
 START TRANSACTION;CALL sp_exigir_perfil(p_usuario,TRUE);
 SELECT status,JSON_OBJECT('valor',valor,'status',status,'descricao',descricao) INTO v_status,v_old FROM cobranca WHERE id_cobranca=p_id FOR UPDATE;
 IF v_status IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cobrança inexistente.';END IF;
 IF v_status<>'Pendente' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cobranças pagas ou canceladas são preservadas. Utilize o status Cancelado.';END IF;
 INSERT INTO log_financeiro(id_cobranca,acao,anterior,id_usuario)VALUES(p_id,'Excluir',v_old,p_usuario);
 DELETE FROM cobranca WHERE id_cobranca=p_id;COMMIT;
END$$
DROP PROCEDURE sp_faturamento_curso$$
CREATE PROCEDURE sp_faturamento_curso(IN p_id_usuario INT UNSIGNED) SQL SECURITY DEFINER
BEGIN
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 SELECT c.id_curso,c.nome,COUNT(b.id_cobranca) AS cobrancas,
 COALESCE(SUM(CASE WHEN b.status<>'Cancelado' THEN b.valor ELSE 0 END),0) AS cobrado,
 COALESCE(SUM(CASE WHEN b.status='Pago' THEN b.valor ELSE 0 END),0) AS recebido,
 COALESCE(SUM(CASE WHEN b.status='Pendente' THEN b.valor ELSE 0 END),0) AS em_aberto,
 COALESCE(SUM(CASE WHEN b.status='Cancelado' THEN b.valor ELSE 0 END),0) AS cancelado
 FROM curso c LEFT JOIN cobranca b ON b.id_curso=c.id_curso GROUP BY c.id_curso,c.nome;
END$$
DROP PROCEDURE sp_dados_sistema$$
CREATE PROCEDURE sp_dados_sistema(IN p_id_usuario INT UNSIGNED) SQL SECURITY DEFINER
BEGIN
 DECLARE v_dados JSON;
 CALL sp_exigir_perfil(p_id_usuario,FALSE);
 SET v_dados=JSON_OBJECT('alunos',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_aluno,'ra',t.ra,'nome',t.nome,'cpf',t.cpf,'email',t.email,'nascimento',t.data_nascimento,'curso_id',t.id_curso,'status',t.status)),JSON_ARRAY()) FROM aluno t),'cursos',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_curso,'nome',t.nome,'carga_horaria',t.carga_horaria_total,'turno',t.turno)),JSON_ARRAY()) FROM curso t),'disciplinas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_disciplina,'curso_id',t.id_curso,'nome',t.nome,'carga_horaria',t.carga_horaria,'periodo',t.periodo,'requisitos',(SELECT COALESCE(JSON_ARRAYAGG(pr.id_disciplina_requisito),JSON_ARRAY()) FROM pre_requisito pr WHERE pr.id_disciplina=t.id_disciplina))),JSON_ARRAY()) FROM disciplina t),'professores',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_professor,'nome',t.nome,'cpf',t.cpf,'email',t.email,'titulacao',t.titulacao,'admissao',t.data_admissao)),JSON_ARRAY()) FROM professor t),'turmas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_turma,'disciplina_id',t.id_disciplina,'professor_id',t.id_professor,'semestre',t.semestre,'vagas',t.vagas,'total_aulas',t.total_aulas,'encerrada',CAST(IF(t.encerrada,'true','false') AS JSON))),JSON_ARRAY()) FROM turma t),'matriculas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_matricula,'aluno_id',t.id_aluno,'turma_id',t.id_turma,'data',t.data_matricula,'n1',t.n1,'n2',t.n2,'exame',t.exame,'faltas',t.faltas,'media_final',t.media_final,'situacao',t.situacao,'frequencia',fn_frequencia(t.id_matricula),'usuario_id',t.id_usuario)),JSON_ARRAY()) FROM matricula t));
 IF fn_perfil_sessao()='Coordenador' THEN
 SET v_dados=JSON_SET(v_dados,'$.usuarios',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_usuario,'nome',t.nome,'cpf',t.cpf,'email',t.email,'login',t.login,'perfil',t.perfil)),JSON_ARRAY()) FROM usuario t),'$.auditoria',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_log,'matricula_id',t.id_matricula,'campo',t.campo,'anterior',t.valor_antigo,'novo',t.valor_novo,'usuario',t.usuario,'usuario_id',t.id_usuario,'data_hora',DATE_FORMAT(t.data_hora,'%Y-%m-%dT%H:%i:%s.000Z'))),JSON_ARRAY()) FROM log_nota t));
 SET v_dados=JSON_SET(v_dados,'$.financeiro',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',id_cobranca,'aluno_id',id_aluno,'curso_id',id_curso,'descricao',descricao,'valor',valor,'vencimento',vencimento,'status',status,'pagamento',data_pagamento,'usuario_id',id_usuario)),JSON_ARRAY()) FROM cobranca));
 END IF;
 SELECT v_dados AS dados;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_salvar_cobranca TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_excluir_cobranca TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_faturamento_curso TO 'sga_fbi_aplicacao';
GRANT EXECUTE ON PROCEDURE sga_fbi.sp_dados_sistema TO 'sga_fbi_aplicacao';
SELECT 'Módulo financeiro instalado.' AS resultado;
