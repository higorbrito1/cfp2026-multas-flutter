# Consulta CTB/MBFT

Aplicativo Flutter offline para consulta rápida de infrações do CTB e MBFT.

## Recursos

- Pesquisa por código, artigo, descrição e campos da ficha.
- Detalhamento completo com seções retráteis.
- Favoritos persistentes com indicação visual e confirmação ao salvar.
- Atualização da base quando houver internet, mantendo uso offline.
- Manifesto das fontes oficiais do CONTRAN/SENATRAN com data da última verificação.
- Interface em modo escuro para uso em campo.
- Crédito discreto: Feito por Higor Brito.

## Atualização das fontes oficiais

O aplicativo baixa a base de infrações e um manifesto de fontes pelo GitHub. O
workflow [`check-official-sources.yml`](.github/workflows/check-official-sources.yml)
verifica diariamente as páginas oficiais do CONTRAN e da SENATRAN e registra
novas resoluções, deliberações, portarias e documentos para revisão.

Documentos oficiais não são convertidos automaticamente em infrações: mudanças
normativas precisam ser conferidas antes de alterar a base do MBFT. Assim, o
aplicativo mantém a operação offline e evita que uma alteração de PDF seja
publicada sem validação.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
