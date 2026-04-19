FROM golang:1.24-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o moku-server .

FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /build/moku-server /app/moku-server

EXPOSE 8090

CMD ["/app/moku-server", "serve", "--http=0.0.0.0:8090"]
