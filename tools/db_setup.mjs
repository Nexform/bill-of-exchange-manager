// Off-stack database for the transpiled unit tests: an in-memory SQLite with the
// tables of src/ (schemas) and their test data (insert).

import { SQLiteDatabaseClient } from "@abaplint/database-sqlite";

export async function setupDatabase(abap, schemas, insert) {
  const client = new SQLiteDatabaseClient();
  abap.context.databaseConnections["DEFAULT"] = client;
  await client.connect();
  await client.execute(schemas.sqlite);
  await client.execute(insert);
}
