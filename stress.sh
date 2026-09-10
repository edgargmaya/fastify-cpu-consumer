#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./stress.sh <requests> [base_url]

  requests  Number of concurrent HTTP calls to /compute (required).
  base_url  Optional. Ingress/ALB URL. If omitted, the script reads it from:
            kubectl -n fastify-test get ingress fastify-cpu-consumer

Examples:
  ./stress.sh 8
  ./stress.sh 15 http://k8s-fastifyt-fastifyc-xxxx.us-east-1.elb.amazonaws.com

Optional env:
  LIMIT   Upper bound of the primality loop per request (default 120000, app max 400000).
EOF
  exit 1
}

[[ $# -ge 1 ]] || usage
[[ "$1" =~ ^[1-9][0-9]*$ ]] || usage

REQUESTS="$1"
LIMIT="${LIMIT:-120000}"

if [[ $# -ge 2 ]]; then
  BASE_URL="${2%/}"
else
  command -v kubectl >/dev/null || {
    echo "kubectl not found; pass the base URL as the second argument." >&2
    exit 1
  }
  HOST="$(kubectl -n fastify-test get ingress fastify-cpu-consumer \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -z "$HOST" ]]; then
    echo "Ingress has no ADDRESS yet. Wait for the ALB or pass base_url." >&2
    exit 1
  fi
  BASE_URL="http://${HOST}"
fi

URL="${BASE_URL}/compute?limit=${LIMIT}"
echo "Sending ${REQUESTS} concurrent requests to ${URL}"

ok=0
fail=0
pids=()
for _ in $(seq 1 "$REQUESTS"); do
  curl -fsS -o /dev/null --max-time 120 "$URL" &
  pids+=("$!")
done

for pid in "${pids[@]}"; do
  if wait "$pid"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done

echo "done ok=${ok} fail=${fail}"
echo "Watch scale with: kubectl -n fastify-test get hpa,pods -w"
