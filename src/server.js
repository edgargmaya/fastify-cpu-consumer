import Fastify from "fastify";

const PORT = Number.parseInt(process.env.PORT ?? "3000", 10);
const MAX_LIMIT = 400_000;
const DEFAULT_LIMIT = 120_000;

const app = Fastify({ logger: true });

function isPrimeByTrialDivision(n) {
  if (n < 2) return false;
  if (n % 2 === 0) return n === 2;
  const root = Math.floor(Math.sqrt(n));
  for (let d = 3; d <= root; d += 2) {
    if (n % d === 0) return false;
  }
  return true;
}

function countPrimes(limit) {
  const scratch = Buffer.allocUnsafe(16 * 1024 * 1024);
  scratch.fill(0x5a);

  let primes = 0;
  for (let n = 2; n <= limit; n++) {
    if (isPrimeByTrialDivision(n)) primes += 1;
  }

  return { primes, bytes: scratch.byteLength };
}

app.get("/health", async () => ({ status: "ok" }));

app.get("/compute", async (request, reply) => {
  const raw = request.query.limit;
  const parsed = raw === undefined ? DEFAULT_LIMIT : Number.parseInt(raw, 10);

  if (!Number.isInteger(parsed) || parsed < 2) {
    return reply.code(400).send({
      error: "limit must be an integer >= 2",
    });
  }

  const limit = Math.min(parsed, MAX_LIMIT);
  const started = process.hrtime.bigint();
  const { primes, bytes } = countPrimes(limit);
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1_000_000;

  return {
    limit,
    primes,
    heapBytes: bytes,
    elapsedMs: Math.round(elapsedMs * 100) / 100,
  };
});

await app.listen({ port: PORT, host: "0.0.0.0" });
