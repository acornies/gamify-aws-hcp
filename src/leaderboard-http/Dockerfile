ARG ARCH
FROM golang:1.20 as build
WORKDIR /app
# Copy dependencies list
COPY . .
# Build with optional lambda.norpc tag
RUN CGO_ENABLED=0 go build -tags lambda.norpc -o main .
# Copy artifacts to a clean image
FROM public.ecr.aws/lambda/provided:al2-$ARCH
COPY --from=build /app/main ./main
COPY extensions/vault-lambda-extension /opt/extensions/vault-lambda-extension
ENTRYPOINT [ "./main" ]