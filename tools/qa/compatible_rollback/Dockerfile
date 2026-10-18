# The dedicated daemon is the only place where the fixed shipping project name
# and privileged namespace probes are allowed. No host Docker socket is mounted.
FROM docker:29.5.2-dind@sha256:392437eb2d6e54f9ae2be9c0aac2cbca95e3f5eb9854b0f0b1d664d473856633
RUN apk add --no-cache python3 bash curl coreutils util-linux git openssl
