# Society

App para organizar o futebol da semana: cola a lista do WhatsApp, marca quem chegou, sorteia os times e controla quem pagou.

**Abrir:** https://brunotaveiradasilva.github.io/society/

No iPhone, abra o link no Safari e toque em **Compartilhar → Adicionar à Tela de Início** para usar como app.

## O que faz

- Organiza a lista colada do grupo em goleiros, linha e lista de espera (tira numeração, emojis e @menções).
- Cada fut fica salvo com a data; o próximo pode repetir a lista do anterior.
- Sorteio com quantidade de times, jogadores por time, goleiro fixo e cor de cada time.
- Os times sorteados ficam travados; quem chegar depois entra no sorteio do próximo time.
- Chamada com "foi" e "pagou", valor por pessoa e lista de quem falta pagar.
- Grupo por link: quem abre o link vê e edita os mesmos futs, e as mudanças aparecem na hora.

Sem grupo, os dados ficam só no aparelho. Com grupo, ficam também no Firestore (projeto Firebase `society-fut`); as regras em `firestore.rules` só deixam abrir um grupo quem tem o código do link. Se duas pessoas mexem no mesmo fut ao mesmo tempo, o app junta as duas mudanças.

## Rodando

```bash
flutter pub get
flutter run -d chrome
flutter test
```

Atualizar as regras do Firestore:

```bash
npx firebase-tools deploy --only firestore:rules
```

Publicar no GitHub Pages:

```bash
flutter build web --release --base-href /society/
```
