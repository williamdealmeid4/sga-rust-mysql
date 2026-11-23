# Guia de Apresentação — Zed (Rust) + MySQL Workbench

**Integrantes do Grupo:**
- André Cavalcante Moreira
- William de Almeida
- Nícolas Silva Botelho Pereira
- Hitalo Guylherme Barbosa Pereira

Este roteiro reúne os pontos mais importantes do código em **Rust** (para mostrar no **Zed**) e as consultas em **SQL** (para demonstrar ao vivo no **MySQL Workbench**).

---

## 1. Principais Comandos em Rust para Mostrar no Zed

Abra a pasta do projeto no Zed (`C:\Users\Willi\Documents\SGA-Rust`) e deixe abertos os 3 arquivos de `src/`:

### A. `src/main.rs` — Rotas da API e Autenticação Argon2id
- **Autenticação (`fn login`, linhas 78–163):**
  - Mostra como o Rust busca o hash no banco com `sqlx::query("CALL sp_CredencialLogin(?)")`, libera a conexão do pool e verifica a senha usando `Argon2::default().verify_password(...)` dentro de `tokio::task::spawn_blocking`.
  - Se a senha estiver correta, chama `CALL sp_LoginUsuario(?, ?)` para gravar a sessão na tabela `sessao_usuario` e devolve o cookie `HttpOnly`.
- **Rotas REST (`fn main`, linhas 245–295):**
  - Mostra o `Router::new()` do Axum mapeando `/api/records/{kind}` (`POST` para criar) e `/api/records/{kind}/{id}` (`PUT` para editar, `DELETE` para excluir), além de `/api/grades/{id}` (notas) e `/api/close` (fechamento de semestre).

### B. `src/mysql_repo.rs` — Comunicação com o MySQL via Stored Procedures
- **Conexão segura com Pool (`Repository::connect`, linhas 74–88):**
  - Usa `MySqlConnectOptions::from_str(url)?.ssl_mode(MySqlSslMode::Required)` e `MySqlPoolOptions::new().max_connections(8)`.
- **Mapeamento de Erros do Banco (`fn db_error`, linhas 21–52):**
  - Traduz os códigos de erro do MySQL para respostas HTTP claras:
    - `1644`: erro disparado pelas triggers/procedures com `SIGNAL SQLSTATE '45000'` (ex.: turma lotada, falta de pré-requisito).
    - `1062`: violação de `UNIQUE` (CPF, RA ou e-mail duplicado).
    - `1451`: bloqueio de `FOREIGN KEY` ao tentar excluir registro que possui histórico/vínculos.
- **Execução parametrizada (`Repository::upsert` e `Repository::delete`, linhas 145–338):**
  - Mostra os comandos `sqlx::query("CALL sp_salvar_aluno(?,?,?,?,?,?,?,?,?)").bind(...)` e `sqlx::query("CALL sp_excluir_cadastro(?,?,?)")`.
  - Destaque que **não há concatenação de strings SQL** (prevenção total contra SQL Injection) e que logo após gravar no MySQL o Rust chama `Self::data(conn, actor)` para ler o estado real persistido no banco.

### C. `src/domain.rs` — Cálculo Acadêmico e Regras de Negócio
- **Cálculo de Média, Exame e Frequência (`fn result_grade`, linhas 51–85):**
  - Implementa as regras acadêmicas: frequência mínima de 75%, média parcial `(N1 + N2) / 2`, aprovação direta (`>= 7.0`), exame (`4.0 <= parcial < 7.0` com média final `(parcial + exame) / 2 >= 5.0`).
- **Prevenção de Ciclos em Pré-requisitos (`fn reaches`, linhas 195–210):**
  - Busca em profundidade (DFS) garantindo que uma disciplina não crie dependência circular.

---

## 2. Demonstração ao Vivo: Sistema Web <-> MySQL Workbench

> **Importante no MySQL Workbench:**
> - Use a conexão administrativa (**Local instance MySQL80**).
> - Se ainda não tiver executado o módulo financeiro no banco principal, abra e execute `database/07_financeiro.sql` uma vez no Workbench.
> - No navegador, cada registro exibe seu **`#ID`** (ex.: `#21`), que corresponde exatamente à chave primária (`id_aluno`, `id_curso`, `id_matricula`) no MySQL.
> - Se você alterar algo direto pelo Workbench, clique no botão **Atualizar** no topo do sistema web para recarregar os dados do MySQL imediatamente.

### Passo a Passo do CRUD ao Vivo (Consultas para o Workbench)

Deixe uma aba SQL aberta no MySQL Workbench com os comandos abaixo:

```sql
USE sga_fbi;

-- 1. Conferir alunos (execute antes e depois de criar/editar/excluir um aluno na interface web)
SELECT id_aluno, ra, nome, cpf, email, data_nascimento, id_curso, status
FROM aluno
ORDER BY id_aluno DESC;

-- 2. Conferir matrículas e notas (execute após matricular ou lançar notas na interface web)
SELECT id_matricula, id_aluno, id_turma, data_matricula, n1, n2, exame, faltas, media_final, situacao
FROM matricula
ORDER BY id_matricula DESC;

-- 3. Conferir auditoria automática gerada pela trigger trg_auditoria_nota após alterar notas
SELECT id_log, id_matricula, campo, valor_antigo, valor_novo, usuario, data_hora
FROM log_nota
ORDER BY id_log DESC
LIMIT 20;

-- 4. Conferir cobranças e log financeiro (após executar 07_financeiro.sql)
SELECT id_cobranca, id_aluno, id_curso, descricao, valor, vencimento, status, data_pagamento
FROM cobranca
ORDER BY id_cobranca DESC;

-- 5. Listar objetos programados no banco (Procedures, Functions, Triggers e Views)
SHOW PROCEDURE STATUS WHERE Db = 'sga_fbi';
SHOW FUNCTION STATUS WHERE Db = 'sga_fbi';
SHOW TRIGGERS FROM sga_fbi;
SHOW FULL TABLES FROM sga_fbi WHERE Table_type = 'VIEW';
```
