class AdminScope {
  // Definir al ejecutar: --dart-define=ADMIN_VENDEDOR_ID=1
  static const int adminVendedorId =
      int.fromEnvironment('ADMIN_VENDEDOR_ID', defaultValue: 0);

  static int? get vendedorId => adminVendedorId > 0 ? adminVendedorId : null;
}
