FROM golang:1.23 AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /app

COPY go.mod main.go ./
RUN go mod tidy && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOOS=linux CGO_ENABLED=0 go build -o service main.go

FROM gcr.io/distroless/static-debian12 AS service

LABEL org.opencontainers.image.description="Simple webserver written in Go that lists the S3 buckets for the active AWS profile."

WORKDIR /

COPY --from=builder /app/service /service

ENTRYPOINT ["/service"]

EXPOSE 8080
