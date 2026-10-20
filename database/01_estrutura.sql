USE sga_fbi;
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
