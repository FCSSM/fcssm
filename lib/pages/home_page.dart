import 'package:flutter/material.dart';
import 'planning_page.dart';
import 'impression_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int index = 0;

  final pages = const [
    PlanningPage(),
    ImpressionPage(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: pages[index],

      bottomNavigationBar: NavigationBar(

        selectedIndex: index,

        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },

        destinations: const [

          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Planning",
          ),

          NavigationDestination(
            icon: Icon(Icons.print),
            label: "Impression",
          ),
        ],
      ),
    );
  }
}