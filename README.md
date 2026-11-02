# Acompanha

App para marcar **encontros pagos com anfitriões** (café, networking, mentoria, idiomas, viagem, social, treino) e achar **parceiros de treino** na própria academia, de graça.

- **Descobrir**: anfitriões com preço por hora, horários livres, reserva e pagamento no app.
- **Parceiros**: pessoas da mesma academia; pedido de parceria, aceite e convite para treinar junto.
- **Reservas**: as que você fez, as que recebeu como anfitrião e os treinos marcados com parceiros. Dá para cancelar (com reembolso até 24h antes) e avaliar depois do encontro.
- **Mensagens**: chat entre cliente e anfitrião (depois de uma reserva) e entre parceiros de treino.
- **Perfil**: perfil de treino, foto, anúncio de anfitrião, agenda de horários, ajuda, privacidade e exclusão de conta.

## Stack

- **App**: Flutter, Riverpod, go_router, Dio, flutter_stripe
- **API**: Django 6 + Django REST Framework, JWT (simplejwt), PostgreSQL, Stripe

```
lib/
├── app/routes/          # go_router + barra inferior
├── core/                # rede (renovação de token), modelos, tema, widgets, formatação
└── features/
    ├── auth/            # login, cadastro, senha, contas salvas, tela de abertura
    ├── discovery/       # feed paginado e filtros
    ├── search/          # busca no servidor + "perto de mim"
    ├── booking/         # perfil do anfitrião, horários, confirmação e pagamento
    ├── bookings/        # minhas reservas / recebidas / avaliação
    ├── matches/         # parceiros de treino e treinos marcados
    ├── chat/            # conversas
    └── profile/         # perfis, academia, agenda, ajuda, privacidade

backend/
├── accounts/   # usuários, login, senha, exclusão de conta
├── profiles/   # anúncios de anfitrião, fotos, horários, categorias
├── bookings/   # reservas, cancelamento/reembolso, avaliações, treinos entre parceiros
├── payments/   # Stripe (pagamento de reserva, plano Pro de personal trainer, webhook)
├── matches/    # pedidos de parceria
├── chat/       # conversas e mensagens
├── safety/     # bloqueios e denúncias (moderação no admin)
├── legal/      # páginas públicas: /termos/ e /privacidade/
└── gyms/       # academias
```

## Rodando o backend

Precisa de Python 3.12+ e PostgreSQL.

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Banco local (os nomes padrão podem ser trocados pelas variáveis abaixo)
createuser gymbuddy --createdb -P      # senha: gymbuddy_dev
createdb gymbuddy -O gymbuddy

python manage.py migrate
python manage.py createsuperuser        # acesso ao /admin
python manage.py runserver 127.0.0.1:8000
```

### Dados de demonstração

```bash
python manage.py seed_hosts --count 500                 # anfitriões com horários e fotos
python manage.py seed_gym_members --join voce@email.com  # coloca gente (e você) numa academia
python manage.py seed_demo_photos                       # (re)aplica as fotos nas contas de demo
python manage.py refresh_demo_slots                     # renova horários vencidos dos anfitriões de demo
```

Os horários de demonstração vencem com o tempo; rode `refresh_demo_slots` quando a descoberta ficar sem horários livres.

As fotos de demonstração são fotos reais do [Unsplash](https://unsplash.com/license) (uso livre), escolhidas à mão em `backend/profiles/demo_photos.py`: rostos separados por gênero para combinar com o primeiro nome, e fotos de ambiente por categoria (café, viagem, treino…) para a galeria do anfitrião. Na primeira vez elas são baixadas para `backend/media/demo/` (cerca de 25 MB, fora do git) e compartilhadas entre as contas de demonstração; contas reais não são tocadas. Servem só para desenvolvimento: para prints da loja ou divulgação, use fotos com autorização de imagem.

### Testes

```bash
python manage.py test        # o usuário do banco precisa de CREATEDB
```

### Variáveis de ambiente

| Variável | Para quê | Padrão |
|---|---|---|
| `DJANGO_SECRET_KEY` | chave secreta (obrigatória com `DJANGO_DEBUG=False`) | chave de dev |
| `DJANGO_DEBUG` | modo debug | `True` |
| `DJANGO_ALLOWED_HOSTS` | domínios aceitos, separados por vírgula | `*` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` | PostgreSQL | `gymbuddy` / `gymbuddy_dev` / `localhost:5432` |
| `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` | pagamentos | vazio (sem pagamento) |
| `STRIPE_WEBHOOK_SECRET` | assinatura do webhook `/api/v1/payments/webhook/` | vazio |
| `STRIPE_TRAINER_PRICE_ID` | preço do plano Pro (ver abaixo) | vazio |
| `ALLOW_UNPAID_BOOKINGS` | confirma reservas sem cobrar (só para desenvolvimento) | `True` em debug sem Stripe |
| `FREE_CANCELLATION_HOURS` | antecedência mínima para reembolso | `24` |
| `BOOKING_PAYMENT_WINDOW_MINUTES` | quanto tempo uma reserva não paga segura o horário | `30` |
| `EMAIL_BACKEND`, `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL` | envio do código de senha (em dev o e-mail sai no console) | console |
| `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | login com Facebook | vazio |
| `SERVE_MEDIA`, `MEDIA_ROOT` | servir fotos pelo próprio Django em produção simples | `False` |
| `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` | origens web permitidas em produção | vazio |
| `DATABASE_URL` | PostgreSQL numa URL só (Render, Railway, Neon...); substitui os `DB_*` | vazio |
| `AWS_STORAGE_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_ENDPOINT_URL`, `AWS_S3_CUSTOM_DOMAIN` | fotos num bucket S3 ou Cloudflare R2 em vez do disco | vazio (disco) |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | assinatura do webhook de contas conectadas (recebimentos dos anfitriões) | vazio |
| `PLATFORM_FEE_PERCENT` | % de cada reserva que fica com o Acompanha | `15` |
| `SUPPORT_EMAIL` | e-mail de contato nas páginas de termos e privacidade | `suporte@acompanha.app` |
| `MODERATION_EMAIL` | recebe um e-mail a cada denúncia | vazio (só o admin) |
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | monitor de erros (sentry.io) | vazio (desligado) |

### Pagamentos (Stripe)

Sem chave do Stripe e com `DEBUG` ligado, o servidor fica em **modo de teste**: a reserva é confirmada sem cobrança e o app mostra um aviso. Para cobrar de verdade:

1. Pegue as chaves em https://dashboard.stripe.com/apikeys e defina `STRIPE_SECRET_KEY` e `STRIPE_PUBLISHABLE_KEY`.
2. Crie um webhook apontando para `https://SEU_DOMINIO/api/v1/payments/webhook/` com os eventos `payment_intent.succeeded`, `payment_intent.payment_failed` e `customer.subscription.*`, e defina `STRIPE_WEBHOOK_SECRET`.
3. (Plano Pro de personal trainer) `python manage.py setup_trainer_plan --amount 12` e copie o `STRIPE_TRAINER_PRICE_ID` impresso.

O app busca a chave pública em `/api/v1/payments/config/`; não precisa recompilar para trocar entre teste e produção.

#### Recebimentos dos anfitriões (Stripe Connect)

Cada anfitrião recebe a parte dele direto numa conta Stripe Express: o cliente paga uma vez, o anfitrião recebe o valor menos `PLATFORM_FEE_PERCENT`, e um reembolso estorna as duas partes. Com pagamentos ligados, **só aparece na busca e só pode ser reservado quem terminou o cadastro de recebimentos** (o app mostra o cartão "Configure seus recebimentos" no Perfil).

1. No painel do Stripe, ative o **Connect** (contas Express, Brasil).
2. Crie um segundo webhook, do tipo **contas conectadas**, para `https://SEU_DOMINIO/api/v1/payments/webhook/` com o evento `account.updated`, e defina `STRIPE_CONNECT_WEBHOOK_SECRET`.
3. Defina `PLATFORM_FEE_PERCENT` com a comissão que você quer.

### Publicando a API (Docker)

O `backend/Dockerfile` serve em qualquer hospedagem de contêiner (Render, Railway, Fly.io...). Ao subir, ele aplica as migrações e roda o gunicorn; os arquivos estáticos do admin já vão na imagem (WhiteNoise).

```bash
cd backend
docker build -t acompanha-api .
docker run -p 8000:8000 --env-file .env acompanha-api
```

Mínimo para produção: `DJANGO_DEBUG=False`, `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS`, `DATABASE_URL`, as chaves do Stripe e um SMTP. A verificação de saúde da hospedagem pode usar `/healthz/`.

### Moderação

Denúncias chegam em **/admin › Segurança › Denúncias**, com as últimas mensagens da conversa quando vieram do chat. No admin dá para marcar como analisada ou suspender a conta denunciada (sai do ar e todas as sessões são encerradas). Com `MODERATION_EMAIL`, cada denúncia também gera um e-mail.

As páginas `/termos/` e `/privacidade/` (links no cadastro e em Perfil › Privacidade) são **rascunhos**: preencha os campos entre colchetes (razão social, CNPJ, endereço, encarregado de dados) e revise com um advogado antes de publicar.

## Rodando o app

```bash
flutter pub get
flutter run                     # simulador iOS / emulador Android falam com o backend local
```

- **Aparelho físico ou servidor remoto**: `flutter run --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1`
- **Login com Facebook**: cadastre o app em https://developers.facebook.com, troque os `YOUR_FACEBOOK_*` em `ios/Runner/Info.plist` e `android/app/src/main/res/values/strings.xml`, e rode com `--dart-define=FACEBOOK_LOGIN=true` (sem isso o botão fica escondido).
- **Mapa no perfil do anfitrião**: troque `YOUR_GOOGLE_MAPS_API_KEY` em `ios/Runner/AppDelegate.swift` e `android/app/src/main/AndroidManifest.xml` e rode com `--dart-define=GOOGLE_MAPS=true` (sem isso o mapa fica escondido, em vez de aparecer em branco).
- **Android**: o Gradle do projeto (8.14) não roda com Java 25. Se o build reclamar da versão do Java, aponte o Flutter para um JDK 21: `flutter config --jdk-dir="$HOME/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home"`.
- **Monitor de erros**: rode/compile com `--dart-define=SENTRY_DSN=...` (sem isso fica desligado).

### Ícone e tela de abertura

O ícone e a tela de abertura atuais são provisórios (um "A" no gradiente da marca), gerados a partir de `assets/brand/`. Para usar o logo de verdade, troque esses PNGs mantendo os tamanhos e rode:

```bash
dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

### Publicando no Google Play (assinatura)

Crie uma vez a chave de envio e guarde-a fora do projeto (perder essa chave dá muito trabalho):

```bash
keytool -genkey -v -keystore ~/acompanha-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Depois crie `android/key.properties` (fica fora do git):

```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=/Users/voce/acompanha-upload.jks
```

E gere o pacote com `flutter build appbundle --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1`. Sem o `key.properties`, o build de lançamento é assinado com a chave de testes.

### Testes

```bash
flutter analyze
flutter test
```

## Antes de publicar nas lojas

Já pronto no código: denunciar e bloquear usuários, termos e privacidade com aceite (e confirmação de 18+) no cadastro, recebimentos dos anfitriões pelo Stripe Connect, monitor de erros, Dockerfile da API, assinatura do Android e ícone provisório.

- [ ] Contas: Apple Developer (US$ 99/ano) e Google Play Console (US$ 25, uma vez).
- [ ] Identificador do app (`com.example.projeto_apollo` / `com.example.projetoApollo` → o seu) e o logo de verdade no lugar do ícone provisório.
- [ ] Hospedar a API (ver "Publicando a API") com domínio HTTPS, PostgreSQL gerenciado com backup e as fotos num bucket.
- [ ] Chaves de produção: Stripe (com Connect ativado), Google Maps, Sentry e (opcional) Facebook.
- [ ] Testar o pagamento de ponta a ponta com as chaves de teste do Stripe: pagar, cancelar com reembolso, plano Pro e o cadastro de recebimentos de um anfitrião.
- [ ] SMTP real para o código de redefinição de senha.
- [ ] Termos e privacidade: preencher os dados da empresa e revisar com um advogado.
- [ ] Notificações push (Firebase/APNs) para mensagens e reservas — hoje o chat atualiza por consulta periódica. Precisa do projeto no Firebase.
- [ ] Testar em aparelhos reais (iPhone e Android).
- [ ] Páginas das lojas: prints, descrição, formulários de privacidade (Apple) e segurança de dados (Google).
