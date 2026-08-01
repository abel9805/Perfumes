import 'package:flutter/material.dart';
import '../config/app_mode.dart';
import '../screens/home_screen.dart';
import '../screens/perfumes/perfumes_screen.dart';
import '../screens/vendedores/vendedores_screen.dart';
import '../screens/clientes/clientes_screen.dart';
import '../screens/comisiones/comisiones_screen.dart';
import '../screens/ventas/ventas_screen.dart';
import '../screens/ventas/saldo_por_cobrar_screen.dart';
import '../screens/entregas/entregas_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isColega = AppModeConfig.isColega;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade800, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.spa, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  AppModeConfig.isColega ? 'COLEGA APP' : 'OVORA APP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isColega ? 'Vista operativa' : 'Control de negocio',
                  style: TextStyle(color: Colors.purple.shade100, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isColega)
            _buildTile(
                context, Icons.dashboard, 'Dashboard', const HomeScreen()),
          if (!isColega) const Divider(),
          _buildTile(
              context, Icons.local_florist, 'Perfumes', const PerfumesScreen()),
          if (!isColega)
            _buildTile(context, Icons.people_alt, 'Vendedores',
                const VendedoresScreen()),
          if (!isColega)
            _buildTile(
                context, Icons.person, 'Clientes', const ClientesScreen()),
          if (!isColega)
            _buildTile(
                context, Icons.percent, 'Comisiones', const ComisionesScreen()),
          const Divider(),
          _buildTile(context, Icons.delivery_dining, 'Entregas a Vendedores',
              const EntregasScreen(tipoFiltro: 'todos')),
          _buildTile(context, Icons.local_shipping, 'Pedidos de Vendedores',
              const EntregasScreen(modoPedidos: true, tipoFiltro: 'pedido')),
          if (!isColega)
            _buildTile(context, Icons.attach_money, 'Saldo por cobrar',
                const SaldoPorCobrarScreen()),
          if (!isColega)
            _buildTile(context, Icons.receipt_long, 'Ventas a Crédito',
                const VentasScreen()),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple.shade700),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
    );
  }
}
