export async function createAuthRequest(db, record) {
  await db.prepare(
    `INSERT INTO auth_requests
      (request_hash, state_hash, client_hash, resume_code_hash, status, created_at, expires_at)
     VALUES (?1, ?2, ?3, ?4, 'pending', ?5, ?6)`,
  ).bind(
    record.requestHash,
    record.stateHash,
    record.clientHash,
    record.resumeCodeHash,
    record.createdAt,
    record.expiresAt,
  ).run();
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

export async function claimApprovedRecovery(db, resumeCodeHash, clientHash, now) {
  return db.prepare(
    `UPDATE auth_requests
        SET resume_client_hash = COALESCE(resume_client_hash, ?2)
      WHERE resume_code_hash = ?1
        AND status = 'approved'
        AND expires_at > ?3
        AND (resume_client_hash IS NULL OR resume_client_hash = ?2)
      RETURNING discord_user_id, display_name, role_ids_json,
                client_hash AS original_client_hash`,
  ).bind(resumeCodeHash, clientHash, now).first();
}

export async function createSession(db, record) {
  return db.prepare(
    `INSERT OR IGNORE INTO sessions
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

export async function trustDevice(db, record, maxDevices) {
  return db.prepare(
    `INSERT INTO trusted_devices
      (discord_user_id, client_hash, device_label, first_seen_at, last_seen_at,
       last_ip_hash, last_country, last_asn, revoked_at)
     SELECT ?1, ?2, ?3, ?4, ?4, ?5, ?6, ?7, NULL
      WHERE EXISTS (
        SELECT 1 FROM trusted_devices
         WHERE discord_user_id = ?1 AND client_hash = ?2 AND revoked_at IS NULL
      ) OR (
        SELECT COUNT(*) FROM trusted_devices
         WHERE discord_user_id = ?1 AND revoked_at IS NULL
      ) < ?8
     ON CONFLICT(discord_user_id, client_hash) DO UPDATE SET
       device_label = excluded.device_label,
       last_seen_at = excluded.last_seen_at,
       last_ip_hash = excluded.last_ip_hash,
       last_country = excluded.last_country,
       last_asn = excluded.last_asn,
       revoked_at = NULL
     RETURNING discord_user_id, client_hash, device_label, first_seen_at, last_seen_at`,
  ).bind(
    record.discordUserId,
    record.clientHash,
    record.deviceLabel,
    record.now,
    record.network.ipHash,
    record.network.country,
    record.network.asn,
    maxDevices,
  ).first();
}

export async function readTrustedDevice(db, discordUserId, clientHash) {
  return db.prepare(
    `SELECT device_label, first_seen_at, last_seen_at,
            last_ip_hash AS ipHash, last_country AS country, last_asn AS asn
       FROM trusted_devices
      WHERE discord_user_id = ?1 AND client_hash = ?2 AND revoked_at IS NULL`,
  ).bind(discordUserId, clientHash).first();
}

export async function releaseRecoveredDevice(db, discordUserId, originalClientHash, newClientHash, now) {
  if (!originalClientHash || originalClientHash === newClientHash) return;
  await db.batch([
    db.prepare(
      `UPDATE trusted_devices
          SET revoked_at = ?4
        WHERE discord_user_id = ?1 AND client_hash = ?2 AND client_hash <> ?3`,
    ).bind(discordUserId, originalClientHash, newClientHash, now),
    db.prepare(
      `DELETE FROM sessions
        WHERE discord_user_id = ?1 AND client_hash = ?2 AND client_hash <> ?3`,
    ).bind(discordUserId, originalClientHash, newClientHash),
  ]);
}

export async function claimDeviceTransfer(db, discordUserId, now, cooldownSeconds) {
  return db.prepare(
    `INSERT INTO device_security (discord_user_id, last_transfer_at)
     VALUES (?1, ?2)
     ON CONFLICT(discord_user_id) DO UPDATE SET
       last_transfer_at = excluded.last_transfer_at
     WHERE device_security.last_transfer_at <= ?2 - ?3
     RETURNING last_transfer_at`,
  ).bind(discordUserId, now, cooldownSeconds).first();
}

export async function countTrustedDevices(db, discordUserId) {
  const row = await db.prepare(
    `SELECT COUNT(*) AS count
       FROM trusted_devices
      WHERE discord_user_id = ?1 AND revoked_at IS NULL`,
  ).bind(discordUserId).first();
  return Number(row?.count || 0);
}

export async function deleteSession(db, tokenHash) {
  await db.prepare("DELETE FROM sessions WHERE token_hash = ?1").bind(tokenHash).run();
}

export async function cleanupExpired(db, now) {
  await db.batch([
    db.prepare("DELETE FROM auth_requests WHERE expires_at <= ?1").bind(now),
    db.prepare("DELETE FROM sessions WHERE expires_at <= ?1").bind(now),
    db.prepare(
      `DELETE FROM trusted_devices
        WHERE revoked_at IS NOT NULL AND revoked_at <= ?1`,
    ).bind(now - 90 * 24 * 60 * 60),
  ]);
}
