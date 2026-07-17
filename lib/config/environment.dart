class Environment {
  static const isDemo = true;
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '/api');
  static const allowLocalBookingFallback = bool.fromEnvironment(
    'ALLOW_LOCAL_BOOKING_FALLBACK',
    defaultValue: true,
  );
}
