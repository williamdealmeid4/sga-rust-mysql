# Explicação pronta: construção do SGA em SQL e Rust

Os números de linha correspondem aos arquivos locais conferidos em 26/10/2026.

## Slide 01 - Sistema de Gestão Acadêmica

O SGA centraliza alunos, turmas, matrículas e avaliações. O foco desta apresentação é explicar como o SQL e o Rust trabalham juntos para gravar dados de verdade no MySQL.

Fonte: TrabalhoFinalLBD-2.pdf, páginas 1-5

## Slide 02 - Organização do backend em Rust

As linhas 1-2 separam regras de domínio e acesso ao banco. App mantém o repositório; Arc compartilha esse estado entre as requisições.

Arquivo: src/main.rs

**Linhas destacadas:** 1, 2, 12, 21, 24

```text
1: mod domain;
2: mod mysql_repo;
12: use mysql_repo::{db_error, user_row, Repository};
20: struct App {
21:     repo: Repository,
22:     attempts: Mutex<HashMap<String, (u32, Instant)>>,
23: }
24: type Shared = Arc<App>;
```

## Slide 03 - SQL: criação da tabela de alunos

L47 define ID e RA único. L48 impede CPF/e-mail repetidos. L50 exige um curso válido; L51 restringe os status aceitos.

Arquivo: database/01_estrutura.sql

**Linhas destacadas:** 47, 48, 50, 51

```text
46: CREATE TABLE aluno (
47:  id_aluno INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, ra VARCHAR(30) NOT NULL UNIQUE,
48:  nome VARCHAR(150) NOT NULL, cpf CHAR(11) NOT NULL UNIQUE, email VARCHAR(254) NOT NULL UNIQUE,
49:  data_nascimento DATE NOT NULL, id_curso INT UNSIGNED NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'Ativo',
50:  CONSTRAINT fk_aluno_curso FOREIGN KEY (id_curso) REFERENCES curso(id_curso),
51:  CONSTRAINT ck_aluno_status CHECK (status IN ('Ativo','Trancado','Formado')),
55: ) ENGINE=InnoDB;
```

## Slide 04 - SQL: integridade da matrícula

L77 impede matrícula duplicada. As FKs ligam aluno, turma e usuário. L81-83 aceitam apenas notas entre 0 e 10, ou NULL antes do lançamento.

Arquivo: database/01_estrutura.sql

**Linhas destacadas:** 77, 78, 79, 81, 82, 83

```text
71: CREATE TABLE matricula (
72:  id_matricula INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, id_aluno INT UNSIGNED NOT NULL,
73:  id_turma INT UNSIGNED NOT NULL, data_matricula DATE NOT NULL,
77:  CONSTRAINT uq_aluno_turma UNIQUE (id_aluno,id_turma),
78:  CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno) REFERENCES aluno(id_aluno),
79:  CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma) REFERENCES turma(id_turma),
80:  CONSTRAINT fk_matricula_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
81:  CONSTRAINT ck_n1 CHECK (n1 IS NULL OR n1 BETWEEN 0 AND 10),
82:  CONSTRAINT ck_n2 CHECK (n2 IS NULL OR n2 BETWEEN 0 AND 10),
83:  CONSTRAINT ck_exame CHECK (exame IS NULL OR exame BETWEEN 0 AND 10),
```

## Slide 05 - Relacionamentos do modelo

A matrícula relaciona aluno e turma. Curso, disciplina e professor ficam em suas próprias tabelas; as chaves estrangeiras preservam essas relações sem repetir os mesmos dados em cada matrícula.

Fonte: database/01_estrutura.sql:16-86

## Slide 06 - Rust inicializa o servidor e conecta ao banco

main.rs:201 carrega a configuração e L252 abre o localhost. Repository::connect exige TLS (L65) e cria o pool (L71-75); main.rs:203 inicia a conexão.

Arquivo: src/main.rs

**Linhas destacadas:** 201, 252, 254

```text
199: #[tokio::main]
200: async fn main() -> Result<(), Box<dyn std::error::Error>> {
201:     let _ = dotenvy::from_filename(".env.local");
251:     let port = std::env::var("SGA_PORT").unwrap_or_else(|_| "3030".into());
252:     let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{port}")).await?;
254:     axum::serve(listener, app)
```

Arquivo: src/mysql_repo.rs

**Linhas destacadas:** 65, 72, 74, 75

```text
65:         let opts = MySqlConnectOptions::from_str(url)?.ssl_mode(MySqlSslMode::Required);
71:         let pool = MySqlPoolOptions::new()
72:             .max_connections(8)
73:             .acquire_timeout(Duration::from_secs(8))
74:             .connect_with(opts)
75:             .await?;
```

## Slide 07 - Rust: rotas que recebem o CRUD

L241 recebe o POST de criação. L243-244 recebem o ID para PUT ou DELETE. Cada rota encaminha a requisição para uma função Rust específica.

Arquivo: src/main.rs

**Linhas destacadas:** 240, 241, 243, 244, 246

```text
237:         .route("/api/login", post(login))
240:         .route("/api/data", get(data))
241:         .route("/api/records/{kind}", post(create))
242:         .route(
243:             "/api/records/{kind}/{id}",
244:             axum::routing::put(update).delete(delete),
245:         )
246:         .route("/api/grades/{id}", post(grades))
247:         .route("/api/close", post(close))
```

## Slide 08 - Autenticação: Rust verifica; SQL abre a sessão

Rust verifica a senha com Argon2id. A procedure confere as credenciais e devolve o usuário e seu perfil; o token de sessão é emitido pelo banco.

Arquivo: src/main.rs

**Linhas destacadas:** 95, 114

```text
94:             Argon2::default()
95:                 .verify_password(password.as_bytes(), &h)
96:                 .is_ok()
114:     let row = sqlx::query("CALL sp_LoginUsuario(?,?)")
115:         .bind(&login)
116:         .bind(proof)
```

Arquivo: database/02_programacao.sql

**Linhas destacadas:** 81, 82, 86

```text
80:  SELECT id_usuario INTO v_id FROM usuario
81:  WHERE login=p_login AND BINARY senha_hash=BINARY p_senha_hash;
82:  IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Login ou senha incorretos.'; END IF;
86:  SELECT id_usuario,nome,email,perfil,@sga_token AS token_sessao FROM usuario WHERE id_usuario=v_id;
```

## Slide 09 - Validação antes e durante a gravação

O Rust valida campos, curso e unicidade. No MySQL, UNIQUE, FOREIGN KEY e CHECK também impedem dados inconsistentes, inclusive entre requisições concorrentes.

Arquivo: src/domain.rs

**Linhas destacadas:** 240, 242, 243, 245

```text
239:                 self.required_person(kind, v)?;
240:                 Self::required(v, &["ra", "status", "nascimento"])?;
241:                 Self::date(v, "nascimento")?;
242:                 self.find("cursos", id(v, "curso_id"))?;
243:                 self.unique(kind, v, &["ra"])?;
244:                 if !["Ativo", "Trancado", "Formado"].contains(&text(v, "status")) {
245:                     return Err("Status de aluno inválido.".into());
```

Arquivo: database/01_estrutura.sql

**Linhas destacadas:** 47, 50, 51

```text
47:  id_aluno INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, ra VARCHAR(30) NOT NULL UNIQUE,
50:  CONSTRAINT fk_aluno_curso FOREIGN KEY (id_curso) REFERENCES curso(id_curso),
51:  CONSTRAINT ck_aluno_status CHECK (status IN ('Ativo','Trancado','Formado')),
52:  CONSTRAINT ck_aluno_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
```

## Slide 10 - Inserção: pedido Rust e INSERT no MySQL

Na API, main.rs:163 passa None para criar. No repositório, L157 chama sp_salvar_aluno; no SQL, L299 insere e L304 confirma a transação.

Arquivo: src/mysql_repo.rs

**Linhas destacadas:** 157, 158, 167

```text
157:                 sqlx::query("CALL sp_salvar_aluno(?,?,?,?,?,?,?,?,?)")
158:                     .bind(key)
159:                     .bind(text(&v, "ra"))
160:                     .bind(text(&v, "nome"))
167:                     .fetch_one(&mut **conn)
168:                     .await
```

Arquivo: database/02_programacao.sql

**Linhas destacadas:** 299, 304, 305

```text
298:  IF p_id IS NULL THEN
299:   INSERT INTO aluno(ra,nome,cpf,email,data_nascimento,id_curso,status) VALUES(p_ra,p_nome,p_cpf,p_email,p_data_nascimento,p_id_curso,p_status); SET v_id=LAST_INSERT_ID();
304:  COMMIT;
305:  SELECT v_id AS id_aluno;
```

## Slide 11 - Edição: o ID identifica a mesma linha

Some(key), em main.rs:172, identifica o aluno existente. O UPDATE da linha 302 usa WHERE id_aluno=p_id: os valores mudam e o ID é preservado.

Arquivo: src/main.rs

**Linhas destacadas:** 168, 172

```text
168:     Path((kind, key)): Path<(String, u64)>,
172:     Repository::upsert(&mut conn, &user, &kind, Some(key), body).await
```

Arquivo: database/02_programacao.sql

**Linhas destacadas:** 302, 304

```text
302:   UPDATE aluno SET ra=p_ra,nome=p_nome,cpf=p_cpf,email=p_email,data_nascimento=p_data_nascimento,id_curso=p_id_curso,status=p_status WHERE id_aluno=p_id; SET v_id=p_id;
304:  COMMIT;
305:  SELECT v_id AS id_aluno;
```

## Slide 12 - Exclusão: a procedure remove o cadastro

Rust envia tabela, ID e usuário como parâmetros. A linha 428 executa o DELETE; L441 recusa um ID inexistente. FKs e regras podem impedir a remoção de um registro vinculado.

Arquivo: src/mysql_repo.rs

**Linhas destacadas:** 324, 326, 328

```text
324:         sqlx::query("CALL sp_excluir_cadastro(?,?,?)")
325:             .bind(table)
326:             .bind(key)
327:             .bind(actor)
328:             .execute(&mut **conn)
329:             .await
```

Arquivo: database/02_programacao.sql

**Linhas destacadas:** 428, 441, 442

```text
428:  WHEN 'aluno' THEN DELETE FROM aluno WHERE id_aluno=p_id;
440:  SET v_rows=ROW_COUNT();
441:  IF v_rows=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
442:  COMMIT;
```

## Slide 13 - Rust consulta o resultado persistido

Em src/mysql_repo.rs:283, o repositório consulta o MySQL após a procedure. A linha 286 localiza o ID retornado e a linha 289 devolve o registro. Em web/app.js:151, a interface recarrega os dados e renderiza o resultado.

Fonte: src/mysql_repo.rs:282-289

Fonte: web/app.js:151

## Slide 14 - CRUD observado na tabela aluno

Ao cadastrar um aluno, o MySQL recebe uma nova linha. Na edição, o mesmo ID passa a ter os novos valores. Na exclusão sem vínculos protegidos, a linha é removida. O SELECT da tabela aluno comprova cada resultado.

Fonte: apresentacao/DEMO_CRUD_AO_VIVO.sql

## Slide 15 - Procedure de validação de matrícula

As linhas 104 e 111 de 02_programacao.sql rejeitam aluno inativo e turma lotada. As linhas 112-115 verificam aprovação no pré-requisito em semestre anterior. SIGNAL devolve a causa da recusa.

Fonte: database/02_programacao.sql:95-115

## Slide 16 - Funções de média e situação

A média parcial é calculada na linha 10. A linha 11 incorpora a nota do exame. A linha 18 dá prioridade à reprovação por falta. Com N1=6, N2=6 e exame=4, a média final é 5; presença abaixo de 75% continua reprovando.

Fonte: database/02_programacao.sql:5-25

## Slide 17 - Auditoria automática por trigger

A trigger AFTER UPDATE começa na linha 143. Nas linhas 147 e 150, ela compara valores antigos e novos e insere o registro de auditoria com matrícula, campo, valores e usuário responsável.

Fonte: database/02_programacao.sql:143-150

## Slide 18 - SQL: criação da view de boletim

L460-461 relacionam matrícula, aluno, turma, disciplina e curso. L459 calcula a frequência. L462 exige sessão; sem ela, a view protegida não expõe registros.

Arquivo: database/02_programacao.sql

**Linhas destacadas:** 456, 459, 460, 461, 462

```text
456: CREATE SQL SECURITY DEFINER VIEW vw_boletim AS
457:  SELECT a.id_aluno,a.nome AS aluno,a.ra,c.nome AS curso,d.id_disciplina,d.nome AS disciplina,
458:  t.id_turma,t.semestre,m.id_matricula,m.data_matricula,m.n1,m.n2,m.exame,m.media_final,m.faltas,
459:  fn_frequencia(m.id_matricula) AS frequencia,m.situacao,m.id_usuario
460:  FROM matricula m JOIN aluno a ON a.id_aluno=m.id_aluno JOIN turma t ON t.id_turma=m.id_turma
461:  JOIN disciplina d ON d.id_disciplina=t.id_disciplina JOIN curso c ON c.id_curso=a.id_curso
462:  WHERE fn_usuario_sessao() IS NOT NULL;
```

## Slide 19 - Rust: o erro do banco vira mensagem

L24 preserva os erros de regra enviados por SIGNAL. L25 trata duplicidade; L26, exclusão com vínculos; L30, violação de CHECK. A API devolve erro em vez de confirmar sucesso.

Arquivo: src/mysql_repo.rs

**Linhas destacadas:** 24, 25, 26, 30, 39

```text
23:         let message = match number {
24:             1644 => db.message().to_owned(),
25:             1062 => "Já existe um registro com este CPF, e-mail, RA, nome ou vínculo.".into(),
26:             1451 => "Este registro está vinculado a outros dados e deve ser preservado.".into(),
30:             3819 => "Valor inválido: confira notas de 0 a 10, campos e limites do cadastro.".into(),
39:         return ApiError(status, message);
```

## Slide 20 - Cursores e transações no fechamento

Em 02_programacao.sql:242, o cursor seleciona as turmas. L244 declara ROLLBACK e RESIGNAL para erros. A validação de perfil ocorre na linha 246; pendências geram erro na linha 252. O COMMIT só ocorre na linha 261, após o processamento.

Fonte: database/02_programacao.sql:238-262

## Slide 21 - Testes da integração

Os 49 testes de integração verificaram operações da API e a persistência no MySQL isolado. Testes adicionais cobriram cobrança pendente e bloqueio de troca de vínculo da matrícula. Os testes de interface validaram o fluxo de novo aluno e a recuperação após erros.

Fonte: database/RESULTADOS_INTEGRACAO.txt

Fonte: database/RESULTADOS_CRUD_ATUAL.txt

Fonte: scripts/enrollment_test.cjs

## Slide 22 - Dificuldades e soluções

A compilação usou o toolchain GNU instalado. O banco existente é consultado sem repetir sua instalação. Transações, restrições e auditoria mantêm consistência e histórico, inclusive quando uma operação precisa ser recusada.

Fonte: README.md

Fonte: database/02_programacao.sql

## Slide 23 - Integração completa das camadas

No formulário, cadastramos os dados do aluno. A API Rust autentica a sessão e chama a procedure. O MySQL executa a operação, aplica as regras e confirma a transação. A aplicação consulta novamente os dados persistidos e atualiza a interface.

Fonte: web/app.js:147-151

Fonte: src/mysql_repo.rs:157-168

Fonte: src/mysql_repo.rs:282-289

## Slide 24 - Conclusão: persistência comprovada

A inclusão cria a linha, a edição altera a linha identificada pelo ID e a exclusão remove a linha quando as regras permitem. A confirmação visual precisa corresponder ao resultado no MySQL; operações recusadas preservam o banco.

Fonte: database/02_programacao.sql:277-306

Fonte: database/02_programacao.sql:420-443
