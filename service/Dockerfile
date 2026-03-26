# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o gcp-clouddeploy-gke-template .

# Final stage
FROM alpine:latest

RUN apk add --no-cache ca-certificates tzdata

RUN addgroup -S rdapp && adduser -S rdapp -G rdapp
USER rdapp

WORKDIR /app

COPY --from=builder /app/gcp-clouddeploy-gke-template .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["./gcp-clouddeploy-gke-template"]
