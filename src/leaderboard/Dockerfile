FROM golang:1.20-alpine as builder

LABEL maintainer="Andrew Cornies <acornies@gmail.com>"

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all dependencies. Dependencies will be cached if the go.mod and go.sum files are not changed
RUN go mod download

# Copy the source from the current directory to the Working Directory inside the container
COPY . .

# Build the Go app
RUN CGO_ENABLED=0 go build -o gamify-leaderboard .

FROM alpine:3.18

WORKDIR /app

RUN apk add curl curl-doc

# Copy the Pre-built binary file from the previous stage
COPY --from=builder /app/gamify-leaderboard .

# COPY --from=builder /app/templates templates

COPY --from=builder /app/static static

RUN adduser -S -D -H -h /app gamify
USER gamify

# Expose port 8080 to the outside world
EXPOSE 3000

# Command to run the executable
CMD ["./gamify-leaderboard"]