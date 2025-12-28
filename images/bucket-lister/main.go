package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/prometheus"
	m "go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/sdk/metric"
)

var (
	s3Client       *s3.Client
	successCounter m.Int64Counter
	failedCounter  m.Int64Counter
)

func init() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
}

func main() {
	ctx := context.Background()

	slog.Info("start service")

	slog.Info("init metrics")
	exporter, err := prometheus.New()
	if err != nil {
		panic(err)
	}
	provider := metric.NewMeterProvider(metric.WithReader(exporter))
	otel.SetMeterProvider(provider)
	meter := otel.Meter("bucket-lister")
	successCounter, err = meter.Int64Counter("bucket_lister_requests_success_total")
	failedCounter, _ = meter.Int64Counter("bucket_lister_requests_failed_total")

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		slog.Error("unable to load SDK config", "error", err)
		return
	}

	s3Client = s3.NewFromConfig(cfg)

	http.Handle("/", http.HandlerFunc(listBuckets))
	http.Handle("/metrics", promhttp.Handler())

	slog.Info("server running on port 8080 ...")

	err = http.ListenAndServe(":8080", nil)
	if err != nil {
		slog.Error("error during listen and serve on port 8080", "error", err.Error())
		os.Exit(1)
	}
}

func listBuckets(w http.ResponseWriter, r *http.Request) {
	result, err := s3Client.ListBuckets(r.Context(), &s3.ListBucketsInput{})
	if err != nil {
		failedCounter.Add(r.Context(), 1)
		slog.Error("unable to list buckets", "error", err.Error())
		http.Error(w, "unable to list buckets", http.StatusInternalServerError)
		return
	}

	for _, bucket := range result.Buckets {
		fmt.Fprintln(w, *bucket.Name)
	}

	successCounter.Add(r.Context(), 1)
	slog.Info("buckets listed")
}
