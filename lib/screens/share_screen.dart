import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("image share"),),
      body: const Center(
          child: SizedBox(
            height: 300,
            width: 300,
            child: ColoredBox(
                color: Colors.blue,
                child: Text("fire!!!")
            ),

          )
      ),
    );
  }
}
