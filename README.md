# fastify-cpu-consumer

Standalone Fastify app used to exercise the Alesia EKS cluster: AWS
Load Balancer Controller (public ALB) and KEDA CPU/memory scaling.
It is not part of the Terraform platform.

One endpoint: `GET /compute?limit=<n>` counts primes in `2..limit`
with **trial division** (CPU) and allocates a 16 MiB scratch buffer
(RAM). Default `limit` is `120000` (capped at `400000`). Liveness and
readiness use `GET /health` so a long `/compute` does not kill the pod.

Image: `edgargmaya/fastify-cpu-consumer:v1`

## Build and push

```bash
docker build -t edgargmaya/fastify-cpu-consumer:v1 .
docker push edgargmaya/fastify-cpu-consumer:v1
```

## Deploy

```bash
kubectl apply -f k8s/
kubectl -n fastify-test get ingress,hpa,pods
```

Wait until the Ingress `ADDRESS` is an `*.elb.amazonaws.com` hostname.

## Stress

```bash
chmod +x stress.sh
./stress.sh 8
./stress.sh 15 http://<alb-hostname>
```

`LIMIT=200000 ./stress.sh 10` raises the work per request.

Watch:

```bash
kubectl -n fastify-test get hpa,deploy,pods -w
```

## Tear down

```bash
kubectl delete ns fastify-test
```
