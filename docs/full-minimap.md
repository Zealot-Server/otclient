# Minimapa completo do Zealot

O cliente carrega o minimapa pessoal e depois o mapa completo distribuído em
`data/minimap.otmm`. Somente os tiles marcados como descobertos em cada arquivo
são mesclados. Assim, um cache pessoal incompleto não apaga áreas do mapa
completo. O mapa recebido do servidor continua atualizando os tiles durante o
jogo.

## Gerar o arquivo para cada versão do mapa

1. Abra no Remere's o mapa usado pelo Canary:
   `canary/data-otservbr-global/world/otservbr.otbm`.
2. No menu **File > Export > Export Minimap...**, selecione o formato
   **.otmm (Client Minimap)** e **All Floors**.
3. Escolha `otclient/data` como pasta de saída e `minimap` como nome. O resultado
   deve ser `otclient/data/minimap.otmm`.
4. Confirme que o arquivo foi gerado a partir do mesmo OTBM que será publicado no
   servidor. Para esta versão, o SHA-256 do OTBM é
   `776008b414d68019456a94d9ab5ea118f044c0f34a6f699023e5bc2b434e574f`.
   Revise especialmente as áreas personalizadas e os acessos a elas.
5. Inclua o OTMM no mesmo release do cliente que disponibiliza o mapa. Os pacotes
   de macOS, Windows e Linux já copiam o diretório `data` para a distribuição.

Ao modificar o OTBM depois deste release, exporte o OTMM novamente. O arquivo
mostra a geometria estática do mapa e ajuda a caminhada automática; ele não
substitui as atualizações do mapa enviadas pelo servidor durante a partida.
