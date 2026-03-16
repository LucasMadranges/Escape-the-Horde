# ─── Stage 1 : Build ────────────────────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

# Dépendances système nécessaires à la compilation (cgo désactivé → pas besoin de gcc)
RUN apk add --no-cache git

WORKDIR /app

# Copier les fichiers de dépendances en premier pour profiter du cache Docker
COPY go.mod go.sum ./
RUN go mod download

# Copier le reste du code source
COPY . .

# Compiler un binaire statique sans CGO
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o api-server .

# ─── Stage 2 : Image finale ──────────────────────────────────────────────────────
FROM alpine:3.21

# Certificats TLS + timezone
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copier uniquement le binaire compilé
COPY --from=builder /app/api-server .

EXPOSE 3000

ENTRYPOINT ["./api-server"]
