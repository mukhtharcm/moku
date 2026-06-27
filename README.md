# 📖 Moku — Offline-First Ebook Reader

<p align="center">
  <strong>Read anywhere. Sync everywhere.</strong>
</p>

<p align="center">
  <a href="https://testflight.apple.com/join/s3K7DF7H">Join the iOS TestFlight</a>
  ·
  <a href="https://github.com/mukhtharcm/moku/releases/latest">Download the macOS app</a>
</p>

Moku is an open-source, offline-first ebook reader for iOS, Android, and macOS with optional self-hostable sync. Read locally without any server, or connect to your own PocketBase instance to sync your library, reading progress, bookmarks, highlights, and collections across devices.

## ✨ Features

- **📚 Multi-Format Reader** — EPUB, PDF, CBZ (comics), TXT, and HTML files with format-specific renderers
- **📝 Highlights & Annotations** — Select text to highlight with color, add notes, and review all annotations per book
- **🔖 Bookmarks** — Save your place and jump back instantly
- **📂 Collections** — Organize books into custom shelves/collections
- **🔍 Discover** — Search Open Library and Project Gutenberg, or add your own OPDS catalogs
- **🌙 Dark Mode** — Full system/light/dark/sepia theme support
- **📱 Offline-First** — Everything works locally, no server required
- **🔄 Optional Sync** — Self-host a PocketBase server or use a hosted instance to sync across devices
- **🗂️ Continue Reading** — Quick access to books you're currently reading
- **🎯 Whole-Book Progress** — Scrub across the entire book, not just within a chapter
- **🖋️ Font Customization** — Font family, size, line height, and margins for a personalized reading experience

## 🚦 Availability

- **iOS** — Public TestFlight is available at [testflight.apple.com/join/s3K7DF7H](https://testflight.apple.com/join/s3K7DF7H)
- **macOS** — Signed and notarized DMG/ZIP releases are published on [GitHub Releases](https://github.com/mukhtharcm/moku/releases/latest)
- **Android** — Signed canary APKs are produced by CI and delivered as workflow/Telegram artifacts
- **App Store production** — Not publicly released yet; current iOS distribution is TestFlight

## 🏗️ Architecture

```
moku/
├── app/       # Flutter app for iOS, Android, and macOS
├── server/    # PocketBase server (Go, self-hostable)
├── website/   # Cloudflare Pages site
└── .github/   # CI/CD workflows and packaging scripts
```

### Flutter App (`app/`)

- **Flutter** — Shared app code for iOS, Android, and macOS
- **Bloc/Cubit** — Predictable state management
- **Drift** — Type-safe SQLite ORM for local storage
- **WebView** — EPUB rendering with custom CSS/JS for highlights
- **Material 3** — Modern, adaptive design system
- **Platform runners** — Native iOS, Android, and Flutter macOS shells
- **5 format parsers** — EPUB, PDF, CBZ, TXT, HTML

### Server (`server/`)

- **PocketBase** — Extended Go server with custom collections
- **Docker** — Easy self-hosting with multi-stage build
- **Auth** — Email/password authentication
- **File Storage** — EPUB and cover image sync

## 🚀 Getting Started

### App Development

```bash
cd app
flutter pub get
flutter run
```

Pick a specific target when needed:

```bash
flutter run -d macos
flutter run -d ios
flutter run -d android
```

Run tests from the Flutter app directory:

```bash
cd app
flutter test
```

### Prebuilt Builds

- **iOS** — Install the public beta from [TestFlight](https://testflight.apple.com/join/s3K7DF7H)
- **macOS** — Download the latest signed and notarized release from [GitHub Releases](https://github.com/mukhtharcm/moku/releases/latest)

### Server (Self-Host)

**Option 1 — Go binary:**

```bash
cd server
go build -o moku-server .
./moku-server serve
```

**Option 2 — Docker Compose (recommended):**

```bash
cd server

# Copy and edit environment variables
cp .env.example .env
# Edit .env and set your admin email/password

docker compose up -d
```

A `.env.example` is provided — set `PB_SUPERUSER_EMAIL` and `PB_SUPERUSER_PASSWORD` and the container will create the admin account on first boot.

**Option 3 — Pre-built image from GHCR:**

```bash
docker run -d \
  -p 8090:8090 \
  -v moku_data:/app/pb_data \
  -e PB_SUPERUSER_EMAIL=admin@example.com \
  -e PB_SUPERUSER_PASSWORD=changeme \
  --name moku-server \
  --restart unless-stopped \
  ghcr.io/mukhtharcm/moku-server:latest
```

The server exposes:

- **API** — `http://localhost:8090/api/`
- **Admin UI** — `http://localhost:8090/_/`

## 🚢 Release Automation

- **iOS TestFlight** — `Deploy to TestFlight` runs on `v*` tags or manual dispatch, builds a signed IPA, uploads it to TestFlight, waits for processing with `asc`, applies beta metadata, validates the build, and submits it to the public group `Friends :)`
- **macOS GitHub Releases** — `Release macOS App` runs on `v*` tags or manual dispatch, builds Flutter macOS from `app/`, signs with Developer ID, notarizes with `asc`, staples the app and DMG, uploads workflow artifacts, and publishes ZIP/DMG assets to GitHub Releases when triggered by a tag or manual `publish_release=true`
- **Android canary** — `Build Android Canary` runs on `main` changes under `app/**` or manual dispatch, builds signed split APKs, uploads workflow artifacts, and posts the APKs to Telegram
- **Server image** — `Build and Push Server Image` publishes the PocketBase server image to GHCR when `server/**` changes
- **Website** — `Deploy Website` publishes the website to Cloudflare Pages when `website/**` changes

### Release Secrets

App Store Connect API key secrets are shared by iOS TestFlight and macOS notarization:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_BASE64`

iOS TestFlight also requires:

- `IOS_DISTRIBUTION_CERT_BASE64`
- `IOS_DISTRIBUTION_CERT_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`

macOS GitHub releases also require:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `SIGNING_IDENTITY`

Android canary releases require:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

For local Android release builds, copy `app/android/key.properties.example` to `app/android/key.properties` and fill in the same values. `ANDROID_KEYSTORE_PATH` may be absolute or relative to `app/android/`.

### Local macOS Packaging

The same packaging path used by CI can be run locally after exporting the signing and notarization environment variables:

```bash
VERSION=1.1.2 \
BUILD_NUMBER=7 \
SIGNING_IDENTITY="Developer ID Application: ..." \
ASC_KEY_ID="..." \
ASC_ISSUER_ID="..." \
NOTARYTOOL_KEY_PATH="$HOME/.private_keys/AuthKey_XXXX.p8" \
NOTARIZE=true \
.github/scripts/package_macos_flutter.sh
```

The script writes release artifacts to `dist/macos/<version>/`.

## 🎨 Design

Moku uses a warm, bookish design language:

- **Primary**: Purple (#6B4EFF)
- **Accent**: Warm Orange / Coral (#FF8A65)
- **Typography**: Serif fonts (Literata, Georgia) for reading, DM Sans for UI
- **Reader Themes**: Light, Dark, Sepia

## 🌏 Name

"Moku" (木) means "wood" or "tree" in Japanese, and in Hawaiian it refers to an island or district. The name evokes the natural, organic feeling of reading from paper — a tree-to-book connection.

## 📄 License

MIT
