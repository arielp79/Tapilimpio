import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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

class ListaOrdenesOperador extends StatelessWidget {
  const ListaOrdenesOperador({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Servicios Pendientes"),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('ordenes')
            .where('estado', isEqualTo: 'pendiente')
            .orderBy('turno', descending: false) // Ordena por fecha de turno
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay servicios asignados."));
          }

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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${data['direccion']}\n${data['ciudad']}"),
                      if (data['turno'] != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "Turno: ${(data['turno'] as Timestamp).toDate().day}/"
                              "${(data['turno'] as Timestamp).toDate().month} - "
                              "${(data['turno'] as Timestamp).toDate().hour}:"
                              "${(data['turno'] as Timestamp).toDate().minute.toString().padLeft(2, '0')} hs",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

  // FUNCIÓN PARA ABRIR GOOGLE MAPS
  void _abrirMapa(String direccion, String ciudad) async {
    // Limpiamos la dirección para que sea una búsqueda válida
    String query = Uri.encodeComponent("$direccion, $ciudad");
    String googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$query";
    String appleMapsUrl = "https://maps.apple.com/?q=$query";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(
        Uri.parse(googleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(
        Uri.parse(appleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _abrirWhatsApp(String telefono, String cliente, String direccion) async {
    String mensaje =
        "Hola $cliente, soy de Tapilimpio. Estoy en camino a tu domicilio en $direccion.";
    var url = "https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    List trabajos = orden['trabajos'] ?? [];
    double total = trabajos.fold(
      0.0,
      (sum, item) => sum + ((item['precio'] ?? 0) * (item['cantidad'] ?? 1)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Información del Trabajo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              orden['cliente_nombre'] ?? 'Cliente',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // BOTÓN WHATSAPP
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

            // DIRECCIÓN CLICKEABLE
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
                              fontWeight: FontWeight.w500,
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
              "A COBRAR: \$${total.toStringAsFixed(0)}",
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
                onPressed: () {
                  FirebaseFirestore.instance
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
