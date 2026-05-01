const admin = require("firebase-admin");
const {logger} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const DEVICE_ROOT = "device";
const APP_ROOT = "iot_power_guard";
const TOKEN_ROOT = `${APP_ROOT}/notification_tokens`;
const ALERT_ROOT = `${APP_ROOT}/offline_alerts`;
const OFFLINE_THRESHOLD_MS = 20 * 1000;
const EPOCH_MS_THRESHOLD = 1000000000000;
const EPOCH_SECONDS_THRESHOLD = 1000000000;
const UINT32_MOD = 4294967296;
const MAX_REASONABLE_LAST_SEEN_DRIFT_MS = 31536000000;

exports.notifyOfflineDevices = onSchedule("every 1 minutes", async () => {
  const db = admin.database();
  const [deviceSnapshot, tokenSnapshot, alertSnapshot] = await Promise.all([
    db.ref(DEVICE_ROOT).get(),
    db.ref(TOKEN_ROOT).get(),
    db.ref(ALERT_ROOT).get(),
  ]);

  const deviceMap = asMap(deviceSnapshot.val());
  const tokenMap = asMap(tokenSnapshot.val());
  const alertMap = asMap(alertSnapshot.val());
  const tokens = extractTokens(tokenMap);
  const now = Date.now();
  const updates = {};

  for (const [deviceId, rawDevice] of Object.entries(deviceMap)) {
    const device = asMap(rawDevice);
    const offlineState = resolveOfflineState(device, now);

    if (!offlineState.isOffline) {
      updates[deviceId] = null;
      continue;
    }

    if (offlineState.offlineStartedAt === null ||
        now - offlineState.offlineStartedAt < OFFLINE_THRESHOLD_MS) {
      continue;
    }

    const previousAlert = asMap(alertMap[deviceId]);
    const notifiedFor = `${offlineState.source}:${offlineState.offlineStartedAt}`;
    if (previousAlert.notified_for === notifiedFor) {
      continue;
    }

    const deviceName = resolveDeviceName(deviceId, device);
    if (tokens.length > 0) {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Perangkat Offline",
          body: `${deviceName} terdeteksi offline.`,
        },
        data: {
          type: "device_offline",
          deviceId,
          deviceName,
          status: "offline",
          source: offlineState.source,
          reason: offlineState.reason,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "device_offline_channel",
          },
        },
      });

      logger.info("Offline notification sent", {
        deviceId,
        deviceName,
        source: offlineState.source,
        reason: offlineState.reason,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    } else {
      logger.warn("FCM token belum tersedia. Alert state tetap disimpan.", {
        deviceId,
        deviceName,
        source: offlineState.source,
      });
    }

    updates[deviceId] = {
      device_name: deviceName,
      notified_at: admin.database.ServerValue.TIMESTAMP,
      notified_for: notifiedFor,
      offline_started_at: offlineState.offlineStartedAt,
      status: "offline",
      source: offlineState.source,
      reason: offlineState.reason,
    };
  }

  if (Object.keys(updates).length > 0) {
    await db.ref(ALERT_ROOT).update(updates);
  }
});

function asMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value;
}

function extractTokens(tokenMap) {
  const values = [];
  for (const rawValue of Object.values(tokenMap)) {
    if (typeof rawValue === "string" && rawValue.trim()) {
      values.push(rawValue.trim());
      continue;
    }

    const value = asMap(rawValue);
    if (typeof value.token === "string" && value.token.trim()) {
      values.push(value.token.trim());
    }
  }
  return [...new Set(values)];
}

function normalizeConnectionStatus(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === "offline" || normalized === "disconnected") {
    return "offline";
  }
  if (normalized === "online" || normalized === "connected") {
    return "online";
  }
  return null;
}

function resolveOfflineState(device, now) {
  const connection = asMap(device.connection);
  const monitoring = asMap(device.monitoring);
  const connectionStatus = normalizeConnectionStatus(
    connection.status ??
      connection.mode ??
      device.connection_status ??
      device.status_koneksi
  );
  const connectionChangedAt = parseTimestamp(
    connection.last_changed ??
      connection.changed_at ??
      connection.updated_at ??
      device.connection_last_changed
  );
  const monitoringTimestamp = parseTimestamp(monitoring.timestamp);
  const lastSeenAt = parseLastSeen(
    device.last_seen ??
      connection.last_seen ??
      monitoring.last_seen ??
      monitoring.timestamp,
    monitoringTimestamp ?? now
  );

  if (connectionStatus === "offline") {
    return {
      isOffline: true,
      offlineStartedAt: connectionChangedAt ?? lastSeenAt,
      source: connectionChangedAt ? "connection_status" : "last_seen_fallback",
      reason: connectionChangedAt
        ? "explicit_offline_status"
        : "explicit_offline_without_last_changed",
    };
  }

  if (lastSeenAt !== null && now - lastSeenAt >= OFFLINE_THRESHOLD_MS) {
    return {
      isOffline: true,
      offlineStartedAt: lastSeenAt,
      source: "last_seen",
      reason:
        connectionStatus === "online"
          ? "heartbeat_stale_while_status_online"
          : "heartbeat_stale",
    };
  }

  return {
    isOffline: false,
    offlineStartedAt: null,
    source: connectionStatus === "online" ? "connection_status" : "unknown",
    reason: connectionStatus === "online" ? "explicit_online_status" : "active",
  };
}

function parseTimestamp(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === "string") {
    const numeric = Number(value);
    if (!Number.isNaN(numeric)) {
      value = numeric;
    } else {
      const parsedDate = Date.parse(value);
      return Number.isNaN(parsedDate) ? null : parsedDate;
    }
  }

  if (typeof value !== "number" || Number.isNaN(value)) {
    return null;
  }

  if (value >= EPOCH_MS_THRESHOLD) {
    return Math.trunc(value);
  }
  if (value >= EPOCH_SECONDS_THRESHOLD) {
    return Math.trunc(value * 1000);
  }
  return null;
}

function parseLastSeen(value, referenceTime) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === "string") {
    const numeric = Number(value);
    if (!Number.isNaN(numeric)) {
      value = numeric;
    } else {
      const parsedDate = Date.parse(value);
      return Number.isNaN(parsedDate) ? null : parsedDate;
    }
  }

  if (typeof value !== "number" || Number.isNaN(value)) {
    return null;
  }

  const numeric = Math.trunc(value);
  const candidates = [];

  if (Math.abs(numeric) >= EPOCH_SECONDS_THRESHOLD) {
    candidates.push(numeric * 1000);
  }

  const wrappedUnsigned = numeric >>> 0;
  const wrappedMs = unwrap32BitMilliseconds(wrappedUnsigned, referenceTime);
  candidates.push(wrappedMs);

  let best = null;
  let bestDiff = MAX_REASONABLE_LAST_SEEN_DRIFT_MS + 1;
  for (const candidate of candidates) {
    const diff = Math.abs(candidate - referenceTime);
    if (diff < bestDiff) {
      best = candidate;
      bestDiff = diff;
    }
  }

  if (bestDiff > MAX_REASONABLE_LAST_SEEN_DRIFT_MS) {
    return null;
  }

  return best;
}

function unwrap32BitMilliseconds(wrappedMilliseconds, referenceMilliseconds) {
  const offset = referenceMilliseconds - wrappedMilliseconds;
  let cycles = Math.floor(offset / UINT32_MOD);

  const lowerCandidate = wrappedMilliseconds + (cycles * UINT32_MOD);
  const upperCandidate = wrappedMilliseconds + ((cycles + 1) * UINT32_MOD);

  if (Math.abs(upperCandidate - referenceMilliseconds) <
      Math.abs(lowerCandidate - referenceMilliseconds)) {
    cycles += 1;
  }

  return wrappedMilliseconds + (cycles * UINT32_MOD);
}

function resolveDeviceName(deviceId, device) {
  const profile = asMap(device.profile);
  if (typeof profile.name === "string" && profile.name.trim()) {
    return profile.name.trim();
  }
  return `Device ${deviceId}`;
}
