-- Informe o ID do aluno mostrado no SGA.
-- Rode antes e depois de clicar em Excluir na tela de alunos.
USE sga_fbi;
SET @id_aluno_demo = 1;

SELECT id_aluno, ra, nome
FROM aluno
WHERE id_aluno = @id_aluno_demo;

SELECT COUNT(*) AS matriculas_do_aluno
FROM matricula
WHERE id_aluno = @id_aluno_demo;
