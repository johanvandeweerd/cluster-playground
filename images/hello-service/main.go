package main

import (
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"

	"github.com/segmentio/kafka-go"
)

var (
	writer *kafka.Writer
)

func init() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
}

func main() {
	err := run()
	if err != nil {
		slog.Error(err.Error())
		os.Exit(1)
	}
}

func run() error {
	writer = &kafka.Writer{
		Addr:     kafka.TCP(os.Getenv("KAFKA_ADDRESS")),
		Topic:    os.Getenv("KAFKA_TOPIC"),
		Balancer: &kafka.LeastBytes{},
	}
	defer writer.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /hello", helloHandler)

	slog.Info("starting HTTP server", "address", ":8080")

	if err := http.ListenAndServe(":8080", mux); err != nil {
		return err
	}

	return nil
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "received hello request")

	if !r.URL.Query().Has("name") || r.URL.Query().Get("name") == "" {
		slog.WarnContext(r.Context(), "no name parameter provided")
		w.WriteHeader(http.StatusBadRequest)
	}

	name := r.URL.Query().Get("name")

	slog.InfoContext(r.Context(), "calling message service", "name", name)
	message, err := messageService(name)
	if err != nil {
		slog.ErrorContext(r.Context(), "failed to call message service", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	slog.InfoContext(r.Context(), "message service called", "name", name)

	slog.InfoContext(r.Context(), "calling audit service", "name", name)
	err = writer.WriteMessages(r.Context(), kafka.Message{
		Key:   []byte(name),
		Value: []byte(message),
	})
	if err != nil {
		slog.ErrorContext(r.Context(), "failed to write message to Kafka", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
	}
	slog.InfoContext(r.Context(), "audit service called", "name", name)

	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, message)
}

func messageService(name string) (string, error) {
	get, err := http.Get(os.Getenv("MESSAGE_SERVICE_URL") + "?name=" + name)
	if err != nil {
		return "", fmt.Errorf("failed to call message service: %w", err)
	}
	defer get.Body.Close()

	body, err := io.ReadAll(get.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response from message service: %w", err)
	}

	return string(body), nil
}
