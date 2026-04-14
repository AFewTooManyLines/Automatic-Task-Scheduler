import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

// colours
var primaryColor = const Color.fromARGB(255, 156, 132, 201);
var darkPrimaryColor = const Color.fromARGB(255, 120, 100, 170);

// functioning
bool darkMode = false;

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Studia',

      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,

          titleTextStyle: GoogleFonts.lato(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        useMaterial3: true,
      ),
      
      darkTheme: ThemeData(
        
        appBarTheme: AppBarTheme(
          backgroundColor: darkPrimaryColor,
          titleTextStyle: GoogleFonts.lato(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        
        scaffoldBackgroundColor: const Color.fromARGB(255, 24, 24, 24),
        
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color.fromARGB(255, 32, 32, 32),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
        ),
        
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      home: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,

            children: [
              const Text(
                'Studia',

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                'Assessment Work Planner',
                
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          
          actions: [
            SwitchTheme(
              data: SwitchThemeData(
                thumbColor: darkMode ? WidgetStateProperty.all(Colors.black) : WidgetStateProperty.all(primaryColor),
                trackColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.5),
                ),
                thumbIcon: darkMode ? const WidgetStatePropertyAll(Icon(Icons.dark_mode)) : const WidgetStatePropertyAll(Icon(Icons.light_mode)),
              ),
              
              child: Switch(
                value: darkMode,

                onChanged: (value) {
                  setState(() {
                    darkMode = value;
                  });
                },
              ),
            ),
          ],
        ),

        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt),
              label: 'Assessments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Calender',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
