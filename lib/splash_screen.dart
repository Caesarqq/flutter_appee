import 'main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// class SplashScreen extends StatelessWidget {
//   final AuthenticationCubit authenticationCubit;

//   SplashScreen({required this.authenticationCubit});

//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<AuthenticationCubit, bool>(
//       cubit: authenticationCubit,
//       builder: (cubitContext, isAuthenticated) {
//         if (isAuthenticated) {
//           return MyHomePage();
//         } else {
//           return AuthenticationScreen();
//         }
//       },
//     );
//   }
// }
class AuthenticationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authentication'),
      ),
      body: Center(
        child: BlocBuilder<AuthenticationCubit, bool>(
          builder: (context, isAuthenticated) {
            return ElevatedButton(
              onPressed: () {
                if (isAuthenticated) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MyHomePage()),
                  );
                } else {
                  context.read<AuthenticationCubit>().authenticate();
                }
              },
              child: Text(
                  isAuthenticated ? 'Вернуться на главную' : 'Authenticate'),
            );
          },
        ),
      ),
    );
  }
}
