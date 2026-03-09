package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/segmentio/kafka-go"
)

var (
	ctx        context.Context
	reader     *kafka.Reader
	processing bool
)

func init() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
}

func main() {
	err := run()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func run() error {
	processing = true

	var stop context.CancelFunc
	ctx, stop = signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		<-ctx.Done()
		slog.Info("shutting down gracefully ...")
		processing = false
	}()

	reader = kafka.NewReader(kafka.ReaderConfig{
		Brokers:  []string{os.Getenv("KAFKA_ADDRESS")},
		GroupID:  "audit-service-group",
		Topic:    os.Getenv("KAFKA_TOPIC"),
		MaxBytes: 1e6, // 10MB
	})
	defer reader.Close()

	slog.Info("consuming messages ...")

	for processing {
		message, err := reader.ReadMessage(ctx)
		if err != nil {
			slog.ErrorContext(ctx, "failed to read message", "error", err)
			break
		}

		slog.InfoContext(ctx, "received message", "message", string(message.Value))
	}

	return nil
}
