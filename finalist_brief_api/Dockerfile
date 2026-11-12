# Build from the repository root:
#   docker build -f finalist_brief_api/Dockerfile .
# (deploy/gcp/deploy.sh does this with Cloud Build.)

# Build stage
FROM dart:3.12.2 AS build

# A minimal workspace with only the API and its shared models. pubspec.lock
# keeps the dependency versions the repository was developed with.
WORKDIR /app
COPY pubspec.lock .
COPY finalist_brief_shared finalist_brief_shared
COPY finalist_brief_api finalist_brief_api
RUN printf '%s\n' \
  'name: _' \
  'publish_to: none' \
  'environment:' \
  '  sdk: ^3.12.2' \
  'workspace:' \
  '  - finalist_brief_shared' \
  '  - finalist_brief_api' \
  > pubspec.yaml
RUN dart pub get

# Compile a self-contained native executable.
RUN dart compile exe finalist_brief_api/bin/server.dart -o /app/server

# Runtime stage: only the executable, its fixtures and the TLS roots.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
COPY finalist_brief_api/assets /app/assets
WORKDIR /app

# Cloud Run sets PORT; 8080 is the default.
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/server"]
