FROM golang:1.26.4-alpine AS build
WORKDIR /src
ENV GO111MODULE=off CGO_ENABLED=0
COPY *.go ./
RUN go test ./... && go build -trimpath -o /out/faults .
FROM scratch
COPY --from=build /out/faults /usr/local/bin/faults
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/faults"]
