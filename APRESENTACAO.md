# Roteiro de apresentação

1. Abra o projeto inteiro no Zed: `C:\Users\Willi\Documents\SGA-Rust`.
2. No Workbench abra a conexão **Local instance MySQL80**. Atualize **Schemas** e expanda **sga_fbi > Tables**. Para abrir uma tabela: botão direito > **Select Rows - Limit 1000**.
3. Abra também `database/SGA-diagrama.mwb` no Workbench. O diagrama fica na aba do modelo; as tabelas e os dados reais ficam na aba da conexão. O modelo é uma representação da estrutura, não uma tela de dados ao vivo.
4. Abra `Iniciar SGA.cmd` e entre como `coordenador`, senha `Fbi@2026`.
5. Cadastre um aluno de demonstração com RA/CPF/e-mail exclusivos. Consulte `SELECT * FROM sga_fbi.aluno ORDER BY id_aluno DESC;` no Workbench. Altere o nome no sistema e execute novamente a consulta; exclua o aluno ainda sem vínculos e confira a remoção.
6. Mostre turmas, vagas, matrículas, notas, exame e frequência. Notas entre 0 e 10; frequência abaixo de 75% reprova. Média parcial >=7 aprova, >=4 e <7 permite exame, abaixo de 4 reprova. No exame, média final >=5 aprova.
7. Mostre auditoria e histórico. A trigger registra as mudanças das notas no banco. Registros com histórico não podem ser excluídos livremente.
8. Mostre cobranças e relatório financeiro após instalar `07_financeiro.sql`. Crie uma cobrança, altere para Pago com a data, confira o relatório. Cobranças pagas/canceladas são preservadas; pendentes podem ser excluídas com auditoria.
9. Entre como `secretario`: demonstre que notas, usuários, fechamento e financeiro não ficam disponíveis. O backend e o MySQL também recusam acessos indevidos.
10. Fechamento de semestre é uma operação definitiva para as turmas do semestre; demonstre em uma cópia de teste. Se houver pendências, a transação inteira é revertida.

## Explicar o fluxo

Formulário → fetch HTTP → rota Axum → autorização/validação Rust → SQLx com parâmetros → stored procedure → regras/FKs/triggers → COMMIT → leitura atualizada do MySQL → tela.

O MySQL é a fonte dos dados. O objeto AcademicSnapshot é temporário e serve à validação, não substitui o banco. O banco também valida as regras para impedir inconsistências entre requisições simultâneas.

## Mostrar SQL

```sql
USE sga_fbi;
SHOW TABLES;
SHOW PROCEDURE STATUS WHERE Db='sga_fbi';
SHOW TRIGGERS;
SELECT * FROM aluno ORDER BY id_aluno DESC;
SELECT * FROM matricula ORDER BY id_matricula;
SELECT * FROM log_nota ORDER BY id_log DESC LIMIT 20;
SELECT * FROM cobranca ORDER BY id_cobranca DESC;
SELECT * FROM log_financeiro ORDER BY id_log DESC LIMIT 20;
```

Use a conexão administrativa pessoal no Workbench. As views protegidas exigem sessão da aplicação; consultar uma view sem sessão pode retornar zero linhas deliberadamente.

## Relações principais

Curso possui disciplinas e alunos; disciplina pode ter pré-requisitos e turmas; professor leciona turmas; matrícula liga aluno e turma; log_nota registra alterações da matrícula; usuário identifica o responsável e possui sessões. Cobrança liga aluno, curso e usuário; log_financeiro preserva o histórico inclusive de cobranças pendentes excluídas.

O sal do Argon2id é único e está codificado dentro do próprio hash. Os segredos de conexão ficam em `.env.local`, nunca no JavaScript. SQLx exige TLS para conectar ao MySQL.
