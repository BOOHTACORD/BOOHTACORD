FROM golang:1.26.4-alpine AS build
WORKDIR /src
ARG BOOHTACORD_CACHE_SCOPE=local-v1
COPY go.mod go.sum ./
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/bootstrap-admin ./cmd/bootstrap_admin
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/recover-admin ./cmd/recover_admin
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/recover-last-admin-access ./cmd/recover_last_admin_access
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/maintenance-admission ./cmd/maintenance_admission
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-stale-staging ./cmd/cleanup_stale_staging
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-unattached-attachments ./cmd/cleanup_unattached_attachments
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-hidden-attachments ./cmd/cleanup_hidden_attachments

RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/installation ./cmd/installation

RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/support-contact ./cmd/support_contact

RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gomod,target=/go/pkg/mod,sharing=locked --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-gobuild,target=/root/.cache/go-build,sharing=locked CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/notification-control ./cmd/notification-control

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
COPY --from=build /out/notification-control /notification-control
COPY --from=build /out/support-contact /support-contact
COPY --from=build /out/installation /installation
COPY --from=build /out/migrate /migrate
COPY --from=build /out/bootstrap-admin /bootstrap-admin
COPY --from=build /out/recover-admin /recover-admin
COPY --from=build /out/recover-last-admin-access /recover-last-admin-access
COPY --from=build /out/maintenance-admission /maintenance-admission
COPY --from=build /out/cleanup-stale-staging /cleanup-stale-staging
COPY --from=build /out/cleanup-unattached-attachments /cleanup-unattached-attachments
COPY --from=build /out/cleanup-hidden-attachments /cleanup-hidden-attachments
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
