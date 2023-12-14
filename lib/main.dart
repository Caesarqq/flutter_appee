import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animations/animations.dart';

void main() {
  runApp(MyApp());
}

class CatImage {
  final String url;

  CatImage({required this.url});

  factory CatImage.fromJson(Map<String, dynamic> json) {
    return CatImage(url: json['url']);
  }

  Map<String, dynamic> toJson() {
    return {'url': url};
  }
}

class CatCubit extends Cubit<List<CatImage>> {
  CatCubit() : super([]);

  void fetchCatImages() async {
    try {
      final response = await http.get(
          Uri.parse('https://api.thecatapi.com/v1/images/search?limit=10'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        List<CatImage> catImages =
            data.map((json) => CatImage.fromJson(json)).toList();
        emit(catImages);
      } else {
        throw Exception('Failed to load cat images');
      }
    } catch (e) {
      throw (Exception('Failed to load cat images: $e'));
    }
  }
}

class AuthenticationCubit extends Cubit<bool> {
  AuthenticationCubit() : super(false);

  Future<void> checkAuthenticationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    emit(isAuthenticated);
  }

  Future<void> authenticate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    emit(true);
  }
}

class InternetCubit extends Cubit<bool> {
  InternetCubit() : super(false);

  StreamSubscription? _subscription;

  void checkInternetConnection() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((result) async {
      bool isConnected = await _isConnected(result);
      emit(isConnected);
    });
  }

  Future<bool> _isConnected(ConnectivityResult result) async {
    return result != ConnectivityResult.none;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class FavoriteCubit extends Cubit<List<CatImage>> {
  FavoriteCubit() : super([]);

  SharedPreferences? _prefs;

  void initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    emit(getFavorites());
  }

  List<CatImage> getFavorites() {
    final List<String>? favoriteStrings = _prefs?.getStringList('favorites');
    if (favoriteStrings == null || favoriteStrings.isEmpty) {
      return [];
    }
    return favoriteStrings.map((json) {
      final Map<String, dynamic> map = jsonDecode(json);
      return CatImage.fromJson(map);
    }).toList();
  }

  void updateFavorites(List<CatImage> updatedFavorites) {
    _prefs?.setStringList('favorites',
        updatedFavorites.map((cat) => jsonEncode(cat.toJson())).toList());
    emit(updatedFavorites);
  }

  void addToFavorites(CatImage catImage) {
    final List<CatImage> updatedFavorites = List.from(state);
    updatedFavorites.add(catImage);
    updateFavorites(updatedFavorites);
  }

  void removeFromFavorites(CatImage catImage) {
    final List<CatImage> updatedFavorites = List.from(state);
    updatedFavorites.remove(catImage);
    updateFavorites(updatedFavorites);
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CatCubit()..fetchCatImages()),
        BlocProvider(
            create: (context) => FavoriteCubit()..initializePreferences()),
        BlocProvider(
            create: (context) =>
                AuthenticationCubit()..checkAuthenticationStatus()),
        BlocProvider(
            create: (context) => InternetCubit()..checkInternetConnection()),
      ],
      child: MaterialApp(
        title: 'f',
        theme: ThemeData(
          primarySwatch: Colors.red,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: BlocBuilder<AuthenticationCubit, bool>(
          builder: (context, isAuthenticated) {
            if (isAuthenticated) {
              return MyHomePage();
            } else {
              return AuthenticationScreen();
            }
          },
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Котики-наркотики'),
      ),
      body: _selectedIndex == 0 ? GeneratorPage() : FavoritesPage(),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Котики',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatCubit, List<CatImage>>(
      builder: (context, catImages) {
        if (catImages.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        var catImage = catImages.first;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FullScreenImagePage(imageUrl: catImage.url),
                    ),
                  );
                },
                child: Hero(
                  tag: catImage.url,
                  child: OpenContainer(
                    closedBuilder:
                        (BuildContext _, VoidCallback openContainer) {
                      return SizedBox(
                        width: 200,
                        height: 200,
                        child: Card(
                          elevation: 5,
                          child: Image.network(
                            catImage.url,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                    openBuilder: (BuildContext _, VoidCallback closeContainer) {
                      return FullScreenImagePage(imageUrl: catImage.url);
                    },
                    transitionType: ContainerTransitionType.fadeThrough,
                    transitionDuration: Duration(milliseconds: 500),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      context.read<CatCubit>().fetchCatImages();
                    },
                    child: Text('Скип'),
                  ),
                  SizedBox(width: 50),
                  ElevatedButton(
                    onPressed: () {
                      final favoriteCubit = context.read<FavoriteCubit>();
                      final List<CatImage> updatedFavorites =
                          List.from(favoriteCubit.state);
                      updatedFavorites.add(catImage);
                      favoriteCubit.updateFavorites(updatedFavorites);
                    },
                    child: Text('Топ'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteCubit, List<CatImage>>(
      builder: (context, favorites) {
        if (favorites.isEmpty) {
          return Center(child: Text('Избранного нет.'));
        }

        return PageView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              padding: EdgeInsets.all(10),
              color: const Color.fromARGB(255, 233, 136, 168),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: IconButton(
                      icon: Icon(Icons.delete_outline),
                      onPressed: () {
                        context
                            .read<FavoriteCubit>()
                            .removeFromFavorites(favorites[index]);
                      },
                    ),
                    title: Image.network(
                      favorites[index].url,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      _startChatWithCat(context, favorites[index]);
                    },
                    child: Text('Написать лучшему котику в этом мире'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startChatWithCat(BuildContext context, CatImage cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(cat: cat),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final CatImage cat;

  ChatScreen({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чат с котиком'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.network(
                cat.url,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              decoration: InputDecoration(
                hintText: 'Введите ваше сообщение...',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _sendMessage(context, cat);
            },
            child: Text('Отправить сообщение'),
          ),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context, CatImage cat) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Сообщение отправлено котику!'),
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthenticationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authentication'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.read<AuthenticationCubit>().authenticate();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MyHomePage()),
            );
          },
          child: Text('Authenticate'),
        ),
      ),
    );
  }
}
