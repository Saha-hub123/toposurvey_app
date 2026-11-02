import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/survey_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TopoSurveyApp());
}

class TopoSurveyApp extends StatelessWidget {
  const TopoSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SurveyState(),
      child: MaterialApp(
        title: 'TopoSurvey 3D',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F131D),
          colorScheme: const ColorScheme.dark(
            primary: Colors.tealAccent,
            secondary: Colors.orangeAccent,
            surface: Color(0xFF161B26),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF141923),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.tealAccent),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
