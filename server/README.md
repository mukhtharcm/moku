# Moku Server

Custom [PocketBase](https://pocketbase.io) backend for the Moku ebook reader app.

## Prerequisites

- Go 1.24+

## Quick Start

```bash
# Install dependencies
go mod tidy

# Run the server (creates pb_data on first run)
go run main.go serve

# Or build and run
go build -o moku-server .
./moku-server serve
```

The server starts at **http://127.0.0.1:8090**.  
Admin UI is available at **http://127.0.0.1:8090/_/**.

## Custom Endpoints

| Method | Path          | Description          |
|--------|---------------|----------------------|
| GET    | `/api/health` | Health check         |

## Migrations

```bash
# Create a new migration
go run main.go migrate create <name>

# Apply migrations
go run main.go migrate up
```

## Docker

```bash
docker build -t moku-server .
docker run -p 8090:8090 -v moku_data:/app/pb_data moku-server
```

## Project Structure

```
server/
├── main.go            # Entry point with custom routes & hooks
├── migrations/        # Auto-generated migration files
│   └── main.go
├── Dockerfile
├── go.mod
└── go.sum
```
