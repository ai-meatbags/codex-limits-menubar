const DISPLAY_NAME_KEYS = ['displayName', 'name', 'email'];
const AUTH_MODE_KEYS = ['authMode', 'auth_mode'];

export function createErrorSnapshot(errorMessage) {
  return {
    ok: false,
    title: '—',
    subtitle: 'Codex limits unavailable',
    errorMessage,
    accountLabel: 'Open logs to inspect local Codex CLI state',
    buckets: [],
    updatedAt: new Date().toISOString()
  };
}

export function createMenubarSnapshot({ accountPayload, rateLimitsPayload }) {
  const buckets = normalizeBuckets(rateLimitsPayload);
  if (!buckets.length) {
    return createErrorSnapshot('App server returned no rate limit buckets');
  }

  const account = normalizeAccount(accountPayload);

  return {
    ok: true,
    title: formatTitle(buckets),
    subtitle: formatSubtitle(buckets),
    accountLabel: formatAccountLabel(account),
    buckets: buckets.map((bucket) => ({
      id: bucket.id,
      windowLabel: bucket.windowLabel,
      remainingPercent: bucket.remainingPercent,
      resetLabel: formatReset(bucket.resetsAt),
      hasCredits: bucket.hasCredits,
      title: `${bucket.windowLabel} — ${bucket.remainingPercent}% remaining`,
      subtitle: formatBucketSubtitle(bucket)
    })),
    updatedAt: new Date().toISOString()
  };
}

function normalizeAccount(payload) {
  const source = payload?.account ?? payload ?? {};

  return {
    displayName: firstDefined(source, DISPLAY_NAME_KEYS) ?? 'ChatGPT account',
    authMode: firstDefined(source, AUTH_MODE_KEYS) ?? 'unknown'
  };
}

function normalizeBuckets(payload) {
  const source = payload ?? {};
  const buckets = arrayFromBuckets(source);

  return buckets
    .map((bucket, index) => normalizeBucket(bucket, index))
    .filter(Boolean)
    .sort((left, right) => {
      if (left.windowDurationMins !== right.windowDurationMins) {
        return left.windowDurationMins - right.windowDurationMins;
      }

      return right.usedPercent - left.usedPercent;
    });
}

function arrayFromBuckets(source) {
  const rateLimits = source.rateLimits ?? source.rate_limits;

  if (Array.isArray(rateLimits)) {
    return rateLimits;
  }

  if (rateLimits && typeof rateLimits === 'object') {
    return Object.entries(rateLimits)
      .filter(([, bucket]) => isBucketCandidate(bucket))
      .map(([limitId, bucket]) => ({ limitId, ...bucket }));
  }

  const bucketsById = source.rateLimitsByLimitId ?? source.rate_limits_by_limit_id;
  if (bucketsById && typeof bucketsById === 'object') {
    return Object.entries(bucketsById).map(([limitId, bucket]) => ({ limitId, ...bucket }));
  }

  if (source.usedPercent !== undefined || source.used_percent !== undefined) {
    return [source];
  }

  return [];
}

function normalizeBucket(bucket, index) {
  const usedPercent = numberOrNull(bucket.usedPercent ?? bucket.used_percent);
  const windowDurationMins = numberOrNull(
    bucket.windowDurationMins ?? bucket.windowDurationMinutes ?? bucket.window_minutes
  );
  const resetsAt = bucket.resetsAt ?? bucket.resets_at ?? null;

  if (usedPercent === null || windowDurationMins === null || !resetsAt) {
    return null;
  }

  const id = bucket.limitId ?? bucket.limit_id ?? `bucket-${index + 1}`;

  return {
    id,
    usedPercent,
    remainingPercent: Math.max(0, 100 - usedPercent),
    windowDurationMins,
    windowLabel: formatWindow(windowDurationMins),
    resetsAt,
    hasCredits: bucket.hasCredits ?? bucket.has_credits ?? true
  };
}

function isBucketCandidate(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  return (
    value.usedPercent !== undefined ||
    value.used_percent !== undefined ||
    value.windowDurationMins !== undefined ||
    value.windowDurationMinutes !== undefined ||
    value.window_minutes !== undefined ||
    value.resetsAt !== undefined ||
    value.resets_at !== undefined
  );
}

function firstDefined(source, keys) {
  for (const key of keys) {
    if (source?.[key]) {
      return source[key];
    }
  }

  return null;
}

function numberOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function formatTitle(buckets) {
  const titleBuckets = buckets.slice(0, 2);
  const warningSuffix = titleBuckets.some((item) => item.remainingPercent <= 15) ? ' !' : '';
  const summary = titleBuckets.map((item) => `${item.windowLabel} ${item.remainingPercent}%`).join(' · ');
  return `${summary}${warningSuffix}`;
}

function formatSubtitle(buckets) {
  return buckets
    .slice(0, 2)
    .map((bucket) => `${bucket.windowLabel} resets ${formatReset(bucket.resetsAt)}`)
    .join(' · ');
}

function formatAccountLabel(account) {
  if (!account.authMode || account.authMode === 'unknown') {
    return account.displayName;
  }

  return `${account.displayName} · ${account.authMode}`;
}

function formatReset(timestamp) {
  const date = normalizeDate(timestamp);
  if (Number.isNaN(date.valueOf())) {
    return 'unknown';
  }

  const now = new Date();
  const timeLabel = new Intl.DateTimeFormat('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  }).format(date);

  if (isSameLocalDay(date, now)) {
    return `today ${timeLabel}`;
  }

  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  if (isSameLocalDay(date, tomorrow)) {
    return `tomorrow ${timeLabel}`;
  }

  const dateOptions = now.getFullYear() === date.getFullYear()
    ? { month: 'short', day: 'numeric' }
    : { year: 'numeric', month: 'short', day: 'numeric' };
  const dateLabel = new Intl.DateTimeFormat('en-US', dateOptions).format(date);

  return `${dateLabel}, ${timeLabel}`;
}

function formatBucketSubtitle(bucket) {
  const details = [`Resets ${formatReset(bucket.resetsAt)}`];
  if (bucket.hasCredits === false) {
    details.push('No credits');
  }

  return details.join(' · ');
}

function normalizeDate(timestamp) {
  const numericTimestamp = Number(timestamp);
  if (Number.isFinite(numericTimestamp)) {
    const milliseconds = numericTimestamp < 1e12 ? numericTimestamp * 1000 : numericTimestamp;
    return new Date(milliseconds);
  }

  return new Date(timestamp);
}

function isSameLocalDay(left, right) {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

function formatWindow(minutes) {
  if (minutes % 10080 === 0) {
    return `${minutes / 10080}w`;
  }

  if (minutes % 1440 === 0) {
    return `${minutes / 1440}d`;
  }

  if (minutes % 60 === 0) {
    return `${minutes / 60}h`;
  }

  return `${minutes}m`;
}
