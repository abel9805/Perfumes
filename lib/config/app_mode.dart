enum AppMode { admin, colega }

class AppModeConfig {
  static AppMode _mode =
      const String.fromEnvironment('APP_MODE', defaultValue: 'admin') ==
              'colega'
          ? AppMode.colega
          : AppMode.admin;

  static AppMode get mode => _mode;

  static bool get isColega => _mode == AppMode.colega;

  static void setMode(AppMode mode) {
    _mode = mode;
  }
}
