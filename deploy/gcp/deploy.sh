#!/usr/bin/env bash
# Deploys Finalist Brief to Google Cloud.
#   api    REST API       -> Cloud Run (image built by Cloud Build), data in Firestore
#   rules  Firestore security rules (deny all client access)
#   web    Flutter web    -> Firebase Hosting (https://finalists.sound.fan)
#   all    all three, API first (default)
#
# Usage: deploy/gcp/deploy.sh [api|rules|web|all]
#
# Reads API keys from the gitignored .env (see .env.example). They reach Cloud
# Run as plain environment variables, not Secret Manager. Sign in first with
# `gcloud auth login` and `firebase login`.
set -euo pipefail

cd "$(dirname "$0")/../.."

PROJECT=finalists-sound-fan
REGION=us-central1
SERVICE=finalist-brief-api
IMAGE_REPO="$REGION-docker.pkg.dev/$PROJECT/finalist-brief/api"
WEB_ORIGIN=https://finalists.sound.fan

# Cloud Run's deterministic URL; the web app is built against it.
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
API_URL="https://$SERVICE-$PROJECT_NUMBER.$REGION.run.app/"

export PATH="$HOME/flutter/bin:$PATH"

# Reads KEY from .env, dropping any surrounding quotes. Fails if it is unset.
env_value() {
  local value
  value=$(grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | sed -E "s/^[\"']|[\"']$//g") || true
  if [ -z "$value" ]; then
    echo "Missing $1 in .env (see .env.example)" >&2
    exit 1
  fi
  printf '%s' "$value"
}

deploy_api() {
  local image envfile
  image="$IMAGE_REPO:$(date +%Y%m%d-%H%M%S)"

  gcloud builds submit --project "$PROJECT" \
    --config deploy/gcp/cloudbuild.yaml \
    --substitutions "_IMAGE=$image" .

  # --env-vars-file keeps secrets off the command line and replaces the
  # service's variables with exactly this set.
  envfile=$(mktemp)
  trap 'rm -f "$envfile"' EXIT
  chmod 600 "$envfile"
  {
    echo "GOOGLE_CLOUD_PROJECT: \"$PROJECT\""
    echo "PUBLIC_WEB_ORIGIN: \"$WEB_ORIGIN\""
    for key in GEMINI_API_KEY TYPESAFE_API_KEY; do
      printf '%s: "%s"\n' "$key" "$(env_value "$key")"
    done
  } > "$envfile"

  gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" \
    --image "$image" \
    --port 8080 \
    --memory 512Mi --cpu 1 --cpu-boost \
    --min-instances 0 --max-instances 3 \
    --allow-unauthenticated \
    --env-vars-file "$envfile"
}

deploy_rules() {
  firebase deploy --only firestore:rules --project "$PROJECT"
}

deploy_web() {
  (
    cd finalist_brief_flutter
    flutter pub get
    flutter build web --release --dart-define="API_URL=$API_URL"
  )
  firebase deploy --only hosting --project "$PROJECT"
}

case "${1:-all}" in
  api) deploy_api ;;
  rules) deploy_rules ;;
  web) deploy_web ;;
  all) deploy_api; deploy_rules; deploy_web ;;
  *) echo "Usage: $0 [api|rules|web|all]" >&2; exit 2 ;;
esac
