export async function createAuthRequest(db, record) {
  await db.prepare(
    `INSERT INTO auth_requests
      (request_hash, state_hash, client_hash, status, created_at, expires_at)
     VALUES (?1, ?2, ?3, 'pending', ?4, ?5)`,
  ).bind(record.requestHash, record.stateHash, record.clientHash, record.createdAt, record.expiresAt).run();
}

export async function reserveCallback(db, stateHash, now) {
  return db.prepare(
    `UPDATE auth_requests
       SET status = 'processing'
     WHERE state_hash = ?1 AND status = 'pending' AND expires_at > ?2
     RETURNING request_hash`,
  ).bind(stateHash, now).first();
}

export async function completeAuthRequest(db, stateHash, result, now) {
  await db.prepare(
    `UPDATE auth_requests SET
       status = ?2,
       discord_user_id = ?3,
       display_name = ?4,
       role_ids_json = ?5,
       denied_reason = ?6,
       completed_at = ?7
     WHERE state_hash = ?1 AND status = 'processing'`,
  ).bind(
    stateHash,
    result.status,
    result.discordUserId || null,
    result.displayName || null,
    JSON.stringify(result.roleIds || []),
    result.deniedReason || null,
    now,
  ).run();
}

export async function readAuthRequest(db, requestHash, clientHash, now) {
  return db.prepare(
    `SELECT status, denied_reason, discord_user_id, display_name, role_ids_json
       FROM auth_requests
      WHERE request_hash = ?1 AND client_hash = ?2 AND expires_at > ?3`,
  ).bind(requestHash, clientHash, now).first();
}

export async function consumeApprovedRequest(db, requestHash, clientHash, now) {
  return db.prepare(
    `DELETE FROM auth_requests
      WHERE request_hash = ?1 AND client_hash = ?2 AND status = 'approved' AND expires_at > ?3
      RETURNING discord_user_id, display_name, role_ids_json`,
  ).bind(requestHash, clientHash, now).first();
}

export async function createSession(db, record) {
  await db.prepare(
    `INSERT INTO sessions
      (token_hash, client_hash, discord_user_id, display_name, role_ids_json, created_at, expires_at, last_seen_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?6)`,
  ).bind(
    record.tokenHash,
    record.clientHash,
    record.discordUserId,
    record.displayName,
    record.roleIdsJson,
    record.createdAt,
    record.expiresAt,
  ).run();
}

export async function readSession(db, tokenHash, clientHash, now) {
  return db.prepare(
    `SELECT discord_user_id, display_name, expires_at
       FROM sessions
      WHERE token_hash = ?1 AND client_hash = ?2 AND expires_at > ?3`,
  ).bind(tokenHash, clientHash, now).first();
}

export async function deleteSession(db, tokenHash) {
  await db.prepare("DELETE FROM sessions WHERE token_hash = ?1").bind(tokenHash).run();
}

export async function cleanupExpired(db, now) {
  await db.batch([
    db.prepare("DELETE FROM auth_requests WHERE expires_at <= ?1").bind(now),
    db.prepare("DELETE FROM sessions WHERE expires_at <= ?1").bind(now),
  ]);
}
