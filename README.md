# QuoteBot (Flutter — No Expo)

Build steps via Codemagic (no Mac needed):

1) Put this folder in a new GitHub repo.
2) Create account on https://codemagic.io and connect the repo.
3) Select default **Flutter** workflow.
4) Under **iOS code signing**, add your App Store Connect API key (Issuer ID, Key ID, and the .p8 file).
5) Set **Bundle Identifier** to `com.jacobschwartz.quotebot` (or your own).
6) Start build → when finished, click **Publish to TestFlight** in Codemagic.

Local dev (optional): install Flutter SDK, then `flutter pub get`, `flutter run`.
