import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:responsive_framework/responsive_framework.dart';

// -----------------------------------------------------------------------------
// 1. Inicialización y Constantes Globales
// -----------------------------------------------------------------------------

final supabase = Supabase.instance.client;
final logger = Logger();

// -----------------------------------------------------------------------------
// 2. Modelos de Datos
// -----------------------------------------------------------------------------

class Product {
  final int id;
  final String name;
  final int code;
  final double price;
  final int quantity;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      code: (map['code'] as int?) ?? 0,
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as int?) ?? 0,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

class SoldProduct {
  final Product product;
  int quantityToSell;

  SoldProduct({required this.product, this.quantityToSell = 1});

  double get subtotal => product.price * quantityToSell;
}

// -----------------------------------------------------------------------------
// 3. Widget Principal (MyApp y SplashScreen)
// -----------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://txhnduxjuaswjocrdymg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4aG5kdXhqdWFzd2pvY3JkeW1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMzAxMzQsImV4cCI6MjA3NTYwNjEzNH0.uWXMEnaJpLFjdA1ZwJNdMNh-c93ohfnb1vzCcYMWeKQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ferretería GNA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: Theme.of(context).textTheme.copyWith(
          bodyLarge: const TextStyle(fontSize: 16),
          bodyMedium: const TextStyle(fontSize: 14),
          headlineSmall: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 🚨 Implementación de Responsive Framework 🚨
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
      ),

      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProductListScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.blue),
            Text('Ferretería GNA', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Pantalla de Listado de Productos (ProductListScreen)
// -----------------------------------------------------------------------------

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});
  static const String bucketName = 'ferreteria_GNA';

  static final currencyFormat = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product> _allProducts = [];
  List<Product> _products = [];
  List<SoldProduct> _selectedProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _columnsToFetch = [
    'id',
    'name',
    'code',
    'price',
    'quantity',
    'imageUrl',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterProducts();
    });
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _products = List.from(_allProducts);
    } else {
      _products = _allProducts.where((product) {
        final nameLower = product.name.toLowerCase();
        final codeString = product.code.toString();

        return nameLower.contains(_searchQuery) ||
            codeString.contains(_searchQuery);
      }).toList();
    }
    _sortProducts();
  }

  void _sortProducts() {
    _products.sort((a, b) {
      final nameComparison = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );

      if (nameComparison != 0) {
        return nameComparison;
      }
      return a.code.compareTo(b.code);
    });
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> data = await supabase
          .from('ferreteria_GNA')
          .select(_columnsToFetch.join(','))
          .order('id');

      _allProducts = data.map(Product.fromMap).toList();
      _products = List.from(_allProducts);
      _sortProducts();
    } on PostgrestException catch (e) {
      logger.e('Error al cargar productos: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: ${e.message}')),
        );
      }
    } catch (e) {
      logger.e('Error desconocido al cargar productos: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _selectedProducts.removeWhere(
          (soldP) => !_allProducts.any((p) => p.id == soldP.product.id),
        );
      });
    }
  }

  void _addProductToList(Product newProduct) {
    setState(() {
      _allProducts.add(newProduct);
      _filterProducts();
    });
  }

  void _updateProductInList(Product updatedProduct) {
    setState(() {
      final allIndex = _allProducts.indexWhere(
        (p) => p.id == updatedProduct.id,
      );
      if (allIndex != -1) {
        _allProducts[allIndex] = updatedProduct;
      }

      final selectedIndex = _selectedProducts.indexWhere(
        (sp) => sp.product.id == updatedProduct.id,
      );
      if (selectedIndex != -1) {
        _selectedProducts[selectedIndex] = SoldProduct(
          product: updatedProduct,
          quantityToSell: _selectedProducts[selectedIndex].quantityToSell,
        );
      }

      _filterProducts();
    });
  }

  String getPublicImageUrl(String fileName) {
    final url = supabase.storage
        .from(ProductListScreen.bucketName)
        .getPublicUrl(fileName);
    return url;
  }

  void _toggleSelection(Product product) {
    setState(() {
      final existingSoldProductIndex = _selectedProducts.indexWhere(
        (p) => p.product.id == product.id,
      );

      if (existingSoldProductIndex != -1) {
        _selectedProducts.removeAt(existingSoldProductIndex);
      } else {
        if (product.quantity > 0) {
          _selectedProducts.add(
            SoldProduct(product: product, quantityToSell: 1),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto sin stock disponible.')),
          );
        }
      }
    });
  }

  double get _totalPrice {
    return _selectedProducts.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Future<void> _finalizeSale() async {
    if (_selectedProducts.isEmpty) return;

    setState(() => _isLoading = true);

    final totalSale = _totalPrice;

    final inventoryUpdates = _selectedProducts.map((soldP) {
      final newQuantity = soldP.product.quantity - soldP.quantityToSell;

      return supabase
          .from('ferreteria_GNA')
          .update({'quantity': newQuantity})
          .eq('id', soldP.product.id);
    }).toList();

    final saleInserts = _selectedProducts.map((soldP) {
      return {
        'name': soldP.product.name,
        'quantity': soldP.quantityToSell,
        'price': soldP.product.price,
        'total': soldP.subtotal,
      };
    }).toList();

    try {
      await Future.wait(inventoryUpdates);
      await supabase.from('sales_GNA').insert(saleInserts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Venta finalizada con éxito. Total: ${ProductListScreen.currencyFormat.format(totalSale)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Actualización LOCAL de stock
      for (var soldP in _selectedProducts) {
        final newQuantity = soldP.product.quantity - soldP.quantityToSell;
        final updatedProduct = Product(
          id: soldP.product.id,
          name: soldP.product.name,
          code: soldP.product.code,
          price: soldP.product.price,
          quantity: newQuantity,
          imageUrl: soldP.product.imageUrl,
        );
        _updateProductInList(updatedProduct);
      }

      setState(() {
        _selectedProducts = [];
      });
    } on PostgrestException catch (e) {
      logger.e('Error en la transacción de venta: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar la venta: ${e.message}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar el producto "${product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          await supabase.storage.from(ProductListScreen.bucketName).remove([
            product.imageUrl!,
          ]);
        }

        await supabase.from('ferreteria_GNA').delete().eq('id', product.id);

        setState(() {
          _allProducts.removeWhere((p) => p.id == product.id);
          _selectedProducts.removeWhere((sp) => sp.product.id == product.id);
          _filterProducts();
        });

        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          CachedNetworkImage.evictFromCache(
            getPublicImageUrl(product.imageUrl!),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto "${product.name}" eliminado.')),
          );
        }
      } on PostgrestException catch (e) {
        logger.e('Error al eliminar producto: ${e.message}');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error DB: ${e.message}')));
        }
      } catch (e) {
        logger.e('Error desconocido al eliminar: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelectionDetails() {
    if (_selectedProducts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final modalTotal = _selectedProducts.fold(
              0.0,
              (sum, item) => sum + item.subtotal,
            );

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle de Venta (Total: ${ProductListScreen.currencyFormat.format(modalTotal)})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _selectedProducts.length,
                      itemBuilder: (context, index) {
                        final soldProduct = _selectedProducts[index];
                        final product = soldProduct.product;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Precio Unit: ${ProductListScreen.currencyFormat.format(product.price)} | Stock: ${product.quantity} | Subtotal: ${ProductListScreen.currencyFormat.format(soldProduct.subtotal)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.blue,
                                ),
                                onPressed: soldProduct.quantityToSell > 1
                                    ? () {
                                        modalSetState(() {
                                          setState(() {
                                            soldProduct.quantityToSell--;
                                          });
                                        });
                                      }
                                    : null,
                              ),
                              Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Text(
                                  '${soldProduct.quantityToSell}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.blue,
                                ),
                                onPressed:
                                    soldProduct.quantityToSell <
                                        product.quantity
                                    ? () {
                                        modalSetState(() {
                                          setState(() {
                                            soldProduct.quantityToSell++;
                                          });
                                        });
                                      }
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  modalSetState(() {
                                    setState(() {
                                      _selectedProducts.removeAt(index);
                                    });
                                  });
                                  if (_selectedProducts.isEmpty) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _finalizeSale();
                      },
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text(
                        'Aceptar',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  AppBar get _appBar {
    if (_selectedProducts.isNotEmpty) {
      return AppBar(
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => setState(() => _selectedProducts = []),
        ),
        title: GestureDetector(
          onTap: _showSelectionDetails,
          child: Text(
            'Total Seleccionado: ${ProductListScreen.currencyFormat.format(_totalPrice)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: _selectedProducts.length == 1
                  ? Colors.white
                  : Colors.grey[400],
            ),
            onPressed: _selectedProducts.length == 1
                ? () async {
                    final productToEdit = _selectedProducts.first.product;
                    final Product? updatedProduct = await Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductFormScreen(product: productToEdit),
                          ),
                        );
                    if (updatedProduct != null) {
                      if (updatedProduct.imageUrl != null) {
                        CachedNetworkImage.evictFromCache(
                          getPublicImageUrl(updatedProduct.imageUrl!),
                        );
                      }
                      _updateProductInList(updatedProduct);
                    }
                    setState(
                      () => _selectedProducts = [],
                    ); // Limpiar la selección después de editar
                  }
                : null,
          ),
        ],
      );
    }

    return AppBar(
      title: const Center(
        child: Text(
          'Ferretería GNA',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_toggle_off),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SalesHistoryScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProductIds = _selectedProducts
        .map((p) => p.product.id)
        .toSet();

    final responsive = ResponsiveBreakpoints.of(context);

    int crossAxisCount;
    double childAspectRatio;

    if (responsive.isMobile) {
      crossAxisCount = 2;
      // 🚨 AJUSTE FINAL 1: 0.55 (Móvil) - Compacto, resuelve el espacio de sobra.
      childAspectRatio = 0.70;
    } else if (responsive.isTablet) {
      crossAxisCount = 3;
      // 🚨 AJUSTE FINAL 2: 0.58 (Tablet) - Le da más altura para el texto de dos líneas, junto con la reducción de fuente.
      childAspectRatio = 0.65;
    } else {
      crossAxisCount = 4;
      // Ajuste para 4 columnas.
      childAspectRatio = 0.76;
    }

    return Scaffold(
      appBar: _appBar,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchProducts,
                    child: _products.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No hay productos en la base de datos.'
                                  : 'No se encontraron productos con el término "$_searchQuery".',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: childAspectRatio,
                                ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final isSelected = selectedProductIds.contains(
                                product.id,
                              );

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  return ProductCard(
                                    product: product,
                                    getPublicImageUrl: getPublicImageUrl,
                                    isSelected: isSelected,
                                    onLongPress: () =>
                                        _toggleSelection(product),
                                    onEdit: () async {
                                      final Product? updatedProduct =
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ProductFormScreen(
                                                    product: product,
                                                  ),
                                            ),
                                          );
                                      if (updatedProduct != null) {
                                        if (updatedProduct.imageUrl != null) {
                                          CachedNetworkImage.evictFromCache(
                                            getPublicImageUrl(
                                              updatedProduct.imageUrl!,
                                            ),
                                          );
                                        }
                                        _updateProductInList(updatedProduct);
                                      }
                                    },
                                    onDelete: () => _deleteProduct(product),
                                    cardWidth: constraints.maxWidth,
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Product? newProduct = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProductFormScreen()),
          );
          if (newProduct != null) {
            _addProductToList(newProduct);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Widget de Tarjeta de Producto (ProductCard)
// -----------------------------------------------------------------------------

class ProductCard extends StatelessWidget {
  final Product product;
  final String Function(String) getPublicImageUrl;
  final bool isSelected;
  final VoidCallback onLongPress;
  final Future<void> Function() onEdit;
  final VoidCallback onDelete;
  final double cardWidth;

  const ProductCard({
    super.key,
    required this.product,
    required this.getPublicImageUrl,
    required this.isSelected,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.cardWidth,
  });

  void _navigateToEdit(BuildContext context) {
    onEdit();
  }

  void _navigateToImageView(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ImageViewScreen(imageUrl: imageUrl, productName: product.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = product.imageUrl != null
        ? getPublicImageUrl(product.imageUrl!)
        : null;

    final bool outOfStock = product.quantity <= 0;

    // Obtener el contexto responsivo
    final responsive = ResponsiveBreakpoints.of(context);

    // 🚨 AJUSTE CLAVE: Reducir el tamaño del nombre cuando hay más columnas (tablet/desktop)
    // El modo móvil vertical (2 columnas) sigue con 19pt; Tablet/Horizontal (3+ columnas) baja a 17pt.
    final double nameFontSize = responsive.isMobile ? 19 : 17;

    // Altura de la imagen reducida al 50% del ancho para maximizar espacio de texto
    final double imageSectionHeight = cardWidth * 0.50;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: isSelected ? onLongPress : () => _navigateToEdit(context),
      child: Card(
        color: outOfStock ? Colors.grey[200] : null,
        elevation: isSelected ? 8 : 4,
        shape: isSelected
            ? RoundedRectangleBorder(
                side: const BorderSide(color: Colors.blue, width: 3.0),
                borderRadius: BorderRadius.circular(8.0),
              )
            : null,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () {
                    if (imageUrl != null) {
                      _navigateToImageView(context, imageUrl);
                    }
                  },
                  child: Container(
                    height: imageSectionHeight,
                    padding: const EdgeInsets.all(2.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.red,
                                    ),
                                  ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: nameFontSize,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 1),
                      Text(
                        'Código: ${product.code}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),

                      Text(
                        'Stock: ${product.quantity}',
                        style: TextStyle(
                          fontSize: 18,
                          color: outOfStock ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ProductListScreen.currencyFormat.format(
                            product.price,
                          ),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isSelected)
              Positioned(
                top: 5,
                right: 5,
                child: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.8),
                  radius: 12,
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              )
            else
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: onDelete,
                ),
              ),

            if (outOfStock)
              const Positioned.fill(
                child: Center(
                  child: Text(
                    'SIN STOCK',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Color.fromRGBO(255, 255, 255, 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. Pantallas de Auxiliares
// -----------------------------------------------------------------------------

class ImageViewScreen extends StatelessWidget {
  final String imageUrl;
  final String productName;

  const ImageViewScreen({
    super.key,
    required this.imageUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(productName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, size: 100, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  XFile? _image;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _codeController.text = widget.product!.code.toString();
      _priceController.text = widget.product!.price.toString();
      _quantityController.text = widget.product!.quantity.toString();
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Fuente de Imagen'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Cámara'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galería'),
          ),
        ],
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = pickedFile;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);
      String? newFileName = widget.product?.imageUrl;
      String? oldFileName = widget.product?.imageUrl;

      if (_image != null) {
        final fileExtension = _image!.path.split('.').last;
        newFileName = '${DateTime.now().microsecondsSinceEpoch}.$fileExtension';

        try {
          // ⚙️ INICIO: LÓGICA DE REDIMENSIONAMIENTO ⚙️
          final rawBytes = await _image!.readAsBytes();
          final originalImage = img.decodeImage(rawBytes);

          if (originalImage == null) {
            throw Exception('No se pudo decodificar la imagen.');
          }

          img.Image resizedImage = originalImage;
          // Redimensionar si el ancho es mayor a 800px
          if (originalImage.width > 800) {
            resizedImage = img.copyResize(originalImage, width: 800);
          }

          // Comprimir a JPEG con calidad 85
          final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
          // ⚙️ FIN: LÓGICA DE REDIMENSIONAMIENTO ⚙️

          await supabase.storage
              .from(ProductListScreen.bucketName)
              .uploadBinary(
                newFileName,
                compressedBytes,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );

          if (oldFileName != null &&
              oldFileName.isNotEmpty &&
              oldFileName != newFileName) {
            await supabase.storage.from(ProductListScreen.bucketName).remove([
              oldFileName,
            ]);
            logger.i('Imagen antigua eliminada: $oldFileName');
          }
        } on StorageException catch (e) {
          logger.e('⛔ Error en Storage al subir/eliminar: ${e.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al subir imagen: ${e.message}')),
            );
          }
          setState(() => _isSaving = false);
          return;
        } catch (e) {
          logger.e('⛔ Error desconocido en imagen: $e');
          setState(() => _isSaving = false);
          return;
        }
      }

      final productData = {
        'name': _nameController.text,
        'code': int.parse(_codeController.text),
        'price': double.parse(_priceController.text),
        'quantity': int.parse(_quantityController.text),
        'imageUrl': newFileName,
      };

      const List<String> columnsToFetch = [
        'id',
        'name',
        'code',
        'price',
        'quantity',
        'imageUrl',
      ];

      try {
        if (widget.product == null) {
          final List<Map<String, dynamic>> result = await supabase
              .from('ferreteria_GNA')
              .insert(productData)
              .select(columnsToFetch.join(','));

          if (mounted) {
            Navigator.of(context).pop(Product.fromMap(result.first));
          }
        } else {
          final List<Map<String, dynamic>> result = await supabase
              .from('ferreteria_GNA')
              .update(productData)
              .eq('id', widget.product!.id)
              .select(columnsToFetch.join(','));

          if (mounted) {
            Navigator.of(context).pop(Product.fromMap(result.first));
          }
        }
      } on PostgrestException catch (e) {
        logger.e('Error al guardar/actualizar producto: ${e.message}');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error DB: ${e.message}')));
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            widget.product == null ? 'Agregar Producto' : 'Editar Producto',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 250,
                        width: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildImagePreview(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(fontSize: 18),
                      ),
                      style: const TextStyle(fontSize: 18),
                      validator: (value) =>
                          value!.isEmpty ? 'Ingresa un nombre' : null,
                    ),

                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Código (Número)',
                        labelStyle: TextStyle(fontSize: 18),
                      ),
                      style: const TextStyle(fontSize: 18),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Ingresa el código';
                        }

                        if (int.tryParse(value) == null) {
                          return 'Debe ser un número entero';
                        }

                        return null;
                      },
                    ),

                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad (Stock)',
                        labelStyle: TextStyle(fontSize: 18),
                      ),
                      style: const TextStyle(fontSize: 18),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Ingresa la cantidad';
                        }

                        if (int.tryParse(value) == null) {
                          return 'Debe ser un número entero';
                        }

                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio (ej: 10000.00)',
                        labelStyle: TextStyle(fontSize: 18),
                      ),
                      style: const TextStyle(fontSize: 18),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Ingresa un precio';
                        }

                        if (double.tryParse(value) == null) {
                          return 'Formato inválido';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(
                        widget.product == null ? 'Guardar' : 'Actualizar',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePreview() {
    if (_image != null) {
      return FutureBuilder<Uint8List>(
        future: _image!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else if (widget.product?.imageUrl != null) {
      final imageUrl = supabase.storage
          .from(ProductListScreen.bucketName)
          .getPublicUrl(widget.product!.imageUrl!);

      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.red),
        ),
      );
    } else {
      return const Center(
        child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// 7. Pantalla de Historial de Ventas (SalesHistoryScreen)
// -----------------------------------------------------------------------------

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> data = await supabase
          .from('sales_GNA')
          .select('id, name, quantity, price, total, created_at')
          .order('created_at', ascending: false);

      _sales = data;
    } on PostgrestException catch (e) {
      logger.e('Error al cargar historial de ventas: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: ${e.message}')),
        );
      }
    } catch (e) {
      logger.e('Error desconocido al cargar ventas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoDate) {
    try {
      final DateTime date = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Fecha Inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
          ? const Center(
              child: Text(
                'No hay ventas registradas aún.',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _sales.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = _sales[index];
                final String formattedPrice = ProductListScreen.currencyFormat
                    .format(sale['price']);
                final String formattedTotal = ProductListScreen.currencyFormat
                    .format(sale['total']);
                final String formattedDate = _formatDate(sale['created_at']);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  leading: CircleAvatar(
                    child: Text(
                      '${sale['quantity']}x',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    sale['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Precio Unitario: $formattedPrice\nFecha: $formattedDate',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                      Text(
                        formattedTotal,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
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
