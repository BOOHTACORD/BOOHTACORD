FROM golang:1.26.4-alpine AS build
WORKDIR /src
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/cmd ./cmd
COPY backend/internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -o /out/gateway ./cmd/telemetry_gateway && CGO_ENABLED=0 go build -trimpath -o /out/registry ./cmd/telemetry_registry
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/gateway /gateway
COPY --from=build /out/registry /registry
USER nonroot:nonroot
ENTRYPOINT ["/gateway"]
