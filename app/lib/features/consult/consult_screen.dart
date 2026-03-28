import 'package:flutter/cupertino.dart';

class ConsultScreen extends StatelessWidget {
  const ConsultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('AI 问诊')),
      child: Center(child: Text('Consult - Coming Soon')),
    );
  }
}
