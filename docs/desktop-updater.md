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

1. Concluir e testar os quatro pacotes desktop no CI, incluindo o smoke do
   script Windows e os testes de login dos pacotes.
2. Publicar o release GitHub com os quatro arquivos.
3. Calcular e conferir os SHA-256 dos arquivos publicados.
4. Atualizar `myaac-main/system/client-release.php` com a versão, URLs e hashes.
5. Verificar que `client-update.php` devolve os mesmos dados da página de
   download. Só então considerar elevar `MIN_CLIENT_APP_VERSION` no login-server.

O cliente 1.0.3 não contém este atualizador e precisa ser reinstalado
manualmente. A partir do primeiro pacote que inclui `client_update`, o botão
de atualização automática ficará disponível para releases posteriores.
