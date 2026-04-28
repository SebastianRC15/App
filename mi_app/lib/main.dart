import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// CONFIGURACIÓN GLOBAL
const String baseUrl = 'https://mi-app-django.onrender.com/api';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

// GESTIÓN DE CARRITO LOCAL
class CartItem {
  final Map<String, dynamic> producto;
  int cantidad;

  CartItem({required this.producto, this.cantidad = 1});
}

class CartManager {
  static List<CartItem> items = [];

  static void agregar(Map<String, dynamic> producto, {int cantidad = 1}) {
    final index = items.indexWhere((item) => item.producto['id'] == producto['id']);
    if (index != -1) {
      items[index].cantidad += cantidad;
    } else {
      items.add(CartItem(producto: producto, cantidad: cantidad));
    }
  }

  static double get subtotal {
    return items.fold<double>(0.0, (sum, item) => sum + (double.parse((item.producto['precio_oferta'] ?? item.producto['precio_normal']).toString()) * item.cantidad));
  }

  static void vaciar() => items.clear();
}

// ESTADO GLOBAL SIMPLE
class GlobalState {
  static String? token;
  static Map<String, dynamic>? usuario;

  static Future<void> fetchUserData() async {
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/mi_perfil/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        usuario = json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
    }
  }

  static void agregarAlCarrito(BuildContext context, Map<String, dynamic> producto, {int cantidad = 1}) {
    CartManager.agregar(producto, cantidad: cantidad);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto añadido al carrito')),
    );
  }
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
    try {
      final response = await http.get(Uri.parse('$baseUrl/categorias/'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          _categorias = [
            {'nombre': 'Todos', 'id': null},
            ...data
          ];
        });
      }
    } catch (e) {
      print('Error al obtener categorías: $e');
    }
  }

  Future<void> _obtenerProductos({String? search, dynamic categoriaId, String? tipoOferta, double? precioMax}) async {
    String url = '$baseUrl/productos/?limit=$_limit';
    if (search != null && search.isNotEmpty) url += '&search=$search';
    if (categoriaId != null) url += '&categoria_id=$categoriaId';
    if (tipoOferta == 'MAS_VENDIDO') url += '&es_mas_vendido=true';
    if (tipoOferta == 'FLASH') url += '&es_oferta_flash=true';
    if (precioMax != null) url += '&precio_max=$precioMax';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _allProducts = data;
          _filteredProducts = data;
          _hasMore = data.length >= _limit;
        });
      }
    } catch (e) {
      print('Error al obtener productos: $e');
    }
  }

  Future<void> _cargarMasProductos() async {
    setState(() => _isLoading = true);
    _limit += 20;
    await _obtenerProductos(
      search: _searchController.text,
      categoriaId: _categoriaSeleccionada == 'Todos' ? null : _categorias.firstWhere((c) => c['nombre'] == _categoriaSeleccionada)['id'],
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
                      final catNombre = cat['nombre'];
                      final isSelected = _categoriaSeleccionada == catNombre;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ChoiceChip(
                          label: Text(catNombre),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _categoriaSeleccionada = catNombre);
                            _obtenerProductos(categoriaId: cat['id']);
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
    try {
      final response = await http.get(Uri.parse('$baseUrl/productos/?precio_max=9.90'));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Error al obtener productos económicos: $e');
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
              final String imagen = (p['imagenes'] as List).isNotEmpty ? p['imagenes'][0] : 'https://via.placeholder.com/150';
              final double precio = double.tryParse((p['precio_oferta'] ?? p['precio_normal']).toString()) ?? 0;
              return GestureDetector(
                onTap: () => onProductTap(p),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imagen, fit: BoxFit.cover))),
                      Text('S/ ${precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
    final double precio = double.tryParse((p['precio_oferta'] ?? p['precio_normal']).toString()) ?? 0;
    final double? precioNormal = p['precio_normal'] != null ? double.tryParse(p['precio_normal'].toString()) : null;
    final int descuento = p['descuento_porcentaje'] ?? 0;
    final double rating = double.tryParse((p['calificacion_promedio'] ?? 0).toString()) ?? 0;
    final String imagen = (p['imagenes'] as List).isNotEmpty ? p['imagenes'][0] : 'https://via.placeholder.com/150';

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
                      image: DecorationImage(image: NetworkImage(imagen), fit: BoxFit.cover),
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
                      Text(p['nombre_producto'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  onPressed: () {
                    CartManager.agregar(p);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto añadido al carrito')));
                  },
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
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _cantidad = 1;
  bool _descripcionExpandida = false;
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final List<String> imagenes = (p['imagenes'] as List).map((e) => e.toString()).toList();
    if (imagenes.isEmpty) imagenes.add('https://via.placeholder.com/400');

    final double precio = double.tryParse((p['precio_oferta'] ?? p['precio_normal']).toString()) ?? 0;
    final double? precioNormal = p['precio_normal'] != null ? double.tryParse(p['precio_normal'].toString()) : null;
    final int descuento = p['descuento_porcentaje'] ?? 0;
    final double subtotal = precio * _cantidad;
    final int stock = p['stock_disponible'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(p['nombre_producto'])),
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
                      Text('Vendido por: ${p['nombre_tienda'] ?? 'Tienda General'}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(' ${p['calificacion_promedio'] ?? 0.0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Nombre
                  Text(p['nombre_producto'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  Text('Stock disponible: $stock', style: TextStyle(color: stock > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
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
                      child: Text(p['descripcion'] ?? 'Sin descripción disponible', style: const TextStyle(fontSize: 16, height: 1.5)),
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
                          IconButton(onPressed: _cantidad < stock ? () => setState(() => _cantidad++) : null, icon: const Icon(Icons.add_circle_outline)),
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
                    onPressed: stock > 0 ? () {
                      CartManager.agregar(p, cantidad: _cantidad);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto añadido al carrito')));
                      Navigator.pop(context);
                    } : null,
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
  String _tipoEnvio = 'NORMAL';
  double _costoEnvio = 10.0;
  final _formKey = GlobalKey<FormState>();
  
  // Controladores del formulario
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _direccionController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _distritoController = TextEditingController();

  Future<void> confirmarPedido(double total) async {
    if (!_formKey.currentState!.validate()) return;
    if (CartManager.items.isEmpty) return;

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${GlobalState.token}',
      },
      body: json.encode({
        'monto_subtotal': CartManager.subtotal,
        'costo_envio': _costoEnvio,
        'monto_total_pagar': CartManager.subtotal + _costoEnvio,
        'tipo_envio': _tipoEnvio,
        'whatsapp_contacto': _whatsappController.text,
        'dni_ruc_comprobante': _dniController.text,
        'direccion_envio': _direccionController.text,
        'items': CartManager.items.map((item) => {
          'producto_id': item.producto['id'],
          'cantidad': item.cantidad,
          'precio_unitario': double.parse((item.producto['precio_oferta'] ?? item.producto['precio_normal']).toString()),
          'subtotal': double.parse((item.producto['precio_oferta'] ?? item.producto['precio_normal']).toString()) * item.cantidad,
        }).toList(),
      }),
    );

    if (response.statusCode == 201) {
      final pedido = json.decode(response.body);
      CartManager.vaciar();
      Navigator.push(context, MaterialPageRoute(builder: (_) => SuccessScreen(pedido: pedido)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GlobalState.token == null) {
      return const Center(child: Text('Inicia sesión para ver tu carrito'));
    }

    final items = CartManager.items;
    if (items.isEmpty) {
      return const Center(child: Text('Tu carrito está vacío'));
    }

    double subtotal = CartManager.subtotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Carrito')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final p = item.producto;
                final String imagen = (p['imagenes'] as List).isNotEmpty ? p['imagenes'][0] : 'https://via.placeholder.com/150';
                final double precio = double.tryParse((p['precio_oferta'] ?? p['precio_normal']).toString()) ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Image.network(imagen, width: 50, fit: BoxFit.cover),
                    title: Text(p['nombre_producto']),
                    subtitle: Text('S/ ${precio.toStringAsFixed(2)} c/u'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                            if (item.cantidad > 1) {
                              item.cantidad--;
                            } else {
                              CartManager.items.removeAt(index);
                            }
                          }),
                        ),
                        Text('${item.cantidad}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => item.cantidad++),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
                
                // Tipos de Envío
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selecciona tipo de envío:', style: TextStyle(fontWeight: FontWeight.bold)),
                      RadioListTile<String>(
                        title: const Text('Envío Express (En 2 horas)'),
                        subtitle: const Text('+ S/ 15.00 (Lima Centro)'),
                        value: 'EXPRESS',
                        groupValue: _tipoEnvio,
                        onChanged: (String? val) => setState(() { _tipoEnvio = val!; _costoEnvio = 15.0; }),
                      ),
                      RadioListTile<String>(
                        title: const Text('Envío Normal (2-3 días hábiles)'),
                        subtitle: const Text('+ S/ 10.00'),
                        value: 'NORMAL',
                        groupValue: _tipoEnvio,
                        onChanged: (String? val) => setState(() { _tipoEnvio = val!; _costoEnvio = 10.0; }),
                      ),
                      RadioListTile<String>(
                        title: const Text('Envío Gratis (Compras > S/ 200)'),
                        subtitle: const Text('S/ 0.00'),
                        value: 'GRATIS',
                        groupValue: _tipoEnvio,
                        onChanged: subtotal > 200 ? (String? val) => setState(() { _tipoEnvio = val!; _costoEnvio = 0.0; }) : null,
                      ),
                    ],
                  ),
                ),

                // Formulario de Confirmación
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text('Datos de Entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombres y Apellidos'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                        TextFormField(controller: _dniController, decoration: const InputDecoration(labelText: 'DNI / RUC'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                        TextFormField(controller: _whatsappController, decoration: const InputDecoration(labelText: 'WhatsApp de contacto'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                        TextFormField(controller: _direccionController, decoration: const InputDecoration(labelText: 'Dirección de envío'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                        TextFormField(controller: _referenciaController, decoration: const InputDecoration(labelText: 'Referencia'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                        TextFormField(controller: _distritoController, decoration: const InputDecoration(labelText: 'Distrito'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                      ],
                    ),
                  ),
                ),

                // Resumen y Botón
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:'), Text('S/ ${subtotal.toStringAsFixed(2)}')]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Envío:'), Text('S/ ${_costoEnvio.toStringAsFixed(2)}')]),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL A PAGAR:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('S/ ${(subtotal + _costoEnvio).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => confirmarPedido(subtotal),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        child: const Text('CONFIRMAR PEDIDO Y PAGAR'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

// --- PANTALLA DE ÉXITO ---
class SuccessScreen extends StatelessWidget {
  final dynamic pedido;
  const SuccessScreen({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text('¡Gracias por tu compra!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Pedido #${pedido['id']} generado con éxito.', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200)),
                child: Column(
                  children: [
                    const Text('Frase motivacional para ti:', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    Text('"${pedido['frase_motivacional']}"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('VOLVER AL INICIO'),
              ),
            ],
          ),
        ),
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
  final TextEditingController _referralController = TextEditingController();

  Future<void> login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        body: {'username': _userController.text, 'password': _passController.text},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        GlobalState.token = data['access'];
        await GlobalState.fetchUserData();
        setState(() {});
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
          'correo_electronico': '${_userController.text}@example.com',
          'nombre_completo': _userController.text,
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

  Future<void> canjearReferido() async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/canjear_referido/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${GlobalState.token}',
      },
      body: json.encode({'codigo': _referralController.text}),
    );
    final data = json.decode(response.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? data['error'])));
    if (response.statusCode == 200) {
      await GlobalState.fetchUserData();
      setState(() {});
    }
  }

  Future<List> obtenerPedidos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/pedidos/'),
      headers: {'Authorization': 'Bearer ${GlobalState.token}'},
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    return [];
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

    final u = GlobalState.usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido, ${u?['nombre_completo'] ?? u?['username']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Saldo Disponible: S/ ${u?['saldo_disponible']}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            
            // Sección Referidos
            const Text('Sistema de Referidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Tu código único: ${u?['codigo_referido_propio']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _referralController, decoration: const InputDecoration(hintText: 'Ingresa código de amigo'))),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: canjearReferido, child: const Text('Canjear')),
              ],
            ),
            const Divider(height: 30),

            // Historial de Pedidos
            const Text('Mis Pedidos Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FutureBuilder<List>(
              future: obtenerPedidos(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('No tienes pedidos aún.');
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final p = snapshot.data![index];
                    return Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            Text('Pedido #${p['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getColorEstado(p['estado_pedido'] ?? 'pendiente'),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                (p['estado_pedido'] ?? 'pendiente').toString().toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text('Total: S/ ${p['monto_total_pagar']} - ${p['fecha_pedido'].toString().substring(0, 10)}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => setState(() {
                GlobalState.token = null;
                GlobalState.usuario = null;
              }),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Cerrar Sesión'),
            )
          ],
        ),
      ),
    );
  }

  Color _getColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange;
      case 'pagado': return Colors.blue;
      case 'enviado': return Colors.purple;
      case 'entregado': return Colors.green;
      default: return Colors.grey;
    }
  }
}
