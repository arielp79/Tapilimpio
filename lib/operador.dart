import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAs4jJqJTRluGFqEd2xnYQJW6qftGeRBmI",
      authDomain: "tapilimpio-7b263.firebaseapp.com",
      projectId: "tapilimpio-7b263",
      storageBucket: "tapilimpio-7b263.firebasestorage.app",
      messagingSenderId: "594990305829",
      appId: "1:594990305829:web:13061c6713de14aa49e5cc",
      measurementId: "G-K97DY67V3Z",
    ),
  );
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ListaOrdenesOperador(),
    ),
  );
}

class ListaOrdenesOperador extends StatefulWidget {
  const ListaOrdenesOperador({super.key});

  @override
  State<ListaOrdenesOperador> createState() => _ListaOrdenesOperadorState();
}

class _ListaOrdenesOperadorState extends State<ListaOrdenesOperador> {
  String? miNombre;

  @override
  void initState() {
    super.initState();
    _cargarIdentidad();
  }

  Future<void> _cargarIdentidad() async {
    final prefs = await SharedPreferences.getInstance();
    String? nombreGuardado = prefs.getString('nombre_operador');

    if (nombreGuardado == null) {
      _pedirNombre();
    } else {
      setState(() => miNombre = nombreGuardado);
      _actualizarToken(nombreGuardado);
    }
  }

  void _pedirNombre() {
    TextEditingController _nameCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Identificación de Operador"),
        content: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            hintText: "Tu nombre exacto (ej: Juan)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_nameCtrl.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('nombre_operador', _nameCtrl.text);
                setState(() => miNombre = _nameCtrl.text);
                Navigator.pop(context);
                _actualizarToken(_nameCtrl.text);
              }
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarToken(String nombre) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    String? token = await messaging.getToken();

    if (token != null) {
      var query = await FirebaseFirestore.instance
          .collection('operadores')
          .where('nombre', isEqualTo: nombre)
          .get();

      for (var doc in query.docs) {
        await doc.reference.update({'fcmToken': token});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          miNombre == null ? "Identificando..." : "Órdenes de $miNombre",
        ),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: miNombre == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('ordenes')
                  .where('estado', isEqualTo: 'pendiente')
                  .where('operador', isEqualTo: miNombre)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text("No tienes servicios asignados."),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          data['cliente_nombre'] ?? 'Sin Nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${data['direccion']}\n${data['ciudad']}",
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.blueGrey,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetalleSoloLectura(orden: data, docId: doc.id),
                          ),
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

class DetalleSoloLectura extends StatelessWidget {
  final Map<String, dynamic> orden;
  final String docId;

  const DetalleSoloLectura({
    super.key,
    required this.orden,
    required this.docId,
  });

  void _abrirMapa(String direccion, String ciudad) async {
    String query = Uri.encodeComponent("$direccion, $ciudad");
    Uri url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _abrirWhatsApp(String telefono, String cliente, String direccion) async {
    String mensaje =
        "Hola $cliente, soy de Tapilimpio. Estoy en camino a tu domicilio en $direccion.";
    Uri url = Uri.parse(
      "https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}",
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Manejo seguro de la lista de trabajos
    final List trabajos = orden['trabajos'] is List ? orden['trabajos'] : [];

    // 2. Cálculo del total (Reemplaza al .fold que fallaba)
    double totalCalculado = 0.0;
    for (var item in trabajos) {
      double p = (item['precio'] ?? 0).toDouble();
      int c = (item['cantidad'] ?? 1);
      totalCalculado += (p * c);
    }

    // 3. Manejo de Fecha y Turno (Lo que pediste mostrar)
    String fechaTexto = "Sin fecha";
    if (orden['turno'] != null && orden['turno'] is Timestamp) {
      DateTime dt = (orden['turno'] as Timestamp).toDate();
      fechaTexto =
          "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}hs";
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Información del Trabajo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RECUADRO DE FECHA Y TURNO
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    "📅 FECHA Y HORA ASIGNADA",
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                  ),
                  Text(
                    fechaTexto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              orden['cliente_nombre'] ?? 'Cliente',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.message, color: Colors.white),
              label: Text(
                "WhatsApp: ${orden['cliente_telefono']}",
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: () => _abrirWhatsApp(
                orden['cliente_telefono'] ?? "",
                orden['cliente_nombre'] ?? "",
                orden['direccion'] ?? "",
              ),
            ),

            const Divider(height: 40),

            const Text(
              "📍 DIRECCIÓN (Toca para ir con GPS)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () =>
                  _abrirMapa(orden['direccion'] ?? "", orden['ciudad'] ?? ""),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.blueAccent),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${orden['direccion']}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            "Piso: ${orden['piso'] ?? '-'} | Depto: ${orden['depto'] ?? '-'}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "🏙️ ${orden['ciudad']}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              "📝 TRABAJOS:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...trabajos
                .map(
                  (t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("${t['tipo']} (x${t['cantidad']})"),
                    trailing: Text("\$${t['precio']}"),
                  ),
                )
                .toList(),

            const Divider(),
            Text(
              "A COBRAR: \$${totalCalculado.toStringAsFixed(0)}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.all(15),
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('ordenes')
                      .doc(docId)
                      .update({'estado': 'completado'});
                  Navigator.pop(context);
                },
                child: const Text(
                  "FINALIZAR SERVICIO",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
