# Graph Report - SGA-Rust  (2026-10-19)

## Corpus Check
- 5 files · ~6,113 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 188 nodes · 528 edges · 12 communities (10 shown, 2 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.85)
- Token cost: unavailable (delegation tool did not expose usage)

## Community Hubs (Navigation)
- AcademicSnapshot / Value
- ApiError / Repository
- main.rs / login
- Requisitos acadêmicos
- app.js / renderShell
- rows / find
- reports / tableSpec
- dashboard / toolbar
- Requisitos acadêmicos
- closeSemester / fieldHtml
- Requisitos acadêmicos
- Requisitos acadêmicos

## God Nodes (most connected - your core abstractions)
1. `AcademicSnapshot` - 23 edges
2. `reports()` - 20 edges
3. `rows()` - 19 edges
4. `ApiError` - 18 edges
5. `text()` - 16 edges
6. `find()` - 14 edges
7. `tableSpec()` - 14 edges
8. `esc()` - 13 edges
9. `dashboard()` - 13 edges
10. `Repository` - 12 edges

## Surprising Connections (you probably didn't know these)
- `close()` --calls--> `text()`  [INFERRED]
  src/main.rs → src/domain.rs
- `login()` --calls--> `text()`  [INFERRED]
  src/main.rs → src/domain.rs
- `login()` --calls--> `user_row()`  [INFERRED]
  src/main.rs → src/mysql_repo.rs
- `App` --references--> `Repository`  [EXTRACTED]
  src/main.rs → src/mysql_repo.rs
- `db_error()` --calls / references--> `ApiError`  [EXTRACTED]
  src/mysql_repo.rs → src/main.rs

## Import Cycles
- None detected.

## Communities (12 total, 2 thin omitted)

### Community 0 - "AcademicSnapshot / Value"
Cohesion: 0.17
Nodes (19): BTreeMap, AcademicSnapshot, enrollment_constraints(), examination_and_closure(), grade_boundaries(), grades_audit_and_permissions(), id(), KINDS (+11 more)

### Community 1 - "ApiError / Repository"
Cohesion: 0.17
Nodes (20): From, IntoResponse, MySql, MySqlPool, MySqlRow, PoolConnection, ApiError, Self (+12 more)

### Community 2 - "main.rs / login"
Cohesion: 0.21
Nodes (28): HashMap, HeaderMap, Instant, Json, Mutex, Path, Response, Shared (+20 more)

### Community 3 - "Requisitos acadêmicos"
Cohesion: 0.08
Nodes (25): Aluno e situação acadêmica, Boletim acadêmico, Cadastro, edição e exclusão de alunos, Curso, carga horária e turno, Disciplina e período, Frequência = (aulas - faltas) / aulas × 100, Histórico completo por semestre, Auditoria de notas (+17 more)

### Community 4 - "app.js / renderShell"
Cohesion: 0.18
Nodes (16): api(), brand(), headActions(), initials(), navigate(), navItems, paths, refresh() (+8 more)

### Community 5 - "rows / find"
Cohesion: 0.29
Nodes (16): classes(), confirmDelete(), editGrades(), editRecord(), enrollments(), exportCsv(), financialSummary(), find() (+8 more)

### Community 6 - "reports / tableSpec"
Cohesion: 0.36
Nodes (11): actionButtons(), capacity(), date(), esc(), fmt(), money(), person(), previewGrades() (+3 more)

### Community 7 - "dashboard / toolbar"
Cohesion: 0.46
Nodes (8): btn(), dashboard(), icon(), isCoord(), metric(), renderBody(), renderTable(), toolbar()

### Community 8 - "Requisitos acadêmicos"
Cohesion: 0.29
Nodes (7): Perfil Coordenador, Desempenho por turma, Encerramento exclusivo do Coordenador, Exame somente na situação Em Exame, Faturamento por curso, Lançamento e alteração de notas e faltas, RN07: notas entre 0 e 10

### Community 9 - "closeSemester / fieldHtml"
Cohesion: 0.50
Nodes (4): closeSemester(), fieldHtml(), option(), semesters()

## Knowledge Gaps
- **17 isolated node(s):** `KINDS`, `paths`, `state`, `navItems`, `titles` (+12 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 43 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `text()` connect `AcademicSnapshot / Value` to `ApiError / Repository`, `main.rs / login`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `ApiError` connect `ApiError / Repository` to `main.rs / login`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `login()` connect `main.rs / login` to `AcademicSnapshot / Value`, `ApiError / Repository`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **What connects `KINDS`, `paths`, `state` to the rest of the system?**
  _17 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Requisitos acadêmicos` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._

## Escopo e integridade

Extração semântica: somente requisitos do sistema no PDF. Extração estrutural: src/ e web/. Sem MySQL. A visão simples agrega relações paralelas em provenance e registra recursão nos atributos dos nós. 18 relações com símbolos externos/não resolvidos foram excluídas da visualização; 2 recursões foram mantidas nos atributos. A extração bruta completa está em extraction_raw.json. O diagnóstico do grafo exibido não contém endpoints ausentes, autorrelações ou colapsos sem proveniência.

A ferramenta de delegação não informou o uso de tokens; zeros internos são marcadores indisponíveis e não representam custo zero.
