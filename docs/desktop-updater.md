# Atualização do cliente desktop Zealot

O cliente consulta `https://www.zealot.website/client-update.php` ao abrir. O
endpoint lê `myaac-main/system/client-release.php`, que também controla os links
de download. Quando a versão publicada é maior que a instalada, o jogador vê
dois botões: baixar pelo site ou atualizar automaticamente.

A atualização automática baixa o pacote completo da arquitetura instalada,
verifica o SHA-256 publicado e grava o arquivo na pasta de dados do usuário.
Um script externo aguarda o fechamento do jogo, verifica o hash novamente,
extrai o pacote em uma pasta temporária ao lado da instalação, conserva a
instalação anterior com o sufixo `.previous.<timestamp>`, coloca a nova no
lugar e abre o cliente. Se a preparação falhar, a instalação antiga continua
intacta. Falhas após o fechamento do jogo ficam em `updates/install.log` na
pasta de dados do usuário. A atualização exige permissão de escrita na pasta
onde o cliente foi instalado.

O instalador não altera `data/things/<version>` nem `data/sounds/<version>`
fora do novo pacote. Os assets baixados em tempo de execução continuam nos
caminhos padrão e com a verificação SHA-256 estrita. A pasta de dados do usuário
preserva configurações e assets já instalados.

## Publicação

1. Concluir e testar os quatro pacotes desktop no CI, incluindo os testes de
   login e `Updater E2E` para Linux, Windows, macOS Apple Silicon e macOS Intel.
   Esse teste instala o pacote público 1.0.4 em um runner descartável. Um módulo
   temporário responde à consulta de versão, aciona o botão de atualização e
   entrega o pacote novo por um servidor HTTP local. O cliente real baixa,
   verifica o SHA-256, executa o instalador e abre a versão nova. Antes disso,
   um checksum errado deve deixar a instalação antiga intacta. Depois da troca,
   o pacote anterior deve continuar no backup. No Windows, o teste inicia o
   cliente 1.0.4 com o diretório de trabalho fora da instalação: o instalador
   dessa versão mantém a pasta aberta quando o cliente é iniciado de dentro
   dela. O teste separado `Windows update helper smoke` reproduz esse cenário
   com o instalador corrigido que acompanha o novo pacote.
2. Publicar o release GitHub com os quatro arquivos.
3. O workflow do site sincroniza automaticamente os links e hashes após conferir
   os pacotes e o CI do mesmo commit. Verificar que `client-update.php` devolve
   os mesmos dados da página de download. Só então considerar elevar
   `MIN_CLIENT_APP_VERSION` no login-server.

O `Updater E2E` cobre o prompt, o botão, o download, o instalador externo, a
troca, o reinício e a conservação da versão anterior com pacotes reais. A
resposta de versão e o servidor de arquivos são locais ao runner, porque o
pacote candidato ainda não foi publicado. Os testes de login do release e a
sincronização do site cobrem as outras partes do fluxo; um teste posterior à
publicação poderá conferir a rota pública de ponta a ponta.

Para repetir apenas os quatro testes de atualização após corrigir o teste,
execute `CI` com `updater_retest_only = true`, `updater_source_run_id` igual ao
ID da execução que gerou os pacotes e `updater_source_sha` igual ao SHA usado
nos nomes dos quatro artefatos. O reteste reutiliza os mesmos pacotes sem
recompilar os clientes.

O cliente 1.0.3 não contém este atualizador e precisa ser reinstalado
manualmente. A partir do primeiro pacote que inclui `client_update`, o botão
de atualização automática ficará disponível para releases posteriores.
No Windows 1.0.4, a atualização automática pode falhar se o cliente foi aberto
com a pasta de instalação como diretório de trabalho. Nesse caso, o jogador
deve usar o botão de download e instalar o novo pacote manualmente uma vez.
