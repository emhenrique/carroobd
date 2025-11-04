
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/providers/obd2_provider.dart';
import 'package:myapp/screens/wrapper.dart';
import 'package:myapp/widgets/temp_overlay_widget.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => OBD2Provider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Ponto de entrada para a janela de sobreposição
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      home: TempOverlayWidget(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primarySeedColor = Colors.cyan;

    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.roboto(fontSize: 57, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.roboto(fontSize: 14),
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primarySeedColor, brightness: Brightness.light),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primarySeedColor, brightness: Brightness.dark),
      textTheme: appTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return MaterialApp(
      title: 'OBD2 Scanner',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, 
      home: const Wrapper(), // A home agora é o Wrapper
      debugShowCheckedModeBanner: false,
    );
  }
}
