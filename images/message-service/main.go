package main

import (
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
)

var (
	prefix = []string{
		"Bonjour",
		"Halo",
		"Hello",
		"Hola",
		"Marhaba",
		"Namaste",
		"Ni hao",
		"Nomoshkar",
		"Ola",
		"Zdravstvuyte",
	}
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
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", messageHandler)

	slog.Info("starting HTTP server", "address", ":8080")

	if err := http.ListenAndServe(":8080", mux); err != nil {
		return err
	}

	return nil
}

func messageHandler(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "received message request")

	if !r.URL.Query().Has("name") || r.URL.Query().Get("name") == "" {
		slog.WarnContext(r.Context(), "no name parameter provided")
		w.WriteHeader(http.StatusBadRequest)
	}

	message := prefix[rand.Intn(10)] + ", " + r.URL.Query().Get("name")

	slog.InfoContext(r.Context(), "message generated", "message", message)

	w.WriteHeader(http.StatusOK)
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(message))
}
