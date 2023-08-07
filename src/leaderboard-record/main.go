package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/hashicorp/vault/api"

	_ "github.com/lib/pq"
)

// Move this struct to common package
type LeaderboardEvent struct {
	FunctionARN  string `json:"function_arn"`
	FunctionName string `json:"function_name"`
	AccountID    string `json:"account_id"`
	Points       int    `json:"points"`
}

func handler(ctx context.Context, sqsEvent events.SQSEvent) error {

	fmt.Println("Started processing event, secrets injected")

	// Check for required env vars env vars
	secretFile := os.Getenv("VAULT_SECRET_FILE_DB")
	if secretFile == "" {
		return errors.New("no VAULT_SECRET_FILE_DB environment variable, exiting")
	}

	dbURL := os.Getenv("DATABASE_ADDR")
	if dbURL == "" {
		return errors.New("no DATABASE_ADDR environment variable, exiting")
	}

	// Read the secret from the file before processing the event
	secretRaw, err := ioutil.ReadFile(secretFile)
	if err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}

	// Decode the JSON into a map[string]interface{}
	var secret api.Secret
	b := bytes.NewBuffer(secretRaw)
	dec := json.NewDecoder(b)
	dec.UseNumber()

	if err := dec.Decode(&secret); err != nil {
		return err
	}

	// Connect to the database and insert the registration
	connStr := fmt.Sprintf("postgres://%s:%s@%s?sslmode=disable", secret.Data["username"], secret.Data["password"], dbURL)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return err
	}

	fmt.Println("Successfully connected to the database")

	for _, message := range sqsEvent.Records {
		// Unmarshal the JSON into a Leaderboard struct
		var event LeaderboardEvent
		if err := json.Unmarshal([]byte(message.Body), &event); err != nil {
			return err
		}

		// save score to database
		sqlStatement := `
INSERT INTO scores (team_id, score_value, score_type, score_date)
VALUES ($1, $2, $3, $4)`
		_, err = db.Exec(sqlStatement, event.AccountID, event.Points, "registration", time.Now())
		if err != nil {
			return err
		}

		fmt.Printf("Successfully recorded leaderboard score event for account: %s\n", event.AccountID)
	}

	defer db.Close()
	return nil
}

func main() {
	lambda.Start(handler)
}
