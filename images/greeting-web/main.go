package main

import (
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
)

var (
	environment     string
	serviceEndpoint string
)

func main() {
	environment = os.Getenv("ENV")
	if environment == "" {
		environment = "white"
	}
	serviceEndpoint = os.Getenv("SERVICE_ENDPOINT")
	if serviceEndpoint == "" {
		serviceEndpoint = "greeting-service"
	}

	slog.Info("application started", "port", "8080", "environment", environment, "service_endpoint", serviceEndpoint)
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

	m, err := message(name)
	if err != nil {
		slog.Error(err.Error())
		http.Error(w, "Error fetching greeting", http.StatusInternalServerError)
		return
	}

	// Return HTML response with background color
	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
	<title>Greeting</title>
	<style>
		body {
			background-color: %s;
			font-family: Arial, sans-serif;
			display: flex;
			justify-content: center;
			align-items: center;
			height: 100vh;
			margin: 0;
		}
		.message {
			font-size: 2em;
			text-align: center;
			padding: 20px;
			background-color: rgba(255, 255, 255, 0.8);
			border-radius: 10px;
		}
	</style>
</head>
<body>
	<div class="message">%s</div>
</body>
</html>`, environment, m)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if _, err := fmt.Fprint(w, html); err != nil {
		slog.Error("error writing response", "error", err)
		http.Error(w, "Error writing response", http.StatusInternalServerError)
	}
}

func message(name string) (string, error) {
	serviceURL := fmt.Sprintf("http://%s/?name=%s", serviceEndpoint, url.QueryEscape(name))
	response, err := http.Get(serviceURL)
	if err != nil {
		return "", fmt.Errorf("error calling greeting-service: %v", err)
	}
	defer response.Body.Close()

	responseBody, err := io.ReadAll(response.Body)
	if err != nil {
		slog.Error("error reading response", "error", err)
		return "", fmt.Errorf("error reading response: %v", err)
	}

	return string(responseBody), nil
}

func init() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))
}
