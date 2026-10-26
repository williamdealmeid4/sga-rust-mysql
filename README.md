# SGA — Rust + MySQL

Sistema acadêmico local da Faculdade do Bug Infinito. Backend Rust (Axum/SQLx), interface HTML/CSS/JavaScript e persistência real no MySQL 8. O servidor escuta somente em `127.0.0.1:3030`.

## Executar neste computador

Abra `Iniciar SGA.cmd`, depois http://127.0.0.1:3030. O MySQL80 precisa estar iniciado. A configuração particular está em `.env.local` e não é publicada.

Contas demonstrativas: `coordenador` e `secretario`. Senha de demonstração: `Fbi@2026`. Existem também coordenador2, secretario2 e secretario3. Troque as senhas antes de usar dados reais.

## Instalação em outro computador

1. Instale o MySQL 8.0.16 ou superior e abra uma conexão administrativa no Workbench.
2. Execute `database/sga_fbi_completo.sql` uma única vez em uma instalação nova. O script cria `sga_fbi`; não apaga bancos existentes. Se o banco já existe, não repita a instalação completa.
3. Crie a conta técnica com uma senha exclusiva usando o modelo abaixo, substituindo o marcador antes de executar.
4. Copie `.env.example` para `.env.local` e preencha a mesma senha. Caracteres especiais da senha precisam de codificação de URL.
5. Use o executável do ZIP/release em `bin/sga-fbi.exe`, ou compile o código e copie o executável para essa pasta.

```sql
CREATE USER 'sga_rust_app'@'localhost' IDENTIFIED BY 'SUBSTITUA_POR_SENHA_FORTE' REQUIRE SSL;
GRANT 'sga_fbi_aplicacao' TO 'sga_rust_app'@'localhost';
SET DEFAULT ROLE 'sga_fbi_aplicacao' TO 'sga_rust_app'@'localhost';
```

A conexão exige TLS e um endereço local. A conta da aplicação recebe permissão para executar procedimentos específicos e consultar views protegidas; não recebe acesso direto às tabelas.

## Sistema, banco e código para apresentação

- `src/main.rs`: servidor HTTP, autenticação Argon2id, cookies e rotas.
- `src/mysql_repo.rs`: comunicação MySQL com parâmetros vinculados e chamadas de stored procedures.
- `src/domain.rs`: validações e cálculo acadêmico; o snapshot é carregado do MySQL, sem persistência JSON.
- `web/`: interface, formulários, relatórios, CSV e impressão.
- `database/`: estrutura, funções, procedures, triggers, permissões, dados demonstrativos e testes.
- `database/SGA-diagrama.mwb`: modelo EER para abrir no MySQL Workbench.
- `APRESENTACAO.md`: roteiro para demonstrar e explicar o projeto.
- `graphify-out/graph.html`: grafo do código e dos requisitos produzido com Graphify.

Cadastrar, alterar, excluir, lançar notas e fechar semestre passam pela API Rust e por procedures no MySQL. A resposta só confirma sucesso depois da operação no banco. Restrições de exclusão preservam históricos vinculados; nesses casos a interface mostra o motivo da recusa.

O coordenador gerencia cadastros, notas, fechamento e cobranças; o secretário gerencia alunos/matrículas e consulta os relatórios permitidos. O financeiro usa valores informados pelo coordenador, sem mensalidades inventadas. A extensão `07_financeiro.sql` atualiza instalações anteriores, preservando os dados acadêmicos; execute uma única vez se ainda não houver a tabela `cobranca`.

## Compilar e verificar

```powershell
cargo build --release
cargo test
```

No Windows, configure o linker correspondente ao toolchain. O binário entregue foi compilado com o toolchain GNU. `package.json` é usado apenas nos testes de interface, não é necessário para executar o sistema.

Os relatórios `database/RESULTADOS_*.txt` registram a validação já executada. Testes destrutivos usam uma instância MySQL isolada na porta 3317 e verificam seu diretório antes de operar. Não aponte esses testes ao banco da apresentação. Os testes de interface com jsdom verificam comportamento e não substituem inspeção visual em navegador.

## Segurança e limites

Senhas usam Argon2id; o navegador não recebe hashes. Sessões expiram e o banco guarda apenas o hash do token. Há autorização no backend e nas procedures, SQL parametrizado, limite de tentativas de login e cookie HttpOnly/SameSite. A configuração e os dados locais não entram no GitHub nem no ZIP público. O sistema foi feito para uso local; a conta demonstrativa e esta configuração não devem ser expostas à internet.

Consulte `STATUS_ENTREGA.md` para saber os testes executados e as verificações finais ainda pendentes.

## Abertura e aparência

A primeira visita em cada aba apresenta um vídeo local, silencioso, de 3 segundos
com a marca da faculdade. É possível usar **Pular abertura** ou Escape quando a
abertura está em foco. Com a preferência de movimento reduzido, a entrada é direta.
Se o vídeo falhar, o sistema libera a interface automaticamente.

O botão de tema aparece na entrada e no cabeçalho do painel. A aparência acompanha
o sistema operacional até uma escolha manual, que fica salva no navegador. Nenhum
dado acadêmico ou credencial é salvo para esse recurso. Os relatórios continuam
com fundo branco na impressão.

O vídeo está em `web/intro.mp4` e é incluído no executável Rust, sem serviços
externos. Para regenerá-lo, use `python scripts/create_intro.py` com Pillow e FFmpeg
instalados; essas ferramentas não são necessárias para executar o SGA.

Para verificar somente a interface, sem conectar ao banco:

```sh
npm ci
npm run test:frontend
```

As alterações de frontend e cabeçalhos exigem recompilar o executável com
`cargo build --release`. Nenhum script SQL precisa ser executado para esta atualização.
Consulte `security_best_practices_report.md` para o escopo da revisão de segurança.
