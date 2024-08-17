import 'package:flutter/material.dart';

class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                strokeWidth: 15.0,
                valueColor: AlwaysStoppedAnimation(Color(0xFFD1C4E9)),
              ),
            ),
            Text(
              "WebRTC connecting...",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// class LoadScreen extends StatelessWidget {
//   const LoadScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           "WebRTC connecting...",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 20),
//         ),
//       ),
//     );
//   }
// }
