import 'package:flutter/material.dart';

class AdminBackHandler extends StatefulWidget {
  final Widget child;
  final bool isDashboard;
  final WidgetBuilder? dashboardBuilder;

  const AdminBackHandler({
    super.key,
    required this.child,
    this.isDashboard = false,
    this.dashboardBuilder,
  });

  @override
  State<AdminBackHandler> createState() => _AdminBackHandlerState();
}

class _AdminBackHandlerState extends State<AdminBackHandler> {
  DateTime? _lastBackPressedAt;

  Future<bool> _onWillPop() async {
    if (widget.isDashboard) {
      final now = DateTime.now();
      if (_lastBackPressedAt == null ||
          now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
        _lastBackPressedAt = now;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presiona atras otra vez para salir')),
        );
        return false;
      }
      return true;
    }

    final builder = widget.dashboardBuilder;
    if (builder != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: builder),
        (route) => false,
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: widget.child,
    );
  }
}
