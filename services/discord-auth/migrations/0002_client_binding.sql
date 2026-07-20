ALTER TABLE auth_requests ADD COLUMN client_hash TEXT;
ALTER TABLE sessions ADD COLUMN client_hash TEXT;

CREATE INDEX IF NOT EXISTS auth_requests_client
    ON auth_requests (request_hash, client_hash);

CREATE INDEX IF NOT EXISTS sessions_client
    ON sessions (token_hash, client_hash);
