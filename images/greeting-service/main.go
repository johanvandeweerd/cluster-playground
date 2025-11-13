package main

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"
)

var (
	environment string
)

func main() {
	environment = os.Getenv("ENV")
	if environment == "" {
		environment = "no-env"
	}

	slog.Info("application started", "port", "8080", "environment", environment)
	if err := http.ListenAndServe(":8080", http.HandlerFunc(greetingHandler)); err != nil {
		slog.Error("server failed to start", "error", err)
		os.Exit(1)
	}
}

func greetingHandler(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	if name == "" {
		name = "anonymous"
	}

	message := fmt.Sprintf("Hello %s from %s", name, environment)
	w.Header().Set("Content-Type", "text/plain")
	if _, err := fmt.Fprint(w, message); err != nil {
		slog.Error("failed to write response", "error", err)
	}
}

func init() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))
}
