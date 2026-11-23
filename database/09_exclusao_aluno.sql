-- Execute como administrador após 08_exclusao_academica.sql.
-- Ao excluir um aluno, o MySQL também exclui matrículas, notas e auditoria delas.
-- Alunos com cobranças continuam sujeitos à restrição financeira.
USE sga_fbi;

ALTER TABLE matricula
  DROP FOREIGN KEY fk_matricula_aluno,
  ADD CONSTRAINT fk_matricula_aluno_cascade
    FOREIGN KEY (id_aluno) REFERENCES aluno(id_aluno) ON DELETE CASCADE;
