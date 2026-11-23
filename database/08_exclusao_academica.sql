-- Migração opcional para o banco existente. Execute como administrador.
-- Excluir matrícula apaga as notas da matrícula e seus registros de auditoria.
USE sga_fbi;

ALTER TABLE log_nota
  DROP FOREIGN KEY fk_log_matricula,
  ADD CONSTRAINT fk_log_matricula_cascade
    FOREIGN KEY (id_matricula) REFERENCES matricula(id_matricula) ON DELETE CASCADE;

DROP TRIGGER IF EXISTS trg_preserva_matricula;
