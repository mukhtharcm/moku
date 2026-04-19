# 📖 Moku — Offline-First Ebook Reader

<p align="center">
  <strong>Read anywhere. Sync everywhere.</strong>
</p>

Moku is an open-source, offline-first ebook reader for iOS and Android with optional self-hostable sync. Read your EPUB books locally without any server, or connect to your own PocketBase instance to sync your library, reading progress, bookmarks, highlights, and collections across devices.

## ✨ Features

- **📚 EPUB Reader** — Beautiful, distraction-free reading with customizable fonts, themes (light/dark/sepia), and smooth chapter navigation
- **📝 Highlights & Annotations** — Select text to highlight, add notes, and review all annotations per book
- **🔖 Bookmarks** — Save your place and jump back instantly
- **📂 Collections** — Organize books into custom shelves/collections
- **🔍 Discover** — Search Open Library's catalog of millions of books
- **🌙 Dark Mode** — Full system/light/dark theme support
- **📱 Offline-First** — Everything works locally, no server required
- **🔄 Optional Sync** — Self-host a PocketBase server or use a hosted instance to sync across devices
- **🗂️ Continue Reading** — Quick access to books you're currently reading

## 🏗️ Architecture

```
moku/
├── app/       # Flutter mobile app (iOS + Android)
└── server/    # PocketBase server (Go, self-hostable)
```

### App (`app/`)
- **Flutter** — Cross-platform UI framework
- **Bloc/Cubit** — Predictable state management
- **Drift** — Type-safe SQLite ORM for local storage
- **WebView** — EPUB rendering with custom CSS/JS for highlights
- **Material 3** — Modern, adaptive design system

### Server (`server/`)
- **PocketBase** — Extended Go server with custom collections
- **Docker** — Easy self-hosting with multi-stage build
- **Auth** — Email/password authentication
- **File Storage** — EPUB and cover image sync

## 🚀 Getting Started

### App

```bash
cd app
flutter pub get
flutter run
```

### Server (Self-Host)

```bash
cd server
go build -o moku-server .
./moku-server serve
```

Or with Docker:

```bash
cd server
docker build -t moku-server .
docker run -p 8090:8090 moku-server
```

## 🎨 Design

Moku uses a warm, playful design language:
- **Primary**: Purple (#6B4EFF)
- **Accent**: Warm Orange (#FF8A65)
- **Typography**: Inter (Google Fonts)
- **Reader Themes**: Light, Dark, Sepia

## 🌏 Name

"Moku" (木) means "wood" or "tree" in Japanese, and in Hawaiian it refers to an island or district. The name evokes the natural, organic feeling of reading from paper — a tree-to-book connection.

## 📄 License

MIT
