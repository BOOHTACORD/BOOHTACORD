# Egress v1.14.1 with a receipt timestamp that retains Go monotonic time.
FROM python:3.12.15-slim@sha256:a0f57064cbdcd6285fa45f51237ab0b35ea8ebaed06a1f5973e89e19dfb86704 AS source
ADD --checksum=sha256:999df9fc52ed6f929d8a003bba354699dc6b69e6a376bd32a6b51383340664a0 https://codeload.github.com/livekit/egress/tar.gz/805884c3e65e1583277f93ae616d3bf0dfd35564 /tmp/egress.tar.gz
RUN mkdir /workspace && tar -xzf /tmp/egress.tar.gz -C /workspace --strip-components=1
COPY tools/build/egress_clock_fix/patch.py /tmp/patch.py
RUN python /tmp/patch.py /workspace/pkg/pipeline/source/sdk/appwriter.go

FROM golang:1.26.5@sha256:705e964a93a2fd2e75c7d59bb7d781b57e30f12293ffde5175c69229e18fb678 AS toolchain
FROM livekit/egress-templates:sha-f88afa8@sha256:6945af05ed55044bd99e61564526329c4d86d1eae3e99b82ce88948fb46c7d1b AS template
FROM livekit/gstreamer:1.24.12-dev@sha256:208d54ac3a93953c81654a00a8f8e6a162dfb35679a6ceb41017dfb581a49166 AS builder
COPY --from=toolchain /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}" GOTOOLCHAIN=local
WORKDIR /workspace
COPY --from=source /workspace/go.mod /workspace/go.sum ./
RUN go mod download
COPY --from=source /workspace/cmd/ cmd/
COPY --from=source /workspace/pkg/ pkg/
COPY --from=source /workspace/version/ version/
COPY --from=template /workspace/build/ cmd/server/templates/
ARG TARGETARCH
RUN CGO_ENABLED=1 GOOS=linux GOARCH=${TARGETARCH} go build -o /tmp/egress ./cmd/server

FROM livekit/egress@sha256:bf2b648b947349c3e9ff7aa8c718f00378d5c06af7624652a3653318e00333ce
USER root
COPY --from=builder /tmp/egress /bin/egress
USER egress
