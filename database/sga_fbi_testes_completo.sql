-- MySQL 8.0.16+ / MySQL Workbench. UTF-8.
-- Intencionalmente sem DROP DATABASE ou IF NOT EXISTS: não sobrescreve banco existente.
SET NAMES utf8mb4;
CREATE DATABASE sga_fbi_testes CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE sga_fbi_testes;


USE sga_fbi_testes;
SET NAMES utf8mb4;

CREATE TABLE usuario (
 id_usuario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 nome VARCHAR(150) NOT NULL, cpf CHAR(11) NOT NULL UNIQUE,
 email VARCHAR(254) NOT NULL UNIQUE, login VARCHAR(80) NOT NULL UNIQUE,
 senha_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 perfil VARCHAR(20) NOT NULL,
 CONSTRAINT ck_usuario_perfil CHECK (perfil IN ('Secretario','Coordenador')),
 CONSTRAINT ck_usuario_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
 CONSTRAINT ck_usuario_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
 CONSTRAINT ck_usuario_hash CHECK (senha_hash LIKE '$argon2id$%')
) ENGINE=InnoDB;

CREATE TABLE curso (
 id_curso INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150) NOT NULL UNIQUE,
 carga_horaria_total INT UNSIGNED NOT NULL, turno VARCHAR(20) NOT NULL,
 CONSTRAINT ck_curso_carga CHECK (carga_horaria_total BETWEEN 1 AND 100000),
 CONSTRAINT ck_curso_turno CHECK (turno IN ('Matutino','Vespertino','Noturno')),
 CONSTRAINT ck_curso_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE=InnoDB;
CREATE TABLE disciplina (
 id_disciplina INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, id_curso INT UNSIGNED NOT NULL,
 nome VARCHAR(150) NOT NULL, carga_horaria INT UNSIGNED NOT NULL, periodo SMALLINT UNSIGNED NOT NULL,
 CONSTRAINT fk_disciplina_curso FOREIGN KEY (id_curso) REFERENCES curso(id_curso),
 CONSTRAINT uq_disciplina_nome UNIQUE (id_curso,nome),
 CONSTRAINT ck_disciplina_carga CHECK (carga_horaria BETWEEN 1 AND 100000),
 CONSTRAINT ck_disciplina_periodo CHECK (periodo BETWEEN 1 AND 100),
 CONSTRAINT ck_disciplina_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE=InnoDB;
CREATE TABLE pre_requisito (
 id_disciplina INT UNSIGNED NOT NULL, id_disciplina_requisito INT UNSIGNED NOT NULL,
 PRIMARY KEY (id_disciplina,id_disciplina_requisito),
 CONSTRAINT fk_pr_disciplina FOREIGN KEY (id_disciplina) REFERENCES disciplina(id_disciplina),
 CONSTRAINT fk_pr_requisito FOREIGN KEY (id_disciplina_requisito) REFERENCES disciplina(id_disciplina),
 CONSTRAINT ck_pr_distintos CHECK (id_disciplina <> id_disciplina_requisito)
) ENGINE=InnoDB;
CREATE TABLE professor (
 id_professor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150) NOT NULL,
 cpf CHAR(11) NOT NULL UNIQUE, email VARCHAR(254) NOT NULL UNIQUE,
 titulacao VARCHAR(80) NOT NULL, data_admissao DATE NOT NULL,
 CONSTRAINT ck_professor_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
 CONSTRAINT ck_professor_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0)
) ENGINE=InnoDB;
CREATE TABLE aluno (
 id_aluno INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, ra VARCHAR(30) NOT NULL UNIQUE,
 nome VARCHAR(150) NOT NULL, cpf CHAR(11) NOT NULL UNIQUE, email VARCHAR(254) NOT NULL UNIQUE,
 data_nascimento DATE NOT NULL, id_curso INT UNSIGNED NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'Ativo',
 CONSTRAINT fk_aluno_curso FOREIGN KEY (id_curso) REFERENCES curso(id_curso),
 CONSTRAINT ck_aluno_status CHECK (status IN ('Ativo','Trancado','Formado')),
 CONSTRAINT ck_aluno_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
 CONSTRAINT ck_aluno_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
 CONSTRAINT ck_aluno_ra CHECK (CHAR_LENGTH(TRIM(ra)) > 0)
) ENGINE=InnoDB;
CREATE TABLE turma (
 id_turma INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, id_disciplina INT UNSIGNED NOT NULL,
 id_professor INT UNSIGNED NOT NULL, semestre CHAR(6) NOT NULL,
 vagas INT UNSIGNED NOT NULL, total_aulas INT UNSIGNED NOT NULL,
 encerrada BOOLEAN NOT NULL DEFAULT FALSE, encerrada_em DATETIME(6) NULL,
 encerrada_por INT UNSIGNED NULL,
 CONSTRAINT fk_turma_disciplina FOREIGN KEY (id_disciplina) REFERENCES disciplina(id_disciplina),
 CONSTRAINT fk_turma_professor FOREIGN KEY (id_professor) REFERENCES professor(id_professor),
 CONSTRAINT fk_turma_encerramento FOREIGN KEY (encerrada_por) REFERENCES usuario(id_usuario),
 CONSTRAINT ck_turma_semestre CHECK (semestre REGEXP '^[0-9]{4}[.][12]$'),
 CONSTRAINT ck_turma_vagas CHECK (vagas BETWEEN 1 AND 100000),
 CONSTRAINT ck_turma_aulas CHECK (total_aulas BETWEEN 1 AND 100000),
 CONSTRAINT ck_turma_encerrada CHECK (encerrada IN (0,1)),
 INDEX ix_turma_semestre (semestre,id_turma)
) ENGINE=InnoDB;
CREATE TABLE matricula (
 id_matricula INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, id_aluno INT UNSIGNED NOT NULL,
 id_turma INT UNSIGNED NOT NULL, data_matricula DATE NOT NULL,
 n1 DECIMAL(4,2) NULL, n2 DECIMAL(4,2) NULL, exame DECIMAL(4,2) NULL,
 faltas INT NOT NULL DEFAULT 0, media_final DECIMAL(6,4) NULL,
 situacao VARCHAR(30) NOT NULL DEFAULT 'Cursando', id_usuario INT UNSIGNED NOT NULL,
 CONSTRAINT uq_aluno_turma UNIQUE (id_aluno,id_turma),
 CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno) REFERENCES aluno(id_aluno),
 CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma) REFERENCES turma(id_turma),
 CONSTRAINT fk_matricula_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
 CONSTRAINT ck_n1 CHECK (n1 IS NULL OR n1 BETWEEN 0 AND 10),
 CONSTRAINT ck_n2 CHECK (n2 IS NULL OR n2 BETWEEN 0 AND 10),
 CONSTRAINT ck_exame CHECK (exame IS NULL OR exame BETWEEN 0 AND 10),
 CONSTRAINT ck_faltas CHECK (faltas >= 0),
 CONSTRAINT ck_situacao CHECK (situacao IN ('Cursando','Aprovado','Em Exame','Reprovado por Nota','Reprovado por Falta')),
 INDEX ix_matricula_turma (id_turma,id_matricula)
) ENGINE=InnoDB;
CREATE TABLE log_nota (
 id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, id_matricula INT UNSIGNED NOT NULL,
 campo VARCHAR(10) NOT NULL, valor_antigo DECIMAL(10,2) NULL, valor_novo DECIMAL(10,2) NULL,
 usuario VARCHAR(150) NOT NULL, id_usuario INT UNSIGNED NOT NULL,
 data_hora DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
 CONSTRAINT fk_log_matricula FOREIGN KEY (id_matricula) REFERENCES matricula(id_matricula),
 CONSTRAINT fk_log_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
 CONSTRAINT ck_log_campo CHECK (campo IN ('n1','n2','exame','faltas')),
 INDEX ix_log_matricula_data (id_matricula,data_hora)
) ENGINE=InnoDB;
-- Extensão de segurança: a identidade não é confiada apenas ao p_id_usuario.
CREATE TABLE sessao_usuario (
 token_hash BINARY(32) PRIMARY KEY, id_usuario INT UNSIGNED NOT NULL,
 criada_em DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), expira_em DATETIME(6) NOT NULL,
 CONSTRAINT fk_sessao_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
 INDEX ix_sessao_expira (expira_em)
) ENGINE=InnoDB;


USE sga_fbi_testes;
SET NAMES utf8mb4;
DELIMITER $$

CREATE FUNCTION fn_calcular_media(p_n1 DECIMAL(4,2),p_n2 DECIMAL(4,2),p_exame DECIMAL(4,2))
RETURNS DECIMAL(6,4) DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
 DECLARE v_parcial DECIMAL(6,4);
 IF p_n1 IS NULL OR p_n2 IS NULL THEN RETURN NULL; END IF;
 SET v_parcial=(p_n1+p_n2)/2;
 IF v_parcial>=4 AND v_parcial<7 AND p_exame IS NOT NULL THEN RETURN (v_parcial+p_exame)/2; END IF;
 RETURN v_parcial;
END$$
CREATE FUNCTION fn_situacao_valores(p_n1 DECIMAL(4,2),p_n2 DECIMAL(4,2),p_exame DECIMAL(4,2),p_faltas INT,p_aulas INT)
RETURNS VARCHAR(30) DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
 DECLARE v_parcial DECIMAL(6,4);
 IF p_aulas<=0 OR (p_aulas-p_faltas)*100 < 75*p_aulas THEN RETURN 'Reprovado por Falta'; END IF;
 IF p_n1 IS NULL OR p_n2 IS NULL THEN RETURN 'Cursando'; END IF;
 SET v_parcial=(p_n1+p_n2)/2;
 IF v_parcial>=7 THEN RETURN 'Aprovado'; END IF;
 IF v_parcial<4 THEN RETURN 'Reprovado por Nota'; END IF;
 IF p_exame IS NULL THEN RETURN 'Em Exame'; END IF;
 IF fn_calcular_media(p_n1,p_n2,p_exame)>=5 THEN RETURN 'Aprovado'; END IF;
 RETURN 'Reprovado por Nota';
END$$
CREATE FUNCTION fn_frequencia(p_id_matricula INT UNSIGNED)
RETURNS DECIMAL(7,4) READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_freq DECIMAL(7,4) DEFAULT NULL;
 SELECT (t.total_aulas-m.faltas)*100.0/t.total_aulas INTO v_freq
 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma WHERE m.id_matricula=p_id_matricula;
 RETURN v_freq;
END$$
CREATE FUNCTION fn_situacao(p_id_matricula INT UNSIGNED)
RETURNS VARCHAR(30) READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(30) DEFAULT NULL;
 SELECT fn_situacao_valores(m.n1,m.n2,m.exame,m.faltas,t.total_aulas) INTO v_status
 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma WHERE m.id_matricula=p_id_matricula;
 RETURN v_status;
END$$
CREATE FUNCTION fn_cr_aluno(p_id_aluno INT UNSIGNED)
RETURNS DECIMAL(7,4) READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_cr DECIMAL(7,4) DEFAULT NULL;
 SELECT SUM(m.media_final*d.carga_horaria)/NULLIF(SUM(d.carga_horaria),0) INTO v_cr
 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma JOIN disciplina d ON d.id_disciplina=t.id_disciplina
 WHERE m.id_aluno=p_id_aluno AND m.situacao IN ('Aprovado','Reprovado por Nota','Reprovado por Falta') AND m.media_final IS NOT NULL;
 RETURN v_cr;
END$$
CREATE FUNCTION fn_usuario_sessao() RETURNS INT UNSIGNED READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_usuario INT UNSIGNED DEFAULT NULL;
 SELECT id_usuario INTO v_usuario FROM sessao_usuario
 WHERE token_hash=UNHEX(SHA2(@sga_token,256)) AND expira_em>NOW(6);
 RETURN v_usuario;
END$$
CREATE FUNCTION fn_perfil_sessao() RETURNS VARCHAR(20) READS SQL DATA SQL SECURITY DEFINER
BEGIN
 DECLARE v_perfil VARCHAR(20) DEFAULT NULL;
 SELECT perfil INTO v_perfil FROM usuario WHERE id_usuario=fn_usuario_sessao();
 RETURN v_perfil;
END$$
CREATE PROCEDURE sp_exigir_perfil(IN p_id_usuario INT UNSIGNED,IN p_coordenador BOOLEAN)
SQL SECURITY DEFINER
BEGIN
 IF fn_usuario_sessao() IS NULL OR NOT (fn_usuario_sessao()<=>p_id_usuario) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sessão inválida, expirada ou usuário divergente. Execute sp_LoginUsuario.';
 END IF;
 IF p_coordenador AND fn_perfil_sessao()<>'Coordenador' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Operação exclusiva do Coordenador.';
 END IF;
END$$
CREATE PROCEDURE sp_LoginUsuario(IN p_login VARCHAR(80),IN p_senha_hash VARCHAR(255))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED DEFAULT NULL;
 SET @sga_token=NULL;
 SELECT id_usuario INTO v_id FROM usuario
 WHERE login=p_login AND BINARY senha_hash=BINARY p_senha_hash;
 IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Login ou senha incorretos.'; END IF;
 DELETE FROM sessao_usuario WHERE expira_em<=NOW(6);
 SET @sga_token=HEX(RANDOM_BYTES(32));
 INSERT INTO sessao_usuario(token_hash,id_usuario,expira_em) VALUES(UNHEX(SHA2(@sga_token,256)),v_id,NOW(6)+INTERVAL 8 HOUR);
 SELECT id_usuario,nome,email,perfil,@sga_token AS token_sessao FROM usuario WHERE id_usuario=v_id;
END$$
CREATE PROCEDURE sp_LogoutUsuario()
SQL SECURITY DEFINER
BEGIN
 DELETE FROM sessao_usuario WHERE token_hash=UNHEX(SHA2(@sga_token,256));
 SET @sga_token=NULL;
END$$

CREATE PROCEDURE sp_validar_matricula(IN p_aluno INT UNSIGNED,IN p_turma INT UNSIGNED,IN p_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_status VARCHAR(20) DEFAULT NULL;
 DECLARE v_curso,v_curso_disc,v_disc,v_vagas,v_count INT UNSIGNED;
 DECLARE v_encerrada BOOLEAN; DECLARE v_semestre CHAR(6);
 CALL sp_exigir_perfil(p_usuario,FALSE);
 SELECT id_curso,status INTO v_curso,v_status FROM aluno WHERE id_aluno=p_aluno FOR UPDATE;
 IF v_status IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Aluno inexistente.'; END IF;
 IF v_status<>'Ativo' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN09: somente alunos Ativos podem realizar matrículas.'; END IF;
 SELECT id_disciplina,vagas,encerrada,semestre INTO v_disc,v_vagas,v_encerrada,v_semestre FROM turma WHERE id_turma=p_turma FOR UPDATE;
 IF v_disc IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma inexistente.'; END IF;
 IF v_encerrada THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma encerrada.'; END IF;
 SELECT id_curso INTO v_curso_disc FROM disciplina WHERE id_disciplina=v_disc;
 IF v_curso<>v_curso_disc THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma de outro curso.'; END IF;
 SELECT COUNT(*) INTO v_count FROM matricula WHERE id_turma=p_turma;
 IF v_count>=v_vagas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN05: turma lotada.'; END IF;
 IF EXISTS(SELECT 1 FROM pre_requisito pr WHERE pr.id_disciplina=v_disc AND NOT EXISTS(
   SELECT 1 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma
   WHERE m.id_aluno=p_aluno AND t.id_disciplina=pr.id_disciplina_requisito AND t.semestre<v_semestre AND m.situacao='Aprovado'
 )) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN06: falta aprovação em pré-requisito de semestre anterior.'; END IF;
END$$

CREATE TRIGGER trg_valida_vagas BEFORE INSERT ON matricula FOR EACH ROW
BEGIN
 CALL sp_validar_matricula(NEW.id_aluno,NEW.id_turma,NEW.id_usuario);
 IF NEW.n1 IS NOT NULL OR NEW.n2 IS NOT NULL OR NEW.exame IS NOT NULL OR NEW.faltas<>0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Crie a matrícula sem notas; utilize as procedures de lançamento.';
 END IF;
 SET NEW.media_final=NULL; SET NEW.situacao='Cursando';
END$$
CREATE TRIGGER trg_atualiza_situacao BEFORE UPDATE ON matricula FOR EACH ROW
BEGIN
 DECLARE v_aulas INT; DECLARE v_encerrada BOOLEAN;
 CALL sp_exigir_perfil(NEW.id_usuario,TRUE);
 IF NEW.id_aluno<>OLD.id_aluno OR NEW.id_turma<>OLD.id_turma OR NEW.data_matricula<>OLD.data_matricula THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Aluno, turma e data original da matrícula não podem ser alterados.';
 END IF;
 SELECT total_aulas,encerrada INTO v_aulas,v_encerrada FROM turma WHERE id_turma=NEW.id_turma FOR UPDATE;
 IF v_encerrada THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma encerrada: notas bloqueadas.'; END IF;
 IF NEW.faltas<0 OR NEW.faltas>v_aulas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltas fora do intervalo permitido.'; END IF;
 -- Notas fora de 0..10 são rejeitadas pelos CHECKs ck_n1/ck_n2/ck_exame.
 IF NEW.exame IS NOT NULL AND (NEW.n1 IS NULL OR NEW.n2 IS NULL OR (NEW.n1+NEW.n2)/2<4 OR (NEW.n1+NEW.n2)/2>=7 OR (v_aulas-NEW.faltas)*100<75*v_aulas) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Exame exige média parcial de 4 a menos de 7 e frequência de pelo menos 75%.';
 END IF;
 SET NEW.media_final=fn_calcular_media(NEW.n1,NEW.n2,NEW.exame);
 SET NEW.situacao=fn_situacao_valores(NEW.n1,NEW.n2,NEW.exame,NEW.faltas,v_aulas);
END$$
CREATE TRIGGER trg_auditoria_nota AFTER UPDATE ON matricula FOR EACH ROW
BEGIN
 DECLARE v_nome VARCHAR(150);
 SELECT nome INTO v_nome FROM usuario WHERE id_usuario=NEW.id_usuario;
 IF NOT(OLD.n1<=>NEW.n1) THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'n1',OLD.n1,NEW.n1,v_nome,NEW.id_usuario); END IF;
 IF NOT(OLD.n2<=>NEW.n2) THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'n2',OLD.n2,NEW.n2,v_nome,NEW.id_usuario); END IF;
 IF NOT(OLD.exame<=>NEW.exame) THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'exame',OLD.exame,NEW.exame,v_nome,NEW.id_usuario); END IF;
 IF OLD.faltas<>NEW.faltas THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'faltas',OLD.faltas,NEW.faltas,v_nome,NEW.id_usuario); END IF;
END$$
CREATE TRIGGER trg_preserva_matricula BEFORE DELETE ON matricula FOR EACH ROW
BEGIN
 CALL sp_exigir_perfil(fn_usuario_sessao(),FALSE);
 IF EXISTS(SELECT 1 FROM turma WHERE id_turma=OLD.id_turma AND encerrada=TRUE) OR OLD.n1 IS NOT NULL OR OLD.n2 IS NOT NULL OR OLD.exame IS NOT NULL OR EXISTS(SELECT 1 FROM log_nota WHERE id_matricula=OLD.id_matricula) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula encerrada ou com notas/auditoria deve ser preservada.';
 END IF;
END$$
CREATE TRIGGER trg_protege_turma BEFORE UPDATE ON turma FOR EACH ROW
BEGIN
 DECLARE v_count INT;
 IF OLD.encerrada THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma já encerrada.'; END IF;
 SELECT COUNT(*) INTO v_count FROM matricula WHERE id_turma=OLD.id_turma;
 IF NEW.vagas<v_count THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Vagas inferiores ao total de matriculados.'; END IF;
 IF v_count>0 AND (NEW.id_disciplina<>OLD.id_disciplina OR NEW.semestre<>OLD.semestre OR NEW.total_aulas<>OLD.total_aulas) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma com matrículas: disciplina, semestre e total de aulas são preservados.'; END IF;
 IF NEW.encerrada THEN CALL sp_exigir_perfil(NEW.encerrada_por,TRUE); SET NEW.encerrada_em=NOW(6); END IF;
END$$
CREATE TRIGGER trg_preserva_turma BEFORE DELETE ON turma FOR EACH ROW
BEGIN
 IF OLD.encerrada THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Turma encerrada não pode ser excluída.'; END IF;
END$$
CREATE TRIGGER trg_valida_pre_requisito BEFORE INSERT ON pre_requisito FOR EACH ROW
BEGIN
 DECLARE v_curso,v_curso_req,v_ciclo INT;
 SELECT id_curso INTO v_curso FROM disciplina WHERE id_disciplina=NEW.id_disciplina;
 SELECT id_curso INTO v_curso_req FROM disciplina WHERE id_disciplina=NEW.id_disciplina_requisito;
 IF v_curso<>v_curso_req THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pré-requisitos devem pertencer ao mesmo curso.'; END IF;
 WITH RECURSIVE dependencias(id,caminho) AS (
  SELECT id_disciplina_requisito,CAST(CONCAT(',',id_disciplina_requisito,',') AS CHAR(4000)) FROM pre_requisito WHERE id_disciplina=NEW.id_disciplina_requisito
  UNION ALL
  SELECT pr.id_disciplina_requisito,CONCAT(d.caminho,pr.id_disciplina_requisito,',') FROM pre_requisito pr JOIN dependencias d ON pr.id_disciplina=d.id
  WHERE LOCATE(CONCAT(',',pr.id_disciplina_requisito,','),d.caminho)=0
 ) SELECT COUNT(*) INTO v_ciclo FROM dependencias WHERE id=NEW.id_disciplina;
 IF v_ciclo>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pré-requisitos não podem formar ciclos.'; END IF;
END$$
CREATE TRIGGER trg_pr_sem_update BEFORE UPDATE ON pre_requisito FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Substitua pré-requisitos removendo e inserindo as relações.'; END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_matricular_aluno(IN p_id_aluno INT UNSIGNED,IN p_id_turma INT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 INSERT INTO matricula(id_aluno,id_turma,data_matricula,id_usuario) VALUES(p_id_aluno,p_id_turma,CURRENT_DATE,p_id_usuario);
 SET v_id=LAST_INSERT_ID(); COMMIT;
 SELECT v_id AS id_matricula;
END$$
CREATE PROCEDURE sp_lancar_notas(IN p_id_matricula INT UNSIGNED,IN p_n1 DECIMAL(4,2),IN p_n2 DECIMAL(4,2),IN p_faltas INT,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_turma INT UNSIGNED DEFAULT NULL; DECLARE v_lock INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 SELECT id_turma INTO v_turma FROM matricula WHERE id_matricula=p_id_matricula;
 IF v_turma IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula inexistente.'; END IF;
 SELECT id_turma INTO v_lock FROM turma WHERE id_turma=v_turma FOR UPDATE;
 UPDATE matricula SET n1=p_n1,n2=p_n2,exame=NULL,faltas=p_faltas,id_usuario=p_id_usuario WHERE id_matricula=p_id_matricula;
 COMMIT;
END$$
CREATE PROCEDURE sp_lancar_exame(IN p_id_matricula INT UNSIGNED,IN p_exame DECIMAL(4,2),IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_turma INT UNSIGNED DEFAULT NULL; DECLARE v_lock INT; DECLARE v_status VARCHAR(30);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 SELECT id_turma INTO v_turma FROM matricula WHERE id_matricula=p_id_matricula;
 IF v_turma IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula inexistente.'; END IF;
 SELECT id_turma INTO v_lock FROM turma WHERE id_turma=v_turma FOR UPDATE;
 SELECT situacao INTO v_status FROM matricula WHERE id_matricula=p_id_matricula FOR UPDATE;
 IF v_status<>'Em Exame' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Exame permitido somente na situação Em Exame.'; END IF;
 IF p_exame IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Informe a nota do exame.'; END IF;
 UPDATE matricula SET exame=p_exame,id_usuario=p_id_usuario WHERE id_matricula=p_id_matricula;
 COMMIT;
END$$
CREATE PROCEDURE sp_historico_aluno(IN p_id_aluno INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 CALL sp_exigir_perfil(fn_usuario_sessao(),FALSE);
 IF NOT EXISTS(SELECT 1 FROM aluno WHERE id_aluno=p_id_aluno) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Aluno inexistente.'; END IF;
 SELECT * FROM vw_boletim WHERE id_aluno=p_id_aluno ORDER BY semestre,disciplina,id_matricula;
END$$
CREATE PROCEDURE sp_fechar_semestre(IN p_semestre CHAR(6),IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_fim BOOLEAN DEFAULT FALSE; DECLARE v_turma INT UNSIGNED; DECLARE v_total INT DEFAULT 0;
 DECLARE turmas CURSOR FOR SELECT id_turma FROM turma WHERE semestre=p_semestre AND encerrada=FALSE ORDER BY id_turma FOR UPDATE;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim=TRUE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 OPEN turmas;
 leitura: LOOP
  FETCH turmas INTO v_turma;
  IF v_fim THEN LEAVE leitura; END IF;
  IF EXISTS(SELECT 1 FROM matricula WHERE id_turma=v_turma AND situacao IN ('Cursando','Em Exame')) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Há notas ou exames pendentes. Nenhuma turma foi encerrada.';
  END IF;
  -- Revalida os resultados via trigger, antes de bloquear a turma.
  UPDATE matricula SET id_usuario=p_id_usuario WHERE id_turma=v_turma;
  UPDATE turma SET encerrada=TRUE,encerrada_por=p_id_usuario WHERE id_turma=v_turma;
  SET v_total=v_total+1;
 END LOOP;
 CLOSE turmas;
 IF v_total=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Não há turmas abertas neste semestre.'; END IF;
 COMMIT;
 SELECT v_total AS turmas_encerradas;
END$$
CREATE PROCEDURE sp_adicionar_pre_requisito(IN p_disciplina INT UNSIGNED,IN p_requisito INT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION; CALL sp_exigir_perfil(p_id_usuario,TRUE);
 INSERT INTO pre_requisito VALUES(p_disciplina,p_requisito); COMMIT;
END$$
CREATE PROCEDURE sp_remover_pre_requisito(IN p_disciplina INT UNSIGNED,IN p_requisito INT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 DELETE FROM pre_requisito WHERE id_disciplina=p_disciplina AND id_disciplina_requisito=p_requisito;
END$$
CREATE PROCEDURE sp_salvar_aluno(IN p_id INT UNSIGNED, IN p_ra VARCHAR(30),
 IN p_nome VARCHAR(150),
 IN p_cpf CHAR(11),
 IN p_email VARCHAR(254),
 IN p_data_nascimento DATE,
 IN p_id_curso INT UNSIGNED,
 IN p_status VARCHAR(20),IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,FALSE);
 IF p_ra IS NULL OR CHAR_LENGTH(TRIM(p_ra))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha ra.'; END IF;
 IF p_nome IS NULL OR CHAR_LENGTH(TRIM(p_nome))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha nome.'; END IF;
 IF p_cpf IS NULL OR CHAR_LENGTH(TRIM(p_cpf))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha cpf.'; END IF;
 IF p_email IS NULL OR CHAR_LENGTH(TRIM(p_email))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha email.'; END IF;
 IF p_status IS NULL OR CHAR_LENGTH(TRIM(p_status))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha status.'; END IF;
 IF p_email NOT REGEXP '^[^ @]+@[^ @]+[.][^ @]+$' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E-mail inválido.'; END IF;
 IF p_data_nascimento>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nascimento no futuro.'; END IF;
 IF p_id IS NOT NULL AND EXISTS(SELECT 1 FROM aluno a WHERE a.id_aluno=p_id AND a.id_curso<>p_id_curso) AND EXISTS(SELECT 1 FROM matricula WHERE id_aluno=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Aluno com matrículas não pode trocar de curso.'; END IF;
 IF p_id IS NULL THEN
  INSERT INTO aluno(ra,nome,cpf,email,data_nascimento,id_curso,status) VALUES(p_ra,p_nome,p_cpf,p_email,p_data_nascimento,p_id_curso,p_status); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM aluno WHERE id_aluno=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
  UPDATE aluno SET ra=p_ra,nome=p_nome,cpf=p_cpf,email=p_email,data_nascimento=p_data_nascimento,id_curso=p_id_curso,status=p_status WHERE id_aluno=p_id; SET v_id=p_id;
 END IF;
 COMMIT;
 SELECT v_id AS id_aluno;
END$$
CREATE PROCEDURE sp_salvar_curso(IN p_id INT UNSIGNED, IN p_nome VARCHAR(150),
 IN p_carga_horaria_total INT UNSIGNED,
 IN p_turno VARCHAR(20),IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_nome IS NULL OR CHAR_LENGTH(TRIM(p_nome))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha nome.'; END IF;
 IF p_turno IS NULL OR CHAR_LENGTH(TRIM(p_turno))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha turno.'; END IF;
 
 IF p_id IS NULL THEN
  INSERT INTO curso(nome,carga_horaria_total,turno) VALUES(p_nome,p_carga_horaria_total,p_turno); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM curso WHERE id_curso=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
  UPDATE curso SET nome=p_nome,carga_horaria_total=p_carga_horaria_total,turno=p_turno WHERE id_curso=p_id; SET v_id=p_id;
 END IF;
 COMMIT;
 SELECT v_id AS id_curso;
END$$
CREATE PROCEDURE sp_salvar_disciplina(IN p_id INT UNSIGNED, IN p_id_curso INT UNSIGNED,
 IN p_nome VARCHAR(150),
 IN p_carga_horaria INT UNSIGNED,
 IN p_periodo SMALLINT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_nome IS NULL OR CHAR_LENGTH(TRIM(p_nome))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha nome.'; END IF;
 IF p_id IS NOT NULL AND EXISTS(SELECT 1 FROM disciplina WHERE id_disciplina=p_id AND id_curso<>p_id_curso) AND (EXISTS(SELECT 1 FROM turma WHERE id_disciplina=p_id) OR EXISTS(SELECT 1 FROM pre_requisito WHERE id_disciplina=p_id OR id_disciplina_requisito=p_id)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Disciplina vinculada não pode trocar de curso.'; END IF;
 IF p_id IS NULL THEN
  INSERT INTO disciplina(id_curso,nome,carga_horaria,periodo) VALUES(p_id_curso,p_nome,p_carga_horaria,p_periodo); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM disciplina WHERE id_disciplina=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
  UPDATE disciplina SET id_curso=p_id_curso,nome=p_nome,carga_horaria=p_carga_horaria,periodo=p_periodo WHERE id_disciplina=p_id; SET v_id=p_id;
 END IF;
 COMMIT;
 SELECT v_id AS id_disciplina;
END$$
CREATE PROCEDURE sp_salvar_professor(IN p_id INT UNSIGNED, IN p_nome VARCHAR(150),
 IN p_cpf CHAR(11),
 IN p_email VARCHAR(254),
 IN p_titulacao VARCHAR(80),
 IN p_data_admissao DATE,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_nome IS NULL OR CHAR_LENGTH(TRIM(p_nome))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha nome.'; END IF;
 IF p_cpf IS NULL OR CHAR_LENGTH(TRIM(p_cpf))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha cpf.'; END IF;
 IF p_email IS NULL OR CHAR_LENGTH(TRIM(p_email))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha email.'; END IF;
 IF p_titulacao IS NULL OR CHAR_LENGTH(TRIM(p_titulacao))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha titulacao.'; END IF;
 IF p_email NOT REGEXP '^[^ @]+@[^ @]+[.][^ @]+$' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E-mail inválido.'; END IF;
 IF p_data_admissao>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Admissão no futuro.'; END IF;
 IF p_id IS NULL THEN
  INSERT INTO professor(nome,cpf,email,titulacao,data_admissao) VALUES(p_nome,p_cpf,p_email,p_titulacao,p_data_admissao); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM professor WHERE id_professor=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
  UPDATE professor SET nome=p_nome,cpf=p_cpf,email=p_email,titulacao=p_titulacao,data_admissao=p_data_admissao WHERE id_professor=p_id; SET v_id=p_id;
 END IF;
 COMMIT;
 SELECT v_id AS id_professor;
END$$
CREATE PROCEDURE sp_salvar_turma(IN p_id INT UNSIGNED, IN p_id_disciplina INT UNSIGNED,
 IN p_id_professor INT UNSIGNED,
 IN p_semestre CHAR(6),
 IN p_vagas INT UNSIGNED,
 IN p_total_aulas INT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_semestre IS NULL OR CHAR_LENGTH(TRIM(p_semestre))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preencha semestre.'; END IF;
 
 IF p_id IS NULL THEN
  INSERT INTO turma(id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(p_id_disciplina,p_id_professor,p_semestre,p_vagas,p_total_aulas); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM turma WHERE id_turma=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
  UPDATE turma SET id_disciplina=p_id_disciplina,id_professor=p_id_professor,semestre=p_semestre,vagas=p_vagas,total_aulas=p_total_aulas WHERE id_turma=p_id; SET v_id=p_id;
 END IF;
 COMMIT;
 SELECT v_id AS id_turma;
END$$
CREATE PROCEDURE sp_salvar_usuario(IN p_id INT UNSIGNED,IN p_nome VARCHAR(150),IN p_cpf CHAR(11),IN p_email VARCHAR(254),IN p_login VARCHAR(80),IN p_senha_hash VARCHAR(255),IN p_perfil VARCHAR(20),IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION; CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_nome IS NULL OR p_login IS NULL OR CHAR_LENGTH(TRIM(p_nome))=0 OR CHAR_LENGTH(TRIM(p_login))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nome e login obrigatórios.'; END IF;
 IF p_email NOT REGEXP '^[^ @]+@[^ @]+[.][^ @]+$' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E-mail inválido.'; END IF;
 IF p_id IS NULL OR p_senha_hash IS NOT NULL THEN
  IF p_senha_hash IS NULL OR p_senha_hash NOT LIKE '$argon2id$%' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A aplicação deve fornecer um hash Argon2id válido.'; END IF;
 END IF;
 IF p_id IS NULL THEN
  INSERT INTO usuario(nome,cpf,email,login,senha_hash,perfil) VALUES(p_nome,p_cpf,p_email,p_login,p_senha_hash,p_perfil);
  SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM usuario WHERE id_usuario=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Usuário inexistente.'; END IF;
  IF p_perfil<>'Coordenador' AND EXISTS(SELECT 1 FROM usuario WHERE id_usuario=p_id AND perfil='Coordenador') AND (SELECT COUNT(*) FROM usuario WHERE perfil='Coordenador')=1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Mantenha ao menos um Coordenador.'; END IF;
  UPDATE usuario SET nome=p_nome,cpf=p_cpf,email=p_email,login=p_login,perfil=p_perfil,senha_hash=COALESCE(p_senha_hash,senha_hash) WHERE id_usuario=p_id;
  IF p_senha_hash IS NOT NULL THEN DELETE FROM sessao_usuario WHERE id_usuario=p_id; END IF;
  SET v_id=p_id;
 END IF;
 COMMIT; SELECT v_id AS id_usuario;
END$$
CREATE PROCEDURE sp_excluir_cadastro(IN p_tipo VARCHAR(30),IN p_id INT UNSIGNED,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_rows INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 CALL sp_exigir_perfil(p_id_usuario,p_tipo NOT IN ('aluno','matricula'));
 CASE p_tipo
 WHEN 'aluno' THEN DELETE FROM aluno WHERE id_aluno=p_id;
 WHEN 'matricula' THEN DELETE FROM matricula WHERE id_matricula=p_id;
 WHEN 'curso' THEN DELETE FROM curso WHERE id_curso=p_id;
 WHEN 'disciplina' THEN DELETE FROM disciplina WHERE id_disciplina=p_id;
 WHEN 'professor' THEN DELETE FROM professor WHERE id_professor=p_id;
 WHEN 'turma' THEN DELETE FROM turma WHERE id_turma=p_id;
 WHEN 'usuario' THEN
  IF p_id=p_id_usuario THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Não exclua seu próprio acesso.'; END IF;
  IF EXISTS(SELECT 1 FROM usuario WHERE id_usuario=p_id AND perfil='Coordenador') AND (SELECT COUNT(*) FROM usuario WHERE perfil='Coordenador')=1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Mantenha ao menos um Coordenador.'; END IF;
  DELETE FROM usuario WHERE id_usuario=p_id;
 ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Tipo de cadastro inválido.';
 END CASE;
 SET v_rows=ROW_COUNT();
 IF v_rows=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
 COMMIT;
END$$
CREATE PROCEDURE sp_faturamento_curso(IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 CALL sp_exigir_perfil(p_id_usuario,TRUE);
 SELECT c.id_curso,c.nome,COUNT(DISTINCT a.id_aluno) AS alunos,
  CAST(NULL AS DECIMAL(12,2)) AS faturamento,
  'Pendente: o enunciado não define mensalidades, cobranças ou pagamentos.' AS observacao
 FROM curso c LEFT JOIN aluno a ON a.id_curso=c.id_curso GROUP BY c.id_curso,c.nome;
END$$
DELIMITER ;

-- Views consultáveis somente com sessão autenticada. Sem acesso a hashes de senha.
CREATE SQL SECURITY DEFINER VIEW vw_boletim AS
 SELECT a.id_aluno,a.nome AS aluno,a.ra,c.nome AS curso,d.id_disciplina,d.nome AS disciplina,
 t.id_turma,t.semestre,m.id_matricula,m.data_matricula,m.n1,m.n2,m.exame,m.media_final,m.faltas,
 fn_frequencia(m.id_matricula) AS frequencia,m.situacao,m.id_usuario
 FROM matricula m JOIN aluno a ON a.id_aluno=m.id_aluno JOIN turma t ON t.id_turma=m.id_turma
 JOIN disciplina d ON d.id_disciplina=t.id_disciplina JOIN curso c ON c.id_curso=a.id_curso
 WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_turmas_lotacao AS
 SELECT t.id_turma,d.nome AS disciplina,p.nome AS professor,t.semestre,t.vagas AS vagas_totais,
 COUNT(m.id_matricula) AS matriculados,t.vagas-COUNT(m.id_matricula) AS vagas_restantes,
 ROUND(COUNT(m.id_matricula)*100.0/t.vagas,2) AS ocupacao_percentual,t.encerrada,t.total_aulas
 FROM turma t JOIN disciplina d ON d.id_disciplina=t.id_disciplina JOIN professor p ON p.id_professor=t.id_professor
 LEFT JOIN matricula m ON m.id_turma=t.id_turma WHERE fn_usuario_sessao() IS NOT NULL
 GROUP BY t.id_turma,d.nome,p.nome,t.semestre,t.vagas,t.encerrada,t.total_aulas;
CREATE SQL SECURITY DEFINER VIEW vw_desempenho_turma AS
 SELECT t.id_turma,d.nome AS disciplina,t.semestre,COUNT(m.id_matricula) AS matriculados,
 ROUND(AVG(m.media_final),4) AS media_global,MAX(m.media_final) AS maior_nota,MIN(m.media_final) AS menor_nota,
 ROUND(SUM(CASE WHEN m.situacao='Aprovado' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(m.id_matricula),0),2) AS aprovados_percentual,
 ROUND(SUM(CASE WHEN m.situacao IN ('Reprovado por Nota','Reprovado por Falta') THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(m.id_matricula),0),2) AS reprovados_percentual,
 SUM(CASE WHEN m.situacao IN ('Cursando','Em Exame') THEN 1 ELSE 0 END) AS pendentes
 FROM turma t JOIN disciplina d ON d.id_disciplina=t.id_disciplina LEFT JOIN matricula m ON m.id_turma=t.id_turma
 WHERE fn_perfil_sessao()='Coordenador' GROUP BY t.id_turma,d.nome,t.semestre;
CREATE SQL SECURITY DEFINER VIEW vw_alunos AS SELECT a.* FROM aluno a WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_cursos AS SELECT c.* FROM curso c WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_disciplinas AS SELECT d.* FROM disciplina d WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_pre_requisitos AS SELECT p.* FROM pre_requisito p WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_professores AS SELECT p.* FROM professor p WHERE fn_usuario_sessao() IS NOT NULL;
CREATE SQL SECURITY DEFINER VIEW vw_usuarios AS SELECT id_usuario,nome,cpf,email,login,perfil FROM usuario WHERE fn_perfil_sessao()='Coordenador';
CREATE SQL SECURITY DEFINER VIEW vw_auditoria_notas AS SELECT l.* FROM log_nota l WHERE fn_perfil_sessao()='Coordenador';

DELIMITER $$
-- Somente o servidor Rust recebe o hash: verifica a senha com Argon2id antes do login.
-- Esta procedure nunca é exposta diretamente ao navegador.
CREATE PROCEDURE sp_CredencialLogin(IN p_login VARCHAR(80)) SQL SECURITY DEFINER
BEGIN SELECT senha_hash FROM usuario WHERE login=p_login; END$$
CREATE PROCEDURE sp_UsarSessao(IN p_token VARCHAR(64)) SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED DEFAULT NULL;
 SET @sga_token=NULL;
 SELECT id_usuario INTO v_id FROM sessao_usuario WHERE token_hash=UNHEX(SHA2(p_token,256)) AND expira_em>NOW(6);
 IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sessão inválida ou expirada.'; END IF;
 SET @sga_token=p_token;
 SELECT id_usuario,nome,email,perfil FROM usuario WHERE id_usuario=v_id;
END$$
CREATE PROCEDURE sp_atualizar_avaliacao(IN p_id INT UNSIGNED,IN p_n1 DECIMAL(4,2),IN p_n2 DECIMAL(4,2),IN p_exame DECIMAL(4,2),IN p_faltas INT,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_turma INT UNSIGNED DEFAULT NULL; DECLARE v_lock INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION; CALL sp_exigir_perfil(p_id_usuario,TRUE);
 SELECT id_turma INTO v_turma FROM matricula WHERE id_matricula=p_id;
 IF v_turma IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Matrícula inexistente.'; END IF;
 SELECT id_turma INTO v_lock FROM turma WHERE id_turma=v_turma FOR UPDATE;
 UPDATE matricula SET n1=p_n1,n2=p_n2,exame=p_exame,faltas=p_faltas,id_usuario=p_id_usuario WHERE id_matricula=p_id;
 COMMIT;
END$$
CREATE PROCEDURE sp_salvar_disciplina_requisitos(IN p_id INT UNSIGNED,IN p_id_curso INT UNSIGNED,IN p_nome VARCHAR(150),IN p_carga INT UNSIGNED,IN p_periodo INT UNSIGNED,IN p_requisitos JSON,IN p_id_usuario INT UNSIGNED)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_id INT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION; CALL sp_exigir_perfil(p_id_usuario,TRUE);
 IF p_requisitos IS NULL OR JSON_TYPE(p_requisitos)<>'ARRAY' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lista de pré-requisitos inválida.'; END IF;
 IF p_id IS NULL THEN
  INSERT INTO disciplina(id_curso,nome,carga_horaria,periodo) VALUES(p_id_curso,p_nome,p_carga,p_periodo); SET v_id=LAST_INSERT_ID();
 ELSE
  IF NOT EXISTS(SELECT 1 FROM disciplina WHERE id_disciplina=p_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Disciplina inexistente.'; END IF;
  IF EXISTS(SELECT 1 FROM disciplina WHERE id_disciplina=p_id AND id_curso<>p_id_curso) AND (EXISTS(SELECT 1 FROM turma WHERE id_disciplina=p_id) OR EXISTS(SELECT 1 FROM pre_requisito WHERE id_disciplina=p_id OR id_disciplina_requisito=p_id)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Disciplina vinculada não pode trocar de curso.'; END IF;
  UPDATE disciplina SET id_curso=p_id_curso,nome=p_nome,carga_horaria=p_carga,periodo=p_periodo WHERE id_disciplina=p_id; SET v_id=p_id;
 END IF;
 DELETE FROM pre_requisito WHERE id_disciplina=v_id;
 INSERT INTO pre_requisito(id_disciplina,id_disciplina_requisito) SELECT v_id,j.requisito FROM JSON_TABLE(p_requisitos,'$[*]' COLUMNS(requisito INT UNSIGNED PATH '$' ERROR ON ERROR)) j;
 COMMIT; SELECT v_id AS id_disciplina;
END$$
CREATE PROCEDURE sp_dados_sistema(IN p_id_usuario INT UNSIGNED) SQL SECURITY DEFINER
BEGIN
 DECLARE v_dados JSON;
 CALL sp_exigir_perfil(p_id_usuario,FALSE);
 SET v_dados=JSON_OBJECT('alunos',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_aluno,'ra',t.ra,'nome',t.nome,'cpf',t.cpf,'email',t.email,'nascimento',t.data_nascimento,'curso_id',t.id_curso,'status',t.status)),JSON_ARRAY()) FROM aluno t),'cursos',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_curso,'nome',t.nome,'carga_horaria',t.carga_horaria_total,'turno',t.turno)),JSON_ARRAY()) FROM curso t),'disciplinas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_disciplina,'curso_id',t.id_curso,'nome',t.nome,'carga_horaria',t.carga_horaria,'periodo',t.periodo,'requisitos',(SELECT COALESCE(JSON_ARRAYAGG(pr.id_disciplina_requisito),JSON_ARRAY()) FROM pre_requisito pr WHERE pr.id_disciplina=t.id_disciplina))),JSON_ARRAY()) FROM disciplina t),'professores',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_professor,'nome',t.nome,'cpf',t.cpf,'email',t.email,'titulacao',t.titulacao,'admissao',t.data_admissao)),JSON_ARRAY()) FROM professor t),'turmas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_turma,'disciplina_id',t.id_disciplina,'professor_id',t.id_professor,'semestre',t.semestre,'vagas',t.vagas,'total_aulas',t.total_aulas,'encerrada',CAST(IF(t.encerrada,'true','false') AS JSON))),JSON_ARRAY()) FROM turma t),'matriculas',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_matricula,'aluno_id',t.id_aluno,'turma_id',t.id_turma,'data',t.data_matricula,'n1',t.n1,'n2',t.n2,'exame',t.exame,'faltas',t.faltas,'media_final',t.media_final,'situacao',t.situacao,'frequencia',fn_frequencia(t.id_matricula),'usuario_id',t.id_usuario)),JSON_ARRAY()) FROM matricula t));
 IF fn_perfil_sessao()='Coordenador' THEN
 SET v_dados=JSON_SET(v_dados,'$.usuarios',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_usuario,'nome',t.nome,'cpf',t.cpf,'email',t.email,'login',t.login,'perfil',t.perfil)),JSON_ARRAY()) FROM usuario t),'$.auditoria',(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',t.id_log,'matricula_id',t.id_matricula,'campo',t.campo,'anterior',t.valor_antigo,'novo',t.valor_novo,'usuario',t.usuario,'usuario_id',t.id_usuario,'data_hora',DATE_FORMAT(t.data_hora,'%Y-%m-%dT%H:%i:%s.000Z'))),JSON_ARRAY()) FROM log_nota t));
 END IF;
 SELECT v_dados AS dados;
END$$
DELIMITER ;


USE sga_fbi_testes;
SET NAMES utf8mb4;
-- Dados fictícios de demonstração. Senha de todas as contas: Fbi@2026.
START TRANSACTION;
INSERT INTO usuario(id_usuario,nome,cpf,email,login,senha_hash,perfil) VALUES(1,'Helena Martins','91000000001','usuario1@fbi.edu.br','coordenador','$argon2id$v=19$m=19456,t=2,p=1$mBMnssSQhUCoy715soOZMA$mfeNIvBGmT3d+Ui7ko8aPLExfEbNIZZUj71rCLAyTEc','Coordenador');
INSERT INTO usuario(id_usuario,nome,cpf,email,login,senha_hash,perfil) VALUES(2,'Rafael Costa','91000000002','usuario2@fbi.edu.br','coordenador2','$argon2id$v=19$m=19456,t=2,p=1$GsCQ0AbqC1AWfvjR4Kn2Hw$YaiKgH2Ryei3s8mpoE/IxXEZ2KXuAN1R0cd6JIPgDIo','Coordenador');
INSERT INTO usuario(id_usuario,nome,cpf,email,login,senha_hash,perfil) VALUES(3,'Marina Alves','91000000003','usuario3@fbi.edu.br','secretario','$argon2id$v=19$m=19456,t=2,p=1$oaTzQ8UZU9YatRHPR0mYag$0rCFPSVyKFJehWCOU7lWj034+Igi7LdIrG53RIt2N0c','Secretario');
INSERT INTO usuario(id_usuario,nome,cpf,email,login,senha_hash,perfil) VALUES(4,'Lucas Ribeiro','91000000004','usuario4@fbi.edu.br','secretario2','$argon2id$v=19$m=19456,t=2,p=1$S3QKWa7y6RE5zOqo77/98A$oS4vnZmiqNi59evZfZOdE78mjJjzZEYv33I4xfEp5g0','Secretario');
INSERT INTO usuario(id_usuario,nome,cpf,email,login,senha_hash,perfil) VALUES(5,'Camila Rocha','91000000005','usuario5@fbi.edu.br','secretario3','$argon2id$v=19$m=19456,t=2,p=1$6cOhB1cYUTtnywt9SLCJGg$6azQ6qW67f73qSrDWpSiDHwjnJ5x9M7/PK9+I/zyzlI','Secretario');
INSERT INTO curso VALUES(1,'Sistemas de Informação',3200,'Noturno');
INSERT INTO curso VALUES(2,'Administração',3000,'Matutino');
INSERT INTO curso VALUES(3,'Engenharia de Software',3600,'Noturno');
INSERT INTO disciplina VALUES(1,1,'Algoritmos e Programação',80,1);
INSERT INTO disciplina VALUES(2,1,'Banco de Dados I',80,2);
INSERT INTO disciplina VALUES(3,1,'Banco de Dados II',80,3);
INSERT INTO disciplina VALUES(4,2,'Fundamentos de Gestão',80,1);
INSERT INTO disciplina VALUES(5,2,'Gestão de Pessoas',80,2);
INSERT INTO disciplina VALUES(6,3,'Engenharia de Requisitos',80,1);
INSERT INTO pre_requisito VALUES(3,2);
INSERT INTO professor VALUES(1,'Ana Beatriz Souza','82000000001','docente1@fbi.edu.br','Doutorado','2022-02-01');
INSERT INTO professor VALUES(2,'Carlos Eduardo Lima','82000000002','docente2@fbi.edu.br','Mestrado','2022-02-01');
INSERT INTO professor VALUES(3,'Fernanda Oliveira','82000000003','docente3@fbi.edu.br','Doutorado','2022-02-01');
INSERT INTO professor VALUES(4,'Pedro Henrique Melo','82000000004','docente4@fbi.edu.br','Mestrado','2022-02-01');
INSERT INTO professor VALUES(5,'Juliana Nascimento','82000000005','docente5@fbi.edu.br','Doutorado','2022-02-01');
INSERT INTO aluno VALUES(1,'20260001','Alice Fernandes','73000000001','aluno1@fbi.edu.br','2004-01-15',1,'Ativo');
INSERT INTO aluno VALUES(2,'20260002','Bruno Carvalho','73000000002','aluno2@fbi.edu.br','2004-02-15',1,'Ativo');
INSERT INTO aluno VALUES(3,'20260003','Clara Mendes','73000000003','aluno3@fbi.edu.br','2004-03-15',1,'Ativo');
INSERT INTO aluno VALUES(4,'20260004','Daniel Santos','73000000004','aluno4@fbi.edu.br','2004-04-15',1,'Ativo');
INSERT INTO aluno VALUES(5,'20260005','Eduarda Lima','73000000005','aluno5@fbi.edu.br','2004-05-15',1,'Ativo');
INSERT INTO aluno VALUES(6,'20260006','Felipe Rodrigues','73000000006','aluno6@fbi.edu.br','2004-06-15',1,'Ativo');
INSERT INTO aluno VALUES(7,'20260007','Gabriela Azevedo','73000000007','aluno7@fbi.edu.br','2004-07-15',1,'Ativo');
INSERT INTO aluno VALUES(8,'20260008','Henrique Barros','73000000008','aluno8@fbi.edu.br','2004-08-15',1,'Ativo');
INSERT INTO aluno VALUES(9,'20260009','Isabela Duarte','73000000009','aluno9@fbi.edu.br','2004-09-15',1,'Ativo');
INSERT INTO aluno VALUES(10,'20260010','João Vitor Silva','73000000010','aluno10@fbi.edu.br','2004-10-15',1,'Ativo');
INSERT INTO aluno VALUES(11,'20260011','Laura Teixeira','73000000011','aluno11@fbi.edu.br','2004-11-15',1,'Ativo');
INSERT INTO aluno VALUES(12,'20260012','Matheus Almeida','73000000012','aluno12@fbi.edu.br','2004-12-15',1,'Ativo');
INSERT INTO aluno VALUES(13,'20260013','Natália Pereira','73000000013','aluno13@fbi.edu.br','2004-01-15',2,'Ativo');
INSERT INTO aluno VALUES(14,'20260014','Otávio Gomes','73000000014','aluno14@fbi.edu.br','2004-02-15',2,'Ativo');
INSERT INTO aluno VALUES(15,'20260015','Paula Monteiro','73000000015','aluno15@fbi.edu.br','2004-03-15',2,'Ativo');
INSERT INTO aluno VALUES(16,'20260016','Renan Cardoso','73000000016','aluno16@fbi.edu.br','2004-04-15',2,'Ativo');
INSERT INTO aluno VALUES(17,'20260017','Sofia Batista','73000000017','aluno17@fbi.edu.br','2004-05-15',2,'Ativo');
INSERT INTO aluno VALUES(18,'20260018','Thiago Correia','73000000018','aluno18@fbi.edu.br','2004-06-15',2,'Ativo');
INSERT INTO aluno VALUES(19,'20260019','Valentina Dias','73000000019','aluno19@fbi.edu.br','2004-07-15',2,'Ativo');
INSERT INTO aluno VALUES(20,'20260020','Vinícius Freitas','73000000020','aluno20@fbi.edu.br','2004-08-15',2,'Trancado');
INSERT INTO turma(id_turma,id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(1,1,1,'2026.2',30,80);
INSERT INTO turma(id_turma,id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(2,2,2,'2026.1',30,80);
INSERT INTO turma(id_turma,id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(3,3,3,'2026.2',30,80);
INSERT INTO turma(id_turma,id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(4,4,4,'2026.2',30,80);
INSERT INTO turma(id_turma,id_disciplina,id_professor,semestre,vagas,total_aulas) VALUES(5,5,5,'2026.2',30,80);
COMMIT;
CALL sp_LoginUsuario('secretario','$argon2id$v=19$m=19456,t=2,p=1$oaTzQ8UZU9YatRHPR0mYag$0rCFPSVyKFJehWCOU7lWj034+Igi7LdIrG53RIt2N0c');
START TRANSACTION;
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(1,1,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(2,1,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(3,2,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(4,2,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(5,3,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(6,3,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(7,4,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(8,4,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(9,5,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(10,5,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(11,6,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(12,6,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(13,7,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(14,7,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(15,8,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(16,8,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(17,9,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(18,9,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(19,10,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(20,10,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(21,11,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(22,11,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(23,12,1,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(24,12,2,'2026-02-10',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(25,13,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(26,14,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(27,15,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(28,16,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(29,17,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(30,18,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(31,19,4,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(32,13,5,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(33,14,5,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(34,15,5,'2026-07-20',3);
INSERT INTO matricula(id_matricula,id_aluno,id_turma,data_matricula,id_usuario) VALUES(35,16,5,'2026-07-20',3);
COMMIT;
CALL sp_LoginUsuario('coordenador','$argon2id$v=19$m=19456,t=2,p=1$mBMnssSQhUCoy715soOZMA$mfeNIvBGmT3d+Ui7ko8aPLExfEbNIZZUj71rCLAyTEc');
CALL sp_lancar_notas(1,5,5,1,1);
CALL sp_lancar_notas(2,8,7.5,1,1);
CALL sp_lancar_notas(3,6,6,2,1);
CALL sp_lancar_notas(4,8,7.5,2,1);
CALL sp_lancar_notas(5,7,7,3,1);
CALL sp_lancar_notas(6,8,7.5,3,1);
CALL sp_lancar_notas(7,8,8,4,1);
CALL sp_lancar_notas(8,8,7.5,4,1);
CALL sp_lancar_notas(9,9,4,0,1);
CALL sp_lancar_notas(10,8,7.5,0,1);
CALL sp_lancar_notas(11,4,5,1,1);
CALL sp_lancar_notas(12,8,7.5,1,1);
CALL sp_lancar_notas(13,5,6,2,1);
CALL sp_lancar_notas(14,8,7.5,2,1);
CALL sp_lancar_notas(15,6,7,3,1);
CALL sp_lancar_notas(16,8,7.5,3,1);
CALL sp_lancar_notas(17,7,8,4,1);
CALL sp_lancar_notas(18,8,7.5,4,1);
CALL sp_lancar_notas(19,8,4,0,1);
CALL sp_lancar_notas(20,8,7.5,0,1);
CALL sp_lancar_notas(21,9,5,1,1);
CALL sp_lancar_notas(22,8,7.5,1,1);
CALL sp_lancar_notas(23,4,6,2,1);
CALL sp_lancar_notas(24,8,7.5,2,1);
CALL sp_lancar_notas(25,8,7,4,1);
CALL sp_lancar_notas(26,8,7,4,1);
CALL sp_lancar_notas(27,8,7,4,1);
CALL sp_lancar_notas(28,8,7,4,1);
CALL sp_lancar_notas(29,8,7,4,1);
CALL sp_lancar_notas(30,8,7,4,1);
CALL sp_lancar_notas(31,8,7,4,1);
CALL sp_LogoutUsuario();
-- Conferência da massa mínima.
SELECT 'usuario' AS tabela,COUNT(*) AS quantidade FROM usuario UNION ALL SELECT 'curso',COUNT(*) FROM curso UNION ALL SELECT 'disciplina',COUNT(*) FROM disciplina UNION ALL SELECT 'professor',COUNT(*) FROM professor UNION ALL SELECT 'aluno',COUNT(*) FROM aluno UNION ALL SELECT 'turma',COUNT(*) FROM turma UNION ALL SELECT 'matricula',COUNT(*) FROM matricula;


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
