-- DEMONSTRAÇÃO DO CRUD NO WORKBENCH - BANCO EXISTENTE
-- Execute as consultas selecionadas após cada ação na interface.
-- Estas instruções apenas consultam os dados e definem variáveis desta sessão.
-- Use sua conexão administrativa. Não execute o instalador completo.
USE sga_fbi;
SET @ra_demo = 'APRES2026'; -- Altere se este RA já estiver em uso.

-- 1. ANTES DE INSERIR: esperado 0 linhas.
-- Na interface: Alunos > Novo aluno. Informe este RA e documentos exclusivos.
SELECT id_aluno,ra,nome,cpf,email,data_nascimento,
       TIMESTAMPDIFF(YEAR,data_nascimento,CURDATE()) AS idade,
       id_curso,status
FROM aluno WHERE ra=@ra_demo;

-- 2. APÓS INSERIR NA INTERFACE: esperado 1 linha.
SELECT id_aluno,ra,nome,email,status FROM aluno WHERE ra=@ra_demo;

-- 3. EDITE O NOME NA INTERFACE E EXECUTE NOVAMENTE:
-- Esperado: mesmo ID e nome novo.
SELECT id_aluno,ra,nome,email,status FROM aluno WHERE ra=@ra_demo;

-- 4. EXCLUA NA INTERFACE O ALUNO AINDA SEM VÍNCULOS:
-- Esperado: 0 linhas e quantidade=0.
SELECT id_aluno,ra,nome FROM aluno WHERE ra=@ra_demo;
SELECT COUNT(*) AS quantidade FROM aluno WHERE ra=@ra_demo;

-- 5. MATRÍCULA: use outro aluno para manter este histórico.
-- Cadastre pela interface e informe o ID retornado na grade de alunos.
SET @id_aluno_demo = 0; -- Substitua pelo ID real do aluno de demonstração.
SELECT id_matricula,id_aluno,id_turma,data_matricula,n1,n2,exame,
       faltas,media_final,situacao
FROM matricula WHERE id_aluno=@id_aluno_demo ORDER BY id_matricula DESC;

-- 6. AUDITORIA: após alterar notas na interface, execute esta consulta.
SELECT l.id_log,l.id_matricula,l.campo,l.valor_antigo,l.valor_novo,
       l.usuario,l.data_hora
FROM log_nota l JOIN matricula m ON m.id_matricula=l.id_matricula
WHERE m.id_aluno=@id_aluno_demo ORDER BY l.id_log DESC;

-- 7. OBJETOS: metadados visíveis conforme as permissões da sua conexão.
SHOW PROCEDURE STATUS WHERE Db='sga_fbi';
SHOW TRIGGERS FROM sga_fbi;
SHOW FULL TABLES FROM sga_fbi WHERE Table_type='VIEW';

-- ATENÇÃO: executar o SELECT novamente atualiza o resultado no Workbench.
-- Uma exclusão recusada por vínculo acadêmico preserva os registros.
-- As views protegidas podem retornar vazio sem sessão da aplicação.
