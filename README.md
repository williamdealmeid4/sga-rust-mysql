# SGA — Sistema de Gestão Acadêmica (Rust + MySQL)

Projeto de Laboratório de Banco de Dados da **Faculdade do Bug Infinito (FBI)**.
O sistema utiliza **Rust (Axum + SQLx)** no backend, **HTML/CSS/JS** no frontend e **MySQL 8** como banco de dados relacional (modelado em 3FN com Stored Procedures, Functions, Triggers, Views e controle transacional).

### Integrantes do Grupo
- **André Cavalcante Moreira**
- **William de Almeida**
- **Nícolas Silva Botelho Pereira**
- **Hitalo Guylherme Barbosa Pereira**

---

## Apresentação

- [Slides (PDF, 15 páginas)](apresentacao/SGA_Apresentacao_15_Paginas.pdf)
- [Consultas da demonstração](apresentacao/DEMO_CRUD_AO_VIVO.sql)
- Abra esta pasta no Zed para mostrar `src/main.rs`, `src/mysql_repo.rs` e os scripts de `database/`.

## Como Executar

1. Certifique-se de que o serviço **MySQL80** está ativo.
2. Execute `Iniciar SGA.cmd` (ou rode `cargo run --release`) e acesse **http://127.0.0.1:3030**.

### Contas de Demonstração

| Perfil | Login | Senha | Permissões |
| :--- | :--- | :--- | :--- |
| **Coordenador** | `coordenador` | `Fbi@2026` | Acesso completo: cursos, disciplinas, professores, turmas, alunos, matrículas, notas, fechamento de semestre, financeiro, auditoria e usuários. |
| **Secretário** | `secretario` | `Fbi@2026` | Gestão de alunos e matrículas, consulta de turmas e emissão de boletins/histórico escolar. |

---

## Instalação do Banco em Novo Ambiente

1. No **MySQL Workbench**, abra uma conexão administrativa (MySQL 8.0.16+) e execute `database/sga_fbi_completo.sql` uma única vez.
2. (Opcional, caso o banco já estivesse criado antes da extensão financeira) Execute `database/07_financeiro.sql` para criar as tabelas e procedures de cobrança.
3. Crie o usuário da aplicação no MySQL:

```sql
CREATE USER 'sga_rust_app'@'localhost' IDENTIFIED BY 'SUA_SENHA_AQUI' REQUIRE SSL;
GRANT 'sga_fbi_aplicacao' TO 'sga_rust_app'@'localhost';
SET DEFAULT ROLE 'sga_fbi_aplicacao' TO 'sga_rust_app'@'localhost';
```

4. Copie `.env.example` para `.env.local` e configure a `DATABASE_URL` com a mesma senha.

---

## Estrutura do Projeto

- `src/main.rs` — Servidor HTTP Axum, rotas REST, autenticação Argon2id e gerenciamento de sessão por cookie `HttpOnly`.
- `src/mysql_repo.rs` — Camada de acesso a dados via `sqlx`, chamadas parametrizadas (`CALL sp_*`) e mapeamento de erros do MySQL (`SIGNAL SQLSTATE '45000'`, chaves estrangeiras e unicidade).
- `src/domain.rs` — Validações de regras de negócio acadêmicas (RN01 a RN09), cálculo de médias/frequência e testes unitários.
- `web/` — Interface web responsiva com suporte a tema claro/escuro, exportação CSV e impressão de boletins/relatórios.
- `database/` — Scripts SQL modulados (`00_criar_banco.sql` a `07_financeiro.sql`), massa de dados inicial, suite de testes SQL e diagrama EER (`SGA-diagrama.mwb`).
- `APRESENTACAO.md` — Guia prático com os comandos em Rust (para mostrar no Zed) e consultas SQL (para demonstrar no MySQL Workbench).

---

## Compilação e Testes

```powershell
# Executar testes unitários de regras acadêmicas em Rust
cargo test

# Compilar binário otimizado
cargo build --release

# Executar verificações da interface
npm run test:frontend
```
