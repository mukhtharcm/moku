# 📖 Moku — Offline-First Ebook Reader

<p align="center">
  <strong>Read anywhere. Sync everywhere.</strong>
</p>

Moku is an open-source, offline-first ebook reader for iOS, Android, and macOS with optional self-hostable sync. Read your books locally without any server, or connect to your own PocketBase instance to sync your library, reading progress, bookmarks, highlights, and collections across devices.

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

## 🏗️ Architecture

```
moku/
├── app/       # Flutter mobile app (iOS + Android)
├── macos-app/ # Native macOS app (Swift + SwiftUI)
└── server/    # PocketBase server (Go, self-hostable)
```

### App (`app/`)
- **Flutter** — Cross-platform UI framework
- **Bloc/Cubit** — Predictable state management
- **Drift** — Type-safe SQLite ORM for local storage
- **WebView** — EPUB rendering with custom CSS/JS for highlights
- **Material 3** — Modern, adaptive design system
- **5 format parsers** — EPUB, PDF, CBZ, TXT, HTML

### macOS App (`macos-app/`)
- **SwiftUI + SwiftData** — Native macOS framework with type-safe persistence
- **WKWebView** — EPUB rendering with custom JS pagination engine
- **PDFKit** — Native PDF reading
- **Multi-window** — Open multiple books simultaneously
- **Keyboard shortcuts** — ⌘O import, ⌘D bookmark, ⌘± font, ⌘] chapter, ⌘⇧F zen mode
- **Drag & drop** — Import books by dropping files onto the library

### Server (`server/`)
- **PocketBase** — Extended Go server with custom collections
- **Docker** — Easy self-hosting with multi-stage build
- **Auth** — Email/password authentication
- **File Storage** — EPUB and cover image sync

## 🚀 Getting Started

### Flutter App (iOS & Android)

```bash
cd app
flutter pub get
flutter run
```

### macOS App

```bash
cd macos-app
# Open in Xcode after generating the project:
xcodegen generate
open Moku.xcodeproj
```

Or download the latest release from [GitHub Releases](https://github.com/mukhtharcm/moku/releases).

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

Moku uses a warm, bookish design language:
- **Primary**: Purple (#6B4EFF)
- **Accent**: Warm Orange / Coral (#FF8A65)
- **Typography**: Serif fonts (Literata, Georgia) for reading, DM Sans for UI
- **Reader Themes**: Light, Dark, Sepia

## 🌏 Name

"Moku" (木) means "wood" or "tree" in Japanese, and in Hawaiian it refers to an island or district. The name evokes the natural, organic feeling of reading from paper — a tree-to-book connection.

## 📄 License

MIT