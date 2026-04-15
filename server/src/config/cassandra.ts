import { Client, type ClientOptions } from "cassandra-driver";
import chalk from "chalk";

// Reads Cassandra env vars from process.env directly so that this module
// stays independent of the strict Zod schema in env.ts (which only validates
// SQL Server vars).  dotenv is already loaded by env.ts before this module
// is ever imported in a seed-script context.

function getContactPoints(): string[] {
  return (process.env["CASSANDRA_CONTACT_POINTS"] ?? "127.0.0.1")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function buildClientOptions(): ClientOptions {
  const options: ClientOptions = {
    contactPoints: getContactPoints(),
    localDataCenter: process.env["CASSANDRA_LOCAL_DATACENTER"] ?? "datacenter1",
    keyspace: process.env["CASSANDRA_KEYSPACE"] ?? "mentoriadbms",
  };

  const username = process.env["CASSANDRA_USERNAME"];
  const password = process.env["CASSANDRA_PASSWORD"];
  if (username && password) {
    options.credentials = { username, password };
  }

  return options;
}

let _client: Client | null = null;

/**
 * Returns (and lazily creates) the shared Cassandra client.
 * Throws if the connection cannot be established.
 */
export async function getCassandraClient(): Promise<Client> {
  if (_client) return _client;

  const client = new Client(buildClientOptions());

  try {
    await client.connect();
    console.log(chalk.green("Connected to Cassandra successfully"));
    _client = client;
    return client;
  } catch (err) {
    console.error(chalk.red("Cassandra connection failed:"), err);
    throw err;
  }
}

/**
 * Gracefully shuts down the shared Cassandra client.
 * Safe to call even if no connection was made.
 */
export async function closeCassandraClient(): Promise<void> {
  if (_client) {
    await _client.shutdown();
    _client = null;
  }
}
