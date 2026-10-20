USE sga_fbi;
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
