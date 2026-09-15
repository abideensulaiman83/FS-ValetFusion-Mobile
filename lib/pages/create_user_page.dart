import 'package:flutter/material.dart';
import '../components/layout/app_layout.dart';

class CreateUserPage extends StatelessWidget {
  const CreateUserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AppLayout(
      title: 'Create User',
      child: Center(
        child: Text('Create User Page'),
      ),
    );
  }
}