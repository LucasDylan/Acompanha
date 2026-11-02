# Acompanha: o que falta para lançar

Atualizado em 3/10/2026. Marque `[x]` conforme for concluindo. Cada item diz quem faz e como saber que terminou.

**Legenda:** 🔴 bloqueia o lançamento · 🟡 importante logo no começo · 🟢 pode vir depois
**Quem faz:** 👤 você · 🤖 Claude (no código) · 👤🤖 você cria a conta ou chave, Claude liga no app

---

## 1. Decisões (fazer primeiro, porque travam o resto)

- [ ] 🔴 👤 **Identificador do app.** Hoje é `com.example...`, e o Google Play recusa. Sugestão: `br.com.acompanha.app`.
  *Pronto quando:* você escolheu e Claude trocou no Android e no iOS.
- [ ] 🔴 👤 **Comissão da plataforma.** Hoje está em 15%, valor provisório (`PLATFORM_FEE_PERCENT`).
  *Pronto quando:* o valor final está definido.
- [ ] 🟡 👤 **Login com Facebook: fica ou sai?** Se sair, a privacidade nas lojas fica mais simples (sem ID de publicidade).
  *Pronto quando:* você decidiu e Claude removeu ou configurou.
- [ ] 🟡 👤 **Logo definitivo.** O ícone atual é provisório.
  *Pronto quando:* os PNGs de `assets/brand/` foram trocados e os ícones gerados de novo (comando no README).

## 2. Contas

- [ ] 🔴 👤 **Apple Developer Program** (US$ 99/ano). Como empresa, precisa do número D-U-N-S, que leva alguns dias.
- [ ] 🔴 👤 **Google Play Console** (US$ 25, uma vez). Numa conta pessoal, o teste fechado exige 12 testadores por 14 dias seguidos.
- [ ] 🔴 👤 **Stripe** com o **Connect** ativado (contas Express, Brasil).
- [ ] 🟡 👤 **Sentry** (monitor de erros; o plano gratuito serve no começo).
- [ ] 🟡 👤 **Google Cloud**, para a chave do Google Maps. Sem ela, o mapa do perfil fica escondido.
- [ ] 🟡 👤 **Firebase**, para as notificações push.
- [ ] 🟡 👤 **Serviço de e-mail** (SendGrid, Mailgun, Amazon SES...), para o código de recuperação de senha.

## 3. Chaves e assinaturas

- [ ] 🔴 👤 **Chave de assinatura do Android.** O comando está no README; guarde o arquivo `.jks` e a senha com backup.
- [ ] 🔴 👤 **Assinatura da Apple.** No Xcode: conta, Team e "Automatically manage signing".
- [ ] 🔴 👤🤖 **Ligar as chaves do Stripe** no servidor (`STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` e os dois webhooks).
- [ ] 🟡 👤🤖 **Chave do Google Maps** no iOS e no Android, e build com `--dart-define=GOOGLE_MAPS=true`.
- [ ] 🟡 👤🤖 **Chave do Sentry** no servidor e no build do app.

## 4. Servidor na internet

- [ ] 🔴 👤🤖 **Hospedar a API** com o Dockerfile pronto (Render, Railway, Fly.io...).
  *Pronto quando:* `https://SEU_DOMINIO/healthz/` responde `{"status": "ok"}`.
- [ ] 🔴 👤 **Domínio** com HTTPS (ex.: `api.acompanha.app`).
- [ ] 🔴 👤 **PostgreSQL gerenciado** com backup automático.
- [ ] 🔴 👤 **Bucket para as fotos** (Cloudflare R2 ou S3).
- [ ] 🔴 👤 **Configurações de produção:** `DJANGO_DEBUG=False`, `DJANGO_SECRET_KEY` forte, `DJANGO_ALLOWED_HOSTS`, SMTP e `MODERATION_EMAIL`.
- [ ] 🔴 👤 **Admin de produção:** criar o usuário administrador (`python manage.py createsuperuser`), para moderar denúncias.

## 5. Funcionalidades que ainda faltam

- [ ] 🟡 🤖 **Notificações push** (mensagem nova, reserva confirmada ou cancelada). Depende do Firebase (item 2).
- [ ] 🟢 🤖 **Página web para pedir exclusão de conta**, que o Google Play pede além da opção dentro do app.
- [ ] 🟢 🤖 **Declaração de criptografia no Info.plist**, para a Apple não perguntar a cada envio.
- [ ] 🟢 🤖 **Commit do trabalho de 3/10.** As alterações estão salvas, mas sem commit; é só pedir.

## 6. Jurídico e negócio

- [ ] 🔴 👤 **Termos de uso e política de privacidade:** preencher razão social, CNPJ, endereço e encarregado de dados, e revisar com um advogado (`backend/legal/templates/legal/`).
- [ ] 🔴 👤 **CNPJ e contabilidade,** por causa de nota fiscal e impostos sobre as comissões.
- [ ] 🟡 👤 **Anfitriões reais** na cidade de lançamento. As contas de demonstração não vão para produção.

## 7. Testes antes de enviar

- [ ] 🔴 👤🤖 **Pagamento de ponta a ponta** com as chaves de teste do Stripe:
  - um anfitrião faz o cadastro de recebimento;
  - um cliente reserva e paga;
  - o cliente cancela e recebe o reembolso;
  - o plano Pro.
- [ ] 🔴 👤 **iPhone de verdade,** pelo TestFlight.
- [ ] 🔴 👤 **Android de verdade,** pelo teste interno e depois pelo teste fechado (12 pessoas por 14 dias).
- [ ] 🟡 👤 **Moderação:** denunciar alguém e conferir que a denúncia aparece no admin e chega por e-mail.

## 8. Páginas das lojas

- [ ] 🔴 👤 **Textos:** o rascunho está em [`docs/lojas.md`](docs/lojas.md); revisar.
- [ ] 🔴 👤 **Prints do app,** feitos com dados e fotos reais e autorizados. As fotos de demonstração não podem ir para a loja.
- [ ] 🔴 👤 **Formulários de privacidade** da Apple e do Google; as respostas estão em `docs/lojas.md`.
- [ ] 🔴 👤 **Enviar para revisão** nas duas lojas.

---

## Já pronto (3/10)

- Chat, reservas, pagamento, cancelamento com reembolso, avaliações, parceiros de treino e plano Pro.
- Denunciar e bloquear usuários, com a fila de moderação no admin.
- Termos de uso e política de privacidade (rascunhos), aceite e confirmação de 18+ no cadastro.
- Recebimentos dos anfitriões pelo Stripe Connect, com comissão configurável.
- Monitor de erros (Sentry) no servidor e no app, ligado por chave.
- Dockerfile e configuração de produção do servidor.
- Assinatura do Android configurada, ícone e tela de abertura provisórios.
- Fotos de demonstração e explicação de cada tipo de encontro.
- Testes automáticos: 64 no servidor e 35 no app.
