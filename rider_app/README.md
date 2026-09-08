# MartFood Rider App

Flutter rider (delivery partner) app for MartFood. This package is **frontend-only**: data is mocked with Riverpod until backend services are wired in.

## Run

```bash
cd rider_app
flutter pub get
flutter run
```

## Architecture

- **Routing:** `go_router` with `StatefulShellRoute.indexedStack` for Home, Delivery, Earnings, Account.
- **State:** `flutter_riverpod` (`Notifier` / `NotifierProvider`) for availability, orders, bank details, and mock session.
- **Design:** `shared_widgets` (`AppTheme`, `CustomButton`, `CustomTextField`, `RiderBottomNavBar`, `SecondaryOutlinedButton`).

## Auth flow (mock)

Splash → Get started → Register (email/password → OTP → personal info → PIN → success) or Login (email/password → verify PIN) → main tabs.

## Delivery PIN (demo)

Active orders show a customer delivery code in state. By default order `MF-20481` uses **`1234`**, and `MF-20490` uses **`5678`**.
