import 'package:flutter/cupertino.dart';

class PetFormScreen extends StatelessWidget {
  final String? petId;
  const PetFormScreen({super.key, this.petId});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('宠物档案')),
      child: Center(child: Text('Pet Form - Coming Soon')),
    );
  }
}
