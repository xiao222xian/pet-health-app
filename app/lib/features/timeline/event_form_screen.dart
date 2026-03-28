import 'package:flutter/cupertino.dart';

class EventFormScreen extends StatelessWidget {
  final String petId;
  const EventFormScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('添加记录')),
      child: Center(child: Text('Event Form - Coming Soon')),
    );
  }
}
