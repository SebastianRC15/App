import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';

// --- PANTALLA PRINCIPAL (IMAGEN 1) ---
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const InicioContent(),
    const Center(child: Text('Explorar')),
    const Center(child: Text('Carrito')),
    const Center(child: Text('Usuario')),
  ];

  // Lista de pantallas para el Bottom Navigation Bar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Tezorum',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 25,
            letterSpacing: -0.9,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.search,
              color: Color.fromARGB(255, 153, 17, 136),
              size: 25,
              weight: 800,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              CupertinoIcons.bell,
              color: Color.fromARGB(255, 153, 17, 136),
              size: 25,
            ),
            onPressed: () {
              // ESTO HACE QUE SE ABRA LA PANTALLA AL DAR CLICK
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Color.fromARGB(255, 153, 17, 136),
        unselectedItemColor: Colors.black45,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Tienda',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            activeIcon: Icon(CupertinoIcons.compass_fill),
            label: 'Descubre',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.shopping_cart),
            activeIcon: Icon(CupertinoIcons.cart_fill),
            label: 'Carrito',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'Usuario',
          ),
        ],
      ),
    );
  }
}

// --- SECCIÓN DE BANNERS CON MOVIMIENTO -
class BannerRotativo extends StatefulWidget {
  const BannerRotativo({super.key});

  @override
  State<BannerRotativo> createState() => _BannerRotativoState();
}

class _BannerRotativoState extends State<BannerRotativo> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cambia cada 1 segundo
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < 3) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 1,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 4,
        onPageChanged: (int page) => setState(() => _currentPage = page),
        itemBuilder: (context, index) {
          return Container(
            width: MediaQuery.of(context).size.width,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: const Color(0xFFE0E0E0), // Color de fondo mientras carga
              image: DecorationImage(
                // Aquí llamamos a la imagen
                image: AssetImage(
                  'assets/images/banners/banner${index + 1}.gif',
                ),
                fit: BoxFit.cover, // Para que la imagen ocupe todo el espacio
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: i == _currentPage ? 12 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? Colors.white
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- SECCIÓN DE CATEGORÍAS (SCROLL HORIZONTAL) ---
class CategoriasScroll extends StatefulWidget {
  const CategoriasScroll({super.key});

  @override
  State<CategoriasScroll> createState() => _CategoriasScrollState();
}

class _CategoriasScrollState extends State<CategoriasScroll> {
  int _selectedIdx = 0; // Solo una vez

  final List<Map<String, dynamic>> _categoriasInfo = [
    {'nombre': 'Todo', 'icono': CupertinoIcons.grid},
    {'nombre': 'Audio/Parlantes', 'icono': CupertinoIcons.speaker_2},
    {'nombre': 'Audífonos', 'icono': CupertinoIcons.headphones},
    {'nombre': 'Hogar/Electrónica', 'icono': CupertinoIcons.house_alt},
    {'nombre': 'Juguetes', 'icono': CupertinoIcons.rocket},
    {
      'nombre': 'Juegos de Mesa',
      'icono': CupertinoIcons.square_grid_2x2,
    }, // Representa mejor un tablero
    {
      'nombre': 'Accesorios Móviles',
      'icono': CupertinoIcons.device_phone_portrait,
    },
    {'nombre': 'Cómputo', 'icono': CupertinoIcons.desktopcomputer},
    {'nombre': 'Videojuegos', 'icono': CupertinoIcons.gamecontroller},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _categoriasInfo.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedIdx == index;
          final categoria = _categoriasInfo[index];

          return GestureDetector(
            onTap: () => setState(() => _selectedIdx = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.fromARGB(255, 153, 17, 136)
                    : const Color.fromARGB(220, 237, 239, 250),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    categoria['icono'],
                    size: 18,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    categoria['nombre'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PANTALLA DE BÚSQUEDA  ---
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Que estas buscando? ...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.tune,
                    color: Colors.grey.shade600,
                  ), // Icono de filtros
                ),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              child: Center(
                child: Text(
                  'Los resultados apareceran aqui',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de campana tachada o vacía en grande
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.bell_slash, // Campana con línea de "no hay"
                color: Colors.black26,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            // Mensaje principal
            const Text(
              'No hay notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            // Mensaje secundario
            Text(
              'Te avisaremos cuando tengamos\nnovedades para ti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class InicioContent extends StatelessWidget {
  const InicioContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const BannerRotativo(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 15),
            child: Text(
              'Categorias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const CategoriasScroll(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
