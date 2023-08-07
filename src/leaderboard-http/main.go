package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/hashicorp/vault/api"

	_ "github.com/lib/pq"
)

func handleRequest(ctx context.Context, request events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {

	fmt.Println("Started processing request, secrets injected")

	// Check for required env vars env vars
	secretFile := os.Getenv("VAULT_SECRET_FILE_DB")
	if secretFile == "" {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, errors.New("no VAULT_SECRET_FILE_DB environment variable, exiting")
	}

	dbURL := os.Getenv("DATABASE_ADDR")
	if dbURL == "" {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, errors.New("no DATABASE_ADDR environment variable, exiting")
	}

	// Read the secret from the file before processing the event
	secretRaw, err := ioutil.ReadFile(secretFile)
	if err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, fmt.Errorf("error reading file: %w", err)
	}

	// Decode the JSON into a map[string]interface{}
	var secret api.Secret
	b := bytes.NewBuffer(secretRaw)
	dec := json.NewDecoder(b)
	dec.UseNumber()

	if err := dec.Decode(&secret); err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
	}

	// Connect to the database and insert the registration
	connStr := fmt.Sprintf("postgres://%s:%s@%s?sslmode=disable", secret.Data["username"], secret.Data["password"], dbURL)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
	}

	fmt.Println("Successfully connected to the database")

	// TODO: Get the scores from the database

	defer db.Close()
	return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusOK}, nil
}

func main() {
	lambda.Start(handleRequest)
}
