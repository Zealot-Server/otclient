# Distribuição inicial para macOS

Este documento define o primeiro modo de distribuição pública do Zealot Client.

## Escopo inicial

- Aplicativo: `Zealot Client`.
- Bundle ID: `website.zealot.client`.
- Versão inicial: `1.0.0`.
- Arquiteturas publicadas: Apple Silicon (`arm64`) e Intel (`x86_64`).
- Versão mínima do macOS: 11.0.
- Formato publicado: arquivo ZIP contendo `Zealot Client.app`.
- Canal de download: página oficial `https://www.zealot.website/download`.
- Sistema mínimo: macOS 11.0.

O ZIP inicial não será assinado nem notarizado, pois a inscrição no Apple Developer Program foi adiada. Por isso, o macOS poderá impedir a primeira abertura. A página de download deve explicar o procedimento de autorização pelo usuário em **Ajustes do Sistema > Privacidade e Segurança**.

## Conteúdo do pacote

São publicados dois arquivos, compilados nativamente e sem emulação:

- `zealot-client-1.0.0-macos-arm64.zip` para Macs com Apple Silicon (M1, M2, M3 e M4);
- `zealot-client-1.0.0-macos-x86_64.zip` para Macs Intel.

Cada ZIP contém apenas o bundle gerado pelo build de release:

```text
Zealot Client.app
```

Não incluir diretórios de build, caches, código-fonte, chaves, arquivos `.env` ou dados pessoais.

## Atualizações

Enquanto o pacote não for assinado/notarizado, atualizações serão distribuídas como um novo ZIP versionado. O cliente deve avisar quando houver uma versão mais recente e direcionar o jogador para a página oficial de download; ele não deve alterar o conteúdo do próprio bundle em execução.

Após a adesão ao Apple Developer Program, este fluxo será substituído por DMG assinado e notarizado, com atualização automática assinada.

## Checklist de publicação

1. Builds macOS de release `arm64` e `x86_64` concluídos no GitHub Actions.
2. App aberto e testado em um Mac Apple Silicon e em um Mac Intel.
3. Arquivos criados com `ditto -c -k --keepParent` e nomeados com versão e arquitetura.
4. SHA-256 publicado ao lado de cada download.
5. URLs, arquitetura e versão atualizadas na página oficial.

## Origem verificável dos assets

O cliente consulta exclusivamente `Zealot-Server/tibia-client`, um fork público
controlado pela Zealot. Cada versão de assets é selecionada por release/tag e o
manifesto `assets.json.sha256` é verificado antes da instalação. Não se deve
desativar `strictManifestSha256` nem habilitar `allowRawFallbackHashMismatch`.
