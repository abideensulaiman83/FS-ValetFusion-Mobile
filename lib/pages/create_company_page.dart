import 'package:flutter/material.dart';
import '../components/layout/app_layout.dart';

class CreateCompanyPage extends StatelessWidget {
  const CreateCompanyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AppLayout(
      title: 'Create Company',
      child: Center(
        child: Text('Create Company Page'),
      ),
    );
  }
}