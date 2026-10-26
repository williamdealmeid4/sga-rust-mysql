# Revisão de segurança — interface SGA

Revisão limitada ao frontend e aos cabeçalhos HTTP sobre o commit
`feb3991a8dbee123a64116d044fa4e040c0214ad`. Foram aplicadas melhorias de defesa
no navegador e de limpeza de dados após expiração da sessão. Nenhum arquivo em
`database/`, procedure, tabela, dado, consulta ou permissão MySQL foi alterado;
os testes desta atualização não conectam ao banco.

A skill de segurança fornece orientação para JavaScript, mas não para Rust/Axum.
A revisão Rust foi limitada aos cabeçalhos e ao fornecimento dos novos arquivos;
não representa uma auditoria completa do backend ou da autenticação.

## Severidade média

### 1. Dados permaneciam em memória e em modal após sessão expirada — corrigido

- Local original: `web/app.js:19`, função `api`.
- Evidência original: no HTTP 401, `state.user=null;renderLogin()` não limpava
  `state.data` nem fechava o diálogo externo a `#app`.
- Impacto: dados acadêmicos já carregados podiam continuar visíveis no modal
  após a aplicação reconhecer que a sessão expirou.
- Correção: `web/app.js:15`, função `clearSession`, limpa o snapshot, fecha e
  esvazia o diálogo e remove o aviso anterior. A mesma rotina é usada ao sair.
- Verificação: teste offline de HTTP 401 com diálogo aberto e dados carregados.
  Isso limpa a interface; não substitui a autorização existente no servidor.

## Severidade baixa / reforço preventivo

### 2. CSP permitia estilos inline — corrigido

- Local: `src/main.rs:56`, função `security_headers`.
- Evidência original: `style-src 'self' 'unsafe-inline'`; havia atributos
  `style` em `brand`, `capacity` e `reports` no frontend.
- Impacto: enfraquecia a defesa contra estilos HTML injetados; não foi demonstrada
  uma exploração independente de XSS nessa configuração.
- Correção: classes CSS e elemento `progress` substituem estilos inline;
  CSP permite CSS local e bloqueia atributos de estilo, objetos e alteração da
  base de URLs. Vídeo e conexões ficam restritos à própria origem.
- Verificação: teste de ausência de atributos `style` no painel e navegador real
  com a política extraída do código Rust, sem violações CSP na tela de entrada.
- Referência: [MDN — style-src-attr](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/style-src-attr).

### 3. Outras defesas preservadas e reforçadas

- `src/main.rs:57`: câmera, microfone e geolocalização desabilitados via
  `Permissions-Policy`; a aplicação não utiliza esses recursos.
- `web/app.js`, função `exportCsv`: proteção existente contra fórmulas inclui
  caracteres de controle antes de `=`, `+`, `-` e `@`. A interpretação de CSV
  varia entre planilhas; esse controle não é garantia universal.
- `web/theme.js:3`: somente preferência de aparência validada (`light`/`dark`)
  em armazenamento local, com tratamento de armazenamento indisponível.
- Escape de texto preexistente mantido; teste com nome de aluno contendo
  `<img ... onerror=...>` confirma exibição textual, sem elemento executável.

## Validação e limites

- `npm run test:frontend`: 24 verificações offline de tema, abertura, expiração
  e renderização segura. Os dados da API são simulados, sem gravações.
- FFprobe: vídeo H.264 de 3,000 segundos, sem áudio, com 17.725 bytes.
- Entrada inspecionada em Chromium em desktop e em viewport de 390 × 844.
- O HTTP 401 de `/api/me` na prévia é intencional: não há sessão ou backend real.
- `npm ci --ignore-scripts`: auditoria npm informou zero vulnerabilidades.
- `cargo test` e compilação Rust não executados: Cargo não está instalado neste
  ambiente. Integração com MySQL e executável Windows não foram validados.
- Contas demonstrativas e aplicação local permanecem conforme o projeto original.
