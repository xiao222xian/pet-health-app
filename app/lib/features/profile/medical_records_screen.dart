import 'package:flutter/cupertino.dart';

class MedicalRecordsScreen extends StatelessWidget {
  final String petId;
  const MedicalRecordsScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('医疗记录')),
      child: Center(child: Text('Medical Records - Coming Soon')),
    );
  }
}
