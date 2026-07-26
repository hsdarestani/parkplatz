class Environment {
  static const isDemo = false;
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Native release builds cannot resolve a relative `/api` URL. Keep the
  // production API as the safe default and override it with `/api` only for
  // the hosted web build, where Nginx proxies same-origin requests.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://parkplatz.smarbiz.sbs/api',
  );

  static const allowLocalBookingFallback = bool.fromEnvironment(
    'ALLOW_LOCAL_BOOKING_FALLBACK',
    defaultValue: false,
  );
}
