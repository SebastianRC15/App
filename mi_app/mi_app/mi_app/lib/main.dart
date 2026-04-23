import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// CONFIGURACIÓN GLOBAL
// Usa '10.0.2.2' para el emulador de Android Studio y '127.0.0.1' para web o local.
const String baseUrl = 'http://10.0.2.2:8000/api'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda Simple',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// ESTADO GLOBAL SIMPLE
class GlobalState {
  static String? token;
  static Map<String, dynamic>? usuario;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    ProductListScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shop), label: 'Productos'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Carrito'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// --- PANTALLA DE PRODUCTOS ---
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List _allProducts = [];
  List _filteredProducts = [];
  List _categorias = [];
  String _categoriaSeleccionada = 'Todos';
  bool _isLoading = false;
  int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (_hasMore && !_isLoading) {
          _cargarMasProductos();
        }
      }
    });
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _obtenerCategorias(),
      _obtenerProductos(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _obtenerCategorias() async {
    final response = await http.get(Uri.parse('$baseUrl/productos/categorias/'));
    if (response.statusCode == 200) {
      final cats = json.decode(utf8.decode(response.bodyBytes)) as List;
      setState(() {
        _categorias = ['Todos', ...cats];
      });
    }
  }

  Future<void> _obtenerProductos({String? search, String? categoria, String? tipoOferta, double? precioMax}) async {
    String url = '$baseUrl/productos/?limit=$_limit';
    if (search != null && search.isNotEmpty) url += '&search=$search';
    if (categoria != null && categoria != 'Todos') url += '&categoria=$categoria';
    if (tipoOferta != null) url += '&tipo_oferta=$tipoOferta';
    if (precioMax != null) url += '&precio_max=$precioMax';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        _allProducts = data;
        _filteredProducts = data;
        _hasMore = data.length >= _limit;
      });
    }
  }

  Future<void> _cargarMasProductos() async {
    setState(() => _isLoading = true);
    _limit += 20;
    await _obtenerProductos(
      search: _searchController.text,
      categoria: _categoriaSeleccionada,
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Buscador Grande Fijo
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 70,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _obtenerProductos(search: val),
                  decoration: InputDecoration(
                    hintText: 'Buscar productos...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Banner Promocional Animado
                const PromotionalBanner(),

                // 3. Categorías horizontales
                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text('Categorías', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categorias.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      final cat = _categorias[index];
                      final isSelected = _categoriaSeleccionada == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _categoriaSeleccionada = cat);
                            _obtenerProductos(categoria: cat);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // 4. 3 tipos de botones oferta
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _offerButton('Más Vendidos', Icons.trending_up, Colors.orange, 'MAS_VENDIDO'),
                      _offerButton('Oferta Flash', Icons.flash_on, Colors.red, 'FLASH'),
                      _offerButton('Liquidación', Icons.shopping_bag, Colors.blue, 'LIQUIDACION'),
                    ],
                  ),
                ),

                // 5. Productos Gancho < S/9.90
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text('Lo más económico (Menos de S/9.90)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                HookProductsSection(onProductTap: (p) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(producto: p)))),

                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text('Para ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 6. Colección de productos aleatoria
          SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = _filteredProducts[index];
                  return ProductCard(p: p);
                },
                childCount: _filteredProducts.length,
              ),
            ),
          ),

          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _cargarMasProductos,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Ver más productos'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _offerButton(String label, IconData icon, Color color, String tipo) {
    return InkWell(
      onTap: () => _obtenerProductos(tipoOferta: tipo),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Banner Promocional Animado
class PromotionalBanner extends StatefulWidget {
  const PromotionalBanner({super.key});

  @override
  State<PromotionalBanner> createState() => _PromotionalBannerState();
}

class _PromotionalBannerState extends State<PromotionalBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<String> _banners = [
    'https://img.freepik.com/free-vector/modern-sale-banner-template-with-abstract-shapes_23-2148204768.jpg',
    'https://img.freepik.com/free-vector/flat-sale-banner-with-photo_23-2149026968.jpg',
    'https://img.freepik.com/free-vector/gradient-sale-background-with-photo_23-2149021468.jpg',
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _autoPlay);
  }

  void _autoPlay() {
    if (!mounted) return;
    _currentPage = (_currentPage + 1) % _banners.length;
    _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    Future.delayed(const Duration(seconds: 3), _autoPlay);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _banners.length,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: DecorationImage(image: NetworkImage(_banners[index]), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

// Sección de Productos Gancho < 9.90
class HookProductsSection extends StatelessWidget {
  final Function(dynamic) onProductTap;
  const HookProductsSection({super.key, required this.onProductTap});

  Future<List> _getCheapProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/productos/?precio_max=9.90'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: FutureBuilder<List>(
        future: _getCheapProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              final p = snapshot.data![index];
              return GestureDetector(
                onTap: () => onProductTap(p),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p['imagen'], fit: BoxFit.cover))),
                      Text('S/ ${p['precio']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Componente Tarjeta de Producto (Reutilizable)
class ProductCard extends StatelessWidget {
  final dynamic p;
  const ProductCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final double precio = double.tryParse(p['precio'].toString()) ?? 0;
    final double? precioNormal = p['precio_normal'] != null ? double.tryParse(p['precio_normal'].toString()) : null;
    final int descuento = p['descuento_porcentaje'] ?? 0;
    final double rating = (p['calificacion'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(producto: p))),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      image: DecorationImage(image: NetworkImage(p['imagen']), fit: BoxFit.cover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(rating.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p['nombre'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (precioNormal != null && precioNormal > precio) ...[
                        Text('S/ ${precioNormal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ] else
                        Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (descuento > 0)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('-$descuento%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            Positioned(
              bottom: 10, right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.blueAccent, radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: () => const ProductDetailScreen(producto: {}).agregarAlCarrito(context),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DETALLE DE PRODUCTO ---
class ProductDetailScreen extends StatefulWidget {
  final dynamic producto;
  const ProductDetailScreen({super.key, required this.producto});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();

  // Mantenemos este método estático o accesible para que ProductListScreen pueda usarlo
  Future<void> agregarAlCarrito(BuildContext context, {int cantidad = 1}) async {
    if (GlobalState.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inicia sesión para agregar al carrito')));
      return;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/carrito/agregar/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${GlobalState.token}',
      },
      body: json.encode({'producto_id': producto['id'], 'cantidad': cantidad}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregado al carrito')));
    }
  }
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _cantidad = 1;
  bool _descripcionExpandida = false;
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final List<String> imagenes = [
      p['imagen'],
      if (p['imagen2'] != null && p['imagen2'].isNotEmpty) p['imagen2'],
      if (p['imagen3'] != null && p['imagen3'].isNotEmpty) p['imagen3'],
      if (p['imagen4'] != null && p['imagen4'].isNotEmpty) p['imagen4'],
    ];

    final double precio = double.tryParse(p['precio'].toString()) ?? 0;
    final double? precioNormal = p['precio_normal'] != null ? double.tryParse(p['precio_normal'].toString()) : null;
    final int descuento = p['descuento_porcentaje'] ?? 0;
    final double subtotal = precio * _cantidad;

    return Scaffold(
      appBar: AppBar(title: Text(p['nombre'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrusel de Imágenes
            Stack(
              children: [
                SizedBox(
                  height: 350,
                  child: PageView.builder(
                    itemCount: imagenes.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) => Image.network(imagenes[index], fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
                if (imagenes.length > 1)
                  Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: imagenes.asMap().entries.map((entry) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == entry.key ? Colors.blueAccent : Colors.grey.shade400,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (descuento > 0)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                      child: Text('-$descuento%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tienda y Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vendido por: ${p['tienda'] ?? 'Tienda General'}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(' ${p['calificacion'] ?? 0.0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Nombre
                  Text(p['nombre'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Precios
                  if (precioNormal != null && precioNormal > precio) ...[
                    Text('S/ ${precioNormal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    Row(
                      children: [
                        Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(width: 10),
                        const Text('OFERTA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ] else
                    Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),

                  const SizedBox(height: 15),
                  Text('Stock disponible: ${p['stock']}', style: TextStyle(color: p['stock'] > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),

                  // Descripción con botón desplegable
                  InkWell(
                    onTap: () => setState(() => _descripcionExpandida = !_descripcionExpandida),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descripción y Características', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Icon(_descripcionExpandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                  if (_descripcionExpandida)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(p['descripcion'], style: const TextStyle(fontSize: 16, height: 1.5)),
                    ),

                  const Divider(height: 30),

                  // Cantidad y Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cantidad:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null, icon: const Icon(Icons.remove_circle_outline)),
                          Text('$_cantidad', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: _cantidad < p['stock'] ? () => setState(() => _cantidad++) : null, icon: const Icon(Icons.add_circle_outline)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sub Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('S/ ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: p['stock'] > 0 ? () => widget.agregarAlCarrito(context, cantidad: _cantidad) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 28),
                    label: const Text('AGREGAR AL CARRITO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CARRITO ---
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<Map<String, dynamic>> obtenerCarrito() async {
    if (GlobalState.token == null) return {};
    final response = await http.get(
      Uri.parse('$baseUrl/carrito/'),
      headers: {'Authorization': 'Bearer ${GlobalState.token}'},
    );
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<void> vaciarCarrito() async {
    final response = await http.post(
      Uri.parse('$baseUrl/carrito/vaciar/'),
      headers: {'Authorization': 'Bearer ${GlobalState.token}'},
    );
    if (response.statusCode == 200) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carrito vaciado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GlobalState.token == null) {
      return const Center(child: Text('Inicia sesión para ver tu carrito'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito'),
        actions: [
          IconButton(onPressed: vaciarCarrito, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: obtenerCarrito(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!['items'] == null || snapshot.data!['items'].isEmpty) {
            return const Center(child: Text('Tu carrito está vacío'));
          }

          final items = snapshot.data!['items'] as List;
          double total = 0;
          for (var item in items) {
            total += (item['producto']['precio'] * item['cantidad']);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Image.network(item['producto']['imagen'], width: 50),
                      title: Text(item['producto']['nombre']),
                      subtitle: Text('Cant: ${item['cantidad']} - S/ ${item['producto']['precio']}'),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('S/ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- PERFIL ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  Future<void> login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        body: {'username': _userController.text, 'password': _passController.text},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        GlobalState.token = data['access'];
        await fetchUserData();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión iniciada correctamente')));
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${error['detail'] ?? 'Credenciales inválidas'}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> register() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _userController.text,
          'password': _passController.text,
          'email': '${_userController.text}@example.com',
        }),
      );
      
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro exitoso, iniciando sesión...')));
        await login();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en registro: $error')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/'),
        headers: {'Authorization': 'Bearer ${GlobalState.token}'},
      );
      
      if (response.statusCode == 200) {
        final List users = json.decode(utf8.decode(response.bodyBytes));
        GlobalState.usuario = users.firstWhere(
          (u) => u['username'] == _userController.text,
          orElse: () => null,
        );
      }
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GlobalState.token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ingreso')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(controller: _userController, decoration: const InputDecoration(labelText: 'Usuario')),
              TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: login, child: const Text('Iniciar Sesión')),
              TextButton(onPressed: register, child: const Text('Registrarse')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido, ${GlobalState.usuario?['username']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Email: ${GlobalState.usuario?['email'] ?? 'No disponible'}'),
            const Spacer(),
            ElevatedButton(
              onPressed: () => setState(() => GlobalState.token = null),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Cerrar Sesión'),
            )
          ],
        ),
      ),
    );
  }
}
