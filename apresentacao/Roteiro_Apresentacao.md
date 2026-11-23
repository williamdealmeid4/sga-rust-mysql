# Roteiro editável da apresentação SGA

Base: TrabalhoFinalLBD-2.pdf (5 páginas) e versão local do projeto em 26/10/2026.

Sugestão: 15-20 minutos de exposição e 5 minutos para a demonstração. Ajuste ao tempo da turma.

## Prioridade: comprovar o CRUD no MySQL

Toda inclusão, alteração ou exclusão confirmada pela aplicação deve ser conferida no banco. A grade do Workbench não se atualiza sozinha: execute o SELECT novamente. Se uma regra impedir a operação, explique a recusa e confira que o dado foi preservado.

## Slide 01 - Sistema de Gestão Acadêmica

Apresentem os integrantes. Digam que a demonstração principal será inserir, consultar, editar e excluir um cadastro, conferindo o mesmo registro no MySQL. Este é um modelo; substituam a proposta de divisão de tarefas pelos responsáveis reais.

Fonte: TrabalhoFinalLBD-2.pdf, p. 1 e 5

## Slide 02 - Requisitos do trabalho

Explique que o enunciado exige modelagem até a 3FN, massa mínima e objetos programados no MySQL. A aplicação atual envia CALL parametrizados. As consultas SQL diretas do roteiro são feitas manualmente na conexão administrativa do Workbench, para comprovar os dados.

**Banco e comunicação.** MySQL e Workbench. Comunicação da aplicação por stored procedures e views; sem INSERT, UPDATE ou DELETE direto pela interface.

**Regras e segurança.** Perfis Secretário/Coordenador, senha com hash, regras RN01-RN09 e auditoria automática.

**Entrega.** SQL, interface, relatório técnico e apresentação com divisão do trabalho e dificuldades.

Fonte: Fonte: TrabalhoFinalLBD-2.pdf, páginas 1-5

## Slide 03 - Modelo relacional e 3FN

Abra database/SGA-diagrama.mwb para mostrar o modelo EER. A tabela matrícula resolve a relação N:N entre alunos e turmas. Explique 1FN com valores atômicos; 2FN na chave composta de pré-requisito; 3FN separando dados do curso, aluno, disciplina e professor. O arquivo do diagrama não é uma grade de dados ao vivo.

**Relações principais.** Curso possui alunos e disciplinas; disciplina possui turmas; professor leciona turmas.

**Matrícula.** Relaciona aluno e turma. UNIQUE(id_aluno, id_turma) impede matrícula duplicada.

**Separação de responsabilidades.** Pré-requisito tem chave composta. Usuário, sessões e log de notas ficam em tabelas próprias.

Fonte: Código: database/01_estrutura.sql, linhas 16-105

## Slide 04 - Como a alteração chega ao banco

O MySQL é a fonte persistente. AcademicSnapshot é uma cópia temporária para validar regras, não um arquivo de armazenamento alternativo. Se o servidor informar erro, a operação não deve ser apresentada como concluída. Uma grade já aberta no Workbench não é atualizada automaticamente.

**1. Pedido.** O formulário envia POST, PUT ou DELETE para a API Rust.

**2. Gravação.** A API valida o usuário e chama uma procedure. O MySQL valida as regras e confirma a transação.

**3. Confirmação.** A aplicação consulta os dados novamente. No Workbench, execute outra vez o SELECT para ver a alteração.

Fonte: Código: src/main.rs:156-180; src/mysql_repo.rs:282-289; web/app.js:147-151

## Slide 05 - CRUD: criar e editar passam pela API

Explique o significado de kind e key. O mesmo padrão atende alunos, cursos, disciplinas, professores e demais cadastros. A sessão é validada antes da execução. Não diga que toda matrícula pode mudar de aluno ou turma: essa troca é bloqueada na implementação atual.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
162:     let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
163:     Repository::upsert(&mut conn, &user, &kind, None, body).await
...
171:     let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
172:     Repository::upsert(&mut conn, &user, &kind, Some(key), body).await
179:     let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
180:     Repository::delete(&mut conn, &user, &kind, key).await
```

**Linhas a destacar:** 163, 172, 180

Fonte: src/main.rs

## Slide 06 - A aplicação chama uma stored procedure

Os pontos de interrogação são parâmetros. Nome, CPF e demais campos não são concatenados para produzir SQL. Mostre também a conexão TLS em src/mysql_repo.rs:64-79. A senha da conexão fica em .env.local e não deve aparecer na apresentação.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
156:             "alunos" => {
157:                 sqlx::query("CALL sp_salvar_aluno(?,?,?,?,?,?,?,?,?)")
158:                     .bind(key)
159:                     .bind(text(&v, "ra"))
160:                     .bind(text(&v, "nome"))
161:                     .bind(text(&v, "cpf"))
162:                     .bind(text(&v, "email"))
163:                     .bind(text(&v, "nascimento"))
164:                     .bind(id(&v, "curso_id"))
165:                     .bind(text(&v, "status"))
166:                     .bind(actor)
167:                     .fetch_one(&mut **conn)
168:                     .await
```

**Linhas a destacar:** 156, 157, 159, 167, 168

Fonte: src/mysql_repo.rs

## Slide 07 - Inserção e edição na mesma procedure

Destaque que o handler faz ROLLBACK e propaga o erro. Restrições, autorização e validações vêm antes da gravação. O retorno do ID permite à API buscar o cadastro efetivamente persistido. Os números correspondem à versão local analisada; verifique o arquivo antes de ensaiar.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
287:  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
288:  START TRANSACTION;
289:  CALL sp_exigir_perfil(p_id_usuario,FALSE);
...
298:  IF p_id IS NULL THEN
299:   INSERT INTO aluno(ra,nome,cpf,email,data_nascimento,id_curso,status) VALUES(p_ra,p_nome,p_cpf,p_email,p_data_nascimento,p_id_curso,p_status); SET v_id=LAST_INSERT_ID();
300:  ELSE
302:   UPDATE aluno SET ra=p_ra,nome=p_nome,cpf=p_cpf,email=p_email,data_nascimento=p_data_nascimento,id_curso=p_id_curso,status=p_status WHERE id_aluno=p_id; SET v_id=p_id;
303:  END IF;
304:  COMMIT;
305:  SELECT v_id AS id_aluno;
```

**Linhas a destacar:** 287, 288, 299, 302, 304, 305

Fonte: database/02_programacao.sql

## Slide 08 - Exclusão também acontece no MySQL

Na apresentação, exclua um aluno de teste ainda sem matrícula ou cobrança. O MySQL recusa exclusões que violam chaves estrangeiras. Matrículas com notas ou auditoria são preservadas. A API usa CALL sp_excluir_cadastro(?,?,?) em src/mysql_repo.rs:324-329.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
424:  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
425:  START TRANSACTION;
426:  CALL sp_exigir_perfil(p_id_usuario,p_tipo NOT IN ('aluno','matricula'));
427:  CASE p_tipo
428:  WHEN 'aluno' THEN DELETE FROM aluno WHERE id_aluno=p_id;
429:  WHEN 'matricula' THEN DELETE FROM matricula WHERE id_matricula=p_id;
...
440:  SET v_rows=ROW_COUNT();
441:  IF v_rows=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registro inexistente.'; END IF;
442:  COMMIT;
```

**Linhas a destacar:** 424, 428, 441, 442

Fonte: database/02_programacao.sql

## Slide 09 - A tela recebe o registro gravado

Este é o trecho central para explicar a exigência de que alterações apareçam no banco. No frontend, web/app.js:151 fecha o formulário, aguarda refresh, atualiza o usuário e renderiza a tela. Uma falha de rede após COMMIT pode exigir nova consulta antes de repetir a operação.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
282:         let actual = row.try_get::<u32, _>(0).map_err(db_error)? as u64;
283:         let refreshed = Self::data(conn, actor).await?;
284:         let result = refreshed[kind]
285:             .as_array()
286:             .and_then(|list| list.iter().find(|r| id(r, "id") == actual))
287:             .cloned()
288:             .unwrap_or_else(|| json!({"id":actual}));
289:         Ok(Json(result))
```

**Linhas a destacar:** 283, 286, 289

Fonte: src/mysql_repo.rs

## Slide 10 - Demonstração principal: CRUD de aluno

Abra DEMO_CRUD_AO_VIVO.sql. Antes de começar, confira que o RA não está em uso. Use o formulário Alunos > Novo aluno para o CRUD completo. Para mostrar o novo fluxo Nova matrícula > Cadastrar novo aluno, use outro cadastro e explique que o primeiro botão salva o aluno e o segundo confirma a matrícula. Não reutilize o aluno já matriculado para a exclusão simples.

**Inserir.** Cadastre um aluno com RA APRES2026 e documentos exclusivos. A consulta deve retornar uma linha.

**Editar.** Altere o nome na interface. Execute o mesmo SELECT e confira o novo nome e o mesmo ID.

**Excluir.** Exclua o aluno sem vínculos. A consulta deve retornar zero linhas.

Fonte: Consulta preparada: DEMO_CRUD_AO_VIVO.sql

## Slide 11 - Matrícula: status, curso, vagas e requisitos

Explique também que há UNIQUE para aluno/turma. A procedure de matrícula e a trigger BEFORE INSERT aplicam as regras no banco. Edição do vínculo aluno/turma não é permitida: sem notas, o caminho é cancelar e criar outra matrícula. O Secretário pode matricular, mas não lançar notas.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
104:  IF v_status<>'Ativo' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN09: somente alunos Ativos podem realizar matrículas.'; END IF;
110:  SELECT COUNT(*) INTO v_count FROM matricula WHERE id_turma=p_turma;
111:  IF v_count>=v_vagas THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN05: turma lotada.'; END IF;
...
112:  IF EXISTS(SELECT 1 FROM pre_requisito pr WHERE pr.id_disciplina=v_disc AND NOT EXISTS(
113:    SELECT 1 FROM matricula m JOIN turma t ON t.id_turma=m.id_turma
114:    WHERE m.id_aluno=p_aluno AND t.id_disciplina=pr.id_disciplina_requisito AND t.semestre<v_semestre AND m.situacao='Aprovado'
115:  )) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RN06: falta aprovação em pré-requisito de semestre anterior.'; END IF;
```

**Linhas a destacar:** 104, 111, 115

Fonte: database/02_programacao.sql

## Slide 12 - Média e frequência são regras do banco

Para 80 aulas e 21 faltas, a frequência é 73,75%. Mesmo com média 9, o resultado é Reprovado por Falta. Valores fora de 0 a 10 são recusados por CHECK em database/01_estrutura.sql:81-83. A função fn_frequencia está em database/02_programacao.sql:27-33.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
10:  SET v_parcial=(p_n1+p_n2)/2;
11:  IF v_parcial>=4 AND v_parcial<7 AND p_exame IS NOT NULL THEN RETURN (v_parcial+p_exame)/2; END IF;
...
18:  IF p_aulas<=0 OR (p_aulas-p_faltas)*100 < 75*p_aulas THEN RETURN 'Reprovado por Falta'; END IF;
20:  SET v_parcial=(p_n1+p_n2)/2;
21:  IF v_parcial>=7 THEN RETURN 'Aprovado'; END IF;
22:  IF v_parcial<4 THEN RETURN 'Reprovado por Nota'; END IF;
23:  IF p_exame IS NULL THEN RETURN 'Em Exame'; END IF;
24:  IF fn_calcular_media(p_n1,p_n2,p_exame)>=5 THEN RETURN 'Aprovado'; END IF;
```

**Linhas a destacar:** 10, 11, 18, 24

Fonte: database/02_programacao.sql

## Slide 13 - Trigger de auditoria de notas

A comparação <=> trata NULL corretamente. Mostre um lançamento pela interface e depois SELECT em matricula e log_nota no Workbench. A trigger é AFTER UPDATE: não depende de um botão específico da tela para registrar a alteração. O lançamento é confirmado por transação.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
143: CREATE TRIGGER trg_auditoria_nota AFTER UPDATE ON matricula FOR EACH ROW
144: BEGIN
145:  DECLARE v_nome VARCHAR(150);
146:  SELECT nome INTO v_nome FROM usuario WHERE id_usuario=NEW.id_usuario;
147:  IF NOT(OLD.n1<=>NEW.n1) THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'n1',OLD.n1,NEW.n1,v_nome,NEW.id_usuario); END IF;
...
150:  IF OLD.faltas<>NEW.faltas THEN INSERT INTO log_nota(id_matricula,campo,valor_antigo,valor_novo,usuario,id_usuario) VALUES(NEW.id_matricula,'faltas',OLD.faltas,NEW.faltas,v_nome,NEW.id_usuario); END IF;
151: END$$
```

**Linhas a destacar:** 143, 147, 150

Fonte: database/02_programacao.sql

## Slide 14 - Views e relatórios

As três views estão em database/02_programacao.sql:456-477. A aplicação atual consulta seu conjunto de dados por sp_dados_sistema, que retorna JSON, e monta os relatórios a partir dele; não diga que cada tela executa diretamente uma view. As views protegidas exigem sessão: sem sessão, podem retornar zero linhas. Na conexão administrativa, use as tabelas-base para comprovar o CRUD.

**vw_boletim.** Aluno, RA, disciplina, semestre, notas, frequência e situação.

**vw_turmas_lotacao.** Vagas totais, matriculados, vagas restantes e ocupação.

**vw_desempenho_turma.** Média, maior/menor nota, aprovados e reprovados por turma.

Fonte: Código: database/02_programacao.sql:456-477; src/mysql_repo.rs:110-116

## Slide 15 - Autenticação e perfis

Explique que o hash não fica no navegador. A procedure recebe o hash verificado no backend, conforme sua assinatura; a senha digitada não é armazenada em texto puro. Coordenador tem acesso a notas, financeiro e fechamento; Secretário gerencia alunos e matrículas. As permissões são verificadas também no backend e no banco.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
94:             Argon2::default()
95:                 .verify_password(password.as_bytes(), &h)
96:                 .is_ok()
...
114:     let row = sqlx::query("CALL sp_LoginUsuario(?,?)")
115:         .bind(&login)
116:         .bind(proof)
117:         .fetch_one(&mut *conn)
118:         .await
119:         .map_err(db_error)?;
121:     let user = user_row(&row)?;
```

**Linhas a destacar:** 95, 114, 121

Fonte: src/main.rs

## Slide 16 - Fechamento com cursor e transação

Execute fechamento apenas no banco isolado de teste. Depois do fechamento, as turmas têm notas e matrículas bloqueadas. Não apresente uma validação de interface como substituta da transação no banco.

### Trecho original com numeração

As quebras de linha dos slides são apenas visuais; este bloco conserva as linhas originais.

```text
242:  DECLARE turmas CURSOR FOR SELECT id_turma FROM turma WHERE semestre=p_semestre AND encerrada=FALSE ORDER BY id_turma FOR UPDATE;
244:  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
245:  START TRANSACTION;
246:  CALL sp_exigir_perfil(p_id_usuario,TRUE);
247:  OPEN turmas;
249:   FETCH turmas INTO v_turma;
251:   IF EXISTS(SELECT 1 FROM matricula WHERE id_turma=v_turma AND situacao IN ('Cursando','Em Exame')) THEN
252:    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Há notas ou exames pendentes. Nenhuma turma foi encerrada.';
...
256:   UPDATE turma SET encerrada=TRUE,encerrada_por=p_id_usuario WHERE id_turma=v_turma;
259:  CLOSE turmas;
261:  COMMIT;
```

**Linhas a destacar:** 242, 244, 245, 246, 252, 261

Fonte: database/02_programacao.sql

## Slide 17 - Testes e evidências

Os testes citados foram executados nesta sessão em instância temporária na porta 3317. Consulte RESULTADOS_INTEGRACAO.txt e RESULTADOS_CRUD_ATUAL.txt. RESULTADOS_TESTES.txt e RESULTADOS_SEGURANCA.txt são relatórios já existentes, não uma nova execução de todos os testes SQL nesta apresentação. Não afirme cobertura total de todos os cenários.

**49 verificações de integração.** Login, permissões, gravação real, notas, auditoria, exclusões e fechamento testados contra MySQL isolado.

**CRUD adicional.** Cobrança pendente: inserir, consultar, editar e excluir. Matrícula: criação, consulta, cancelamento e bloqueio da troca de vínculo.

**Interface.** 24 verificações de interface/segurança e teste do cadastro de aluno dentro da matrícula.

Fonte: Evidências: database/RESULTADOS_INTEGRACAO.txt e RESULTADOS_CRUD_ATUAL.txt

## Slide 18 - Dificuldades e soluções do projeto

Complete esta fala com dificuldades vividas pelo próprio grupo. Não apresente como solucionado o erro 1064 do outro trabalho de combustíveis; ele não é um defeito demonstrado do SGA. Mencione também a decisão de calcular idade pelo nascimento, em vez de armazenar uma idade que ficará desatualizada.

**Compilação no Windows.** O linker MSVC não estava disponível. O executável foi recompilado com o toolchain GNU instalado.

**Banco existente e instalação.** O script completo cria um banco novo. No banco já instalado, usar conexão e consultas de conferência evita o erro 1007.

**Consistência do CRUD.** Transações, parâmetros, chaves estrangeiras e recarga após gravação mantêm as operações verificáveis.

Fonte: Base: execução local e código analisado em 26/10/2026

## Slide 19 - Divisão do trabalho do grupo

Esta é uma proposta de divisão, não um registro de autoria. Substituam pelos nomes e responsabilidades reais. Para grupos de três integrantes, redistribuam a última parte. Cada pessoa deve explicar um trecho de código e participar da demonstração.

**Integrante 1 / preencher nome.** Modelagem, 3FN, tabelas, chaves e restrições.

**Integrante 2 / preencher nome.** Procedures, funções, triggers e transações.

**Integrantes 3 e 4 / preencher nomes.** Interface/API, integração, testes e documentação. Ajustar à contribuição real de cada um.

Fonte: Modelo a preencher conforme a divisão real do grupo

## Slide 20 - O que comprovar ao apresentar

Finalize com a demonstração do CRUD. Reexecute o SELECT no Workbench depois de cada operação, porque a grade anterior pode mostrar uma consulta antiga. Não rode o instalador completo nem o fechamento no banco da demonstração. Tenha o roteiro SQL aberto e o arquivo de testes isolados como evidência.

**Operação confirmada na interface.** O registro correspondente deve estar persistido no MySQL após o COMMIT.

**Mesma chave, mesmo registro.** Conferir o mesmo ID ou RA após inserir e editar; conferir a ausência após excluir.

**Erro de regra também é um resultado.** Uma exclusão protegida ou matrícula inválida deve ser recusada, com o banco preservado.

Fonte: Roteiro: DEMO_CRUD_AO_VIVO.sql

## Antes de apresentar

- Preencher os nomes e a divisão real do grupo.
- Abrir a conexão administrativa no Workbench e selecionar sga_fbi.
- Abrir DEMO_CRUD_AO_VIVO.sql; não executar o instalador completo.
- Usar aluno de demonstração com documentos e RA exclusivos.
- Conferir o mesmo ID ou RA em cada etapa do CRUD.
- Demonstrar exclusão antes de criar vínculos com matrícula ou cobrança.
- Para mostrar matrícula e auditoria, usar outro cadastro e manter seu histórico.
- Não mostrar .env.local, senha do MySQL ou hashes reais nos slides.
- Atualizar números de linha se o código mudar depois deste material.

## Requisitos do PDF cobertos

| Tema | Slides |
|---|---|
| Tecnologias e comunicação por procedures/views | 2, 4, 6, 14 |
| Modelagem e 3FN | 3 |
| CRUD com persistência comprovável | 4-10, 20 |
| RN01-RN09 e matrícula | 11-13 |
| Views e relatórios | 14 |
| Autenticação e perfis | 15 |
| Cursores e transações | 16 |
| Testes e evidências | 17 |
| Dificuldades e soluções | 18 |
| Divisão do trabalho | 19 |
