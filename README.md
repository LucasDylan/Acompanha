# Social Meeting

A mobile app to book paid meetings with hosts (coffee, mentorship, networking, language practice, travel companionship).

## Stack

- **Frontend**: Flutter (Riverpod, go_router)
- **Backend**: Django REST API
- **Database**: SQLite (dev) / PostgreSQL (prod)

## Flutter - Run MVP

```bash
flutter pub get
flutter run
```

**Demo login**: On the login screen, tap "Demo login (no backend)" to test the app without a backend.

### Structure (Feature-first)

```
lib/
├── main.dart
├── app/
│   └── routes/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── network/
│   ├── models/
│   └── widgets/
└── features/
    ├── auth/          # Login, register, JWT
    ├── profile/       # Host profile, photo upload
    ├── discovery/     # Browse hosts, filters
    ├── booking/       # Slots, host detail, confirm
    ├── bookings/      # My bookings list
    └── chat/          # Messages (placeholder)
```

## Django Backend

```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

For Android emulator: Flutter uses `http://10.0.2.2:8000` by default for API.

## Features (MVP)

- [x] Auth (email/password, JWT, demo login)
- [x] Registration
- [x] Host profile (create, edit, photo upload)
- [x] Discovery (mock hosts, filters)
- [x] Host detail + time slots
- [x] Booking flow (date/time, payment placeholder)
- [x] Bottom nav (Discover, Bookings, Messages, Profile)
- [x] Chat UI (static, WebSocket-ready)
- [x] Django models & auth API

## Roadmap

- [ ] Stripe payment integration
- [ ] WebSocket chat
- [ ] Push notifications
- [ ] Calendar sync
