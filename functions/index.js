const admin = require("firebase-admin");
const {logger} = require("firebase-functions");
const {onValueWritten} = require("firebase-functions/v2/database");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const DEVICE_ROOT = "device";
const APP_ROOT = "iot_power_guard";
const DATABASE_INSTANCE = "home-electrical-tracking-54460-default-rtdb";
const DATABASE_REGION = "asia-southeast1";
const TOKEN_ROOT = `${APP_ROOT}/notification_tokens`;
const ALERT_ROOT = `${APP_ROOT}/offline_alerts`;
const CLASSIFICATION_ALERT_ROOT = `${APP_ROOT}/classification_alerts`;
const DEVICE_CLASSIFICATION_ROOT = `${DEVICE_ROOT}/{deviceId}/knn/classification`;
const DEVICE_MONITORING_ROOT = `${DEVICE_ROOT}/{deviceId}/monitoring`;
const PREDICTION_ENDPOINT = "https://hetrack-knn.onrender.com/predict";
const OFFLINE_THRESHOLD_MS = 20 * 1000;
const EPOCH_MS_THRESHOLD = 1000000000000;
const EPOCH_SECONDS_THRESHOLD = 1000000000;
const UINT32_MOD = 4294967296;
const MAX_REASONABLE_LAST_SEEN_DRIFT_MS = 31536000000;
const LOW_CONSUMPTION_THRESHOLD_WATTS = 150;
const MEDIUM_CONSUMPTION_THRESHOLD_WATTS = 400;
const NO_LOAD_CURRENT_THRESHOLD_AMPS = 0.04;
const NO_LOAD_POWER_THRESHOLD_WATTS = 1;
const DASHBOARD_ROOM_CONFIGS = [
  {
    roomId: "dapur",
    aliases: ["dapur", "kitchen", "device1", "esp32_1"],
  },
  {
    roomId: "kamar",
    aliases: ["kamar", "bedroom", "bed", "device2", "esp32_2"],
  },
  {
    roomId: "ruang_tengah",
    aliases: [
      "ruang tengah",
      "ruang_tengah",
      "living room",
      "living",
      "device3",
      "esp32_3",
    ],
  },
];

exports.classifyDeviceMonitoring = onValueWritten(
  {
    ref: DEVICE_MONITORING_ROOT,
    instance: DATABASE_INSTANCE,
    region: DATABASE_REGION,
    timeoutSeconds: 60,
  },
  async (event) => {
    const deviceId = event.params.deviceId;
    const monitoring = asMap(event.data.after.val());
    if (Object.keys(monitoring).length === 0) {
      return;
    }

    const deviceRef = admin.database().ref(`${DEVICE_ROOT}/${deviceId}`);
    const deviceSnapshot = await deviceRef.get();
    const device = asMap(deviceSnapshot.val());
    const roomId = resolveRoomId(deviceId, device);
    const features = monitoringFeatures(monitoring);

    let prediction = null;
    if (isNoLoad(features)) {
      prediction = {
        classification: "Normal",
        probabilities: {},
        source: "no_load_override",
      };
    } else {
      try {
        prediction = await requestPrediction(roomId, features);
      } catch (error) {
        logger.error("Gagal meminta prediksi KNN dari Render.", {
          deviceId,
          roomId,
          error: error.message,
        });
        prediction = {
          classification: classifyByPower(features.power),
          probabilities: {},
          source: "power_threshold_fallback",
        };
      }
    }

    const currentClassification = canonicalClassification(
      asMap(device.knn).classification
    );
    const nextClassification = canonicalClassification(
      prediction.classification
    );
    if (!nextClassification || currentClassification === nextClassification) {
      return;
    }

    await deviceRef.child("knn").update({
      classification: classificationLabel(nextClassification),
      probabilities: prediction.probabilities,
      room: roomId,
      source: prediction.source,
      updated_at: admin.database.ServerValue.TIMESTAMP,
    });

    logger.info("Device classification updated", {
      deviceId,
      roomId,
      classification: nextClassification,
      source: prediction.source,
    });
  }
);

exports.notifyClassificationChange = onValueWritten(
  {
    ref: DEVICE_CLASSIFICATION_ROOT,
    instance: DATABASE_INSTANCE,
    region: DATABASE_REGION,
  },
  async (event) => {
    const deviceId = event.params.deviceId;
    const before = canonicalClassification(event.data.before.val());
    const after = canonicalClassification(event.data.after.val());

    if (before === after) {
      return;
    }

    const alertRef = admin.database().ref(
      `${CLASSIFICATION_ALERT_ROOT}/${deviceId}`
    );

    if (!isAlertClassification(after)) {
      await alertRef.remove();
      return;
    }

    const [tokenSnapshot, alertSnapshot, deviceSnapshot] = await Promise.all([
      admin.database().ref(TOKEN_ROOT).get(),
      alertRef.get(),
      admin.database().ref(`${DEVICE_ROOT}/${deviceId}`).get(),
    ]);
    const device = asMap(deviceSnapshot.val());
    const monitoring = monitoringFeatures(asMap(device.monitoring));
    if (isNoLoad(monitoring)) {
      await Promise.all([
        alertRef.remove(),
        admin.database().ref(`${DEVICE_ROOT}/${deviceId}/knn`).update({
          classification: "Normal",
          probabilities: {},
          source: "no_load_notification_guard",
          updated_at: admin.database.ServerValue.TIMESTAMP,
        }),
      ]);
      logger.info("Classification notification suppressed for no-load state", {
        deviceId,
        classification: after,
        power: monitoring.power,
        current: monitoring.current,
      });
      return;
    }

    const previousAlert = asMap(alertSnapshot.val());
    if (previousAlert.notified_for === after) {
      return;
    }

    const tokens = extractTokens(asMap(tokenSnapshot.val()));
    if (tokens.length === 0) {
      logger.warn("FCM token belum tersedia untuk notifikasi klasifikasi.", {
        deviceId,
        classification: after,
      });
      return;
    }

    const deviceName = resolveDeviceName(deviceId, device);
    const alert = classificationAlert(after, deviceName);
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: alert.title,
        body: alert.body,
      },
      data: {
        type: "classification_alert",
        deviceId,
        deviceName,
        classification: after,
        title: alert.title,
        body: alert.body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: alert.channelId,
        },
      },
    });

    logger.info("Classification notification sent", {
      deviceId,
      deviceName,
      classification: after,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    await alertRef.set({
      device_name: deviceName,
      classification: after,
      notified_at: admin.database.ServerValue.TIMESTAMP,
      notified_for: after,
    });
  }
);

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

function normalizeClassification(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return value.toString().trim().toLowerCase();
}

function canonicalClassification(value) {
  const normalized = normalizeClassification(value);
  if (normalized === "high" || normalized === "tinggi" ||
      normalized === "boros") {
    return "boros";
  }
  if (normalized === "medium" || normalized === "sedang" ||
      normalized === "waspada") {
    return "waspada";
  }
  if (normalized === "low" || normalized === "normal" ||
      normalized === "aman") {
    return "normal";
  }
  return normalized;
}

function isAlertClassification(value) {
  const classification = canonicalClassification(value);
  return classification === "waspada" || classification === "boros";
}

function classificationLabel(classification) {
  const canonical = canonicalClassification(classification);
  if (canonical === "boros") {
    return "Boros";
  }
  if (canonical === "waspada") {
    return "Waspada";
  }
  return "Normal";
}

function classifyByPower(power) {
  if (power >= MEDIUM_CONSUMPTION_THRESHOLD_WATTS) {
    return "Boros";
  }
  if (power >= LOW_CONSUMPTION_THRESHOLD_WATTS) {
    return "Waspada";
  }
  return "Normal";
}

function isNoLoad(features) {
  return Math.abs(features.current) <= NO_LOAD_CURRENT_THRESHOLD_AMPS &&
    Math.abs(features.power) <= NO_LOAD_POWER_THRESHOLD_WATTS;
}

function monitoringFeatures(monitoring) {
  return {
    voltage: numberValue(monitoring.voltage),
    current: numberValue(monitoring.current),
    power: numberValue(monitoring.power),
  };
}

function numberValue(value) {
  if (typeof value === "number" && !Number.isNaN(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

async function requestPrediction(roomId, features) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(PREDICTION_ENDPOINT, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        room: roomId,
        features: [features.voltage, features.current],
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`Render returned HTTP ${response.status}`);
    }

    const decoded = await response.json();
    return {
      classification: decoded.prediction ?? "Normal",
      probabilities: asMap(decoded.probabilities),
      source: "render_knn",
    };
  } finally {
    clearTimeout(timeout);
  }
}

function resolveRoomId(deviceId, device) {
  const profile = asMap(device.profile);
  const candidates = [
    deviceId,
    profile.name,
    profile.room,
    profile.icon,
    device.name,
    device.room,
  ]
    .filter((value) => typeof value === "string" && value.trim())
    .map((value) => value.trim().toLowerCase());

  for (const config of DASHBOARD_ROOM_CONFIGS) {
    if (candidates.some((candidate) => {
      return config.aliases.some((alias) => candidate.includes(alias));
    })) {
      return config.roomId;
    }
  }
  return deviceId;
}

function classificationAlert(classification, deviceName) {
  if (classification === "boros") {
    return {
      title: "Peringatan Konsumsi Tinggi",
      body:
        `${deviceName} berada pada level BOROS. ` +
        "Silahkan periksa beban listrik Anda.",
      channelId: "boros_channel",
    };
  }

  return {
    title: "Peringatan Konsumsi",
    body:
      `${deviceName} berada pada level WASPADA. ` +
      "Pantau konsumsi listrik Anda.",
    channelId: "waspada_channel",
  };
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
