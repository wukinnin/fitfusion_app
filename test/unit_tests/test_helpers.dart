import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TargetScreen extends StatelessWidget {
  final String label;

  const TargetScreen(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label)),
    );
  }
}

Widget buildTestApp({
  Widget? home,
  Map<String, WidgetBuilder> routes = const {},
  RouteFactory? onGenerateRoute,
  String? initialRoute,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;

  return MaterialApp(
    home: home,
    routes: routes,
    onGenerateRoute: onGenerateRoute,
    initialRoute: initialRoute,
  );
}
