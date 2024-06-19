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
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/hashicorp/vault/api"

	_ "github.com/lib/pq"
)

func handleRequest(ctx context.Context, request events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {

	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

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
	connStr := fmt.Sprintf("postgres://%s:%s@%s", secret.Data["username"], secret.Data["password"], dbURL)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
	}

	fmt.Println("Successfully connected to the database")

	// Get the scores from the database
	rows, err := db.QueryContext(ctx, "SELECT team_id, SUM(score_value) AS total FROM scores GROUP BY team_id ORDER BY total DESC")
	if err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
	}
	defer rows.Close()

	// Build a map of teamID -> score
	scores := make(map[string]int)
	for rows.Next() {
		var teamID string
		var score int
		if err := rows.Scan(&teamID, &score); err != nil {
			return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
		}
		scores[teamID] = score
	}

	// JSON encode the scores
	scoresJSON, err := json.Marshal(scores)
	if err != nil {
		return events.LambdaFunctionURLResponse{Body: request.Body, StatusCode: http.StatusInternalServerError}, err
	}

	defer db.Close()

	return events.LambdaFunctionURLResponse{
		Body:       string(scoresJSON),
		Headers:    map[string]string{"Content-Type": "application/json"},
		StatusCode: http.StatusOK}, nil
}

func main() {
	lambda.Start(handleRequest)
}
