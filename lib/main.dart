import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Asegurate de tener esto en pubspec.yaml

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
      home: AdminTapilimpio(),
    ),
  );
}

class AdminTapilimpio extends StatefulWidget {
  const AdminTapilimpio({super.key});

  @override
  State<AdminTapilimpio> createState() => _AdminTapilimpioState();
}

class _AdminTapilimpioState extends State<AdminTapilimpio> {
  Future<void> _guardarEnFirebase() async {
    if (operadorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ ERROR: Debes seleccionar un OPERADOR"),
          backgroundColor: Colors.red,
        ),
      );
      return; // Cancela el guardado
    }

    await FirebaseFirestore.instance.collection('ordenes').add({
      'cliente_nombre': _nombreController.text,
      'cliente_telefono': _telefonoController.text,
      'operador': operadorSeleccionado,
      'ciudad': ciudadSeleccionada,
      'direccion': _direccionController.text,
      'piso': _pisoController.text,
      'depto': _deptoController.text,
      'estado': 'pendiente',
      'fecha': DateTime.now(), // Fecha de creación para registro
      'trabajos': trabajosAgregados,
      // USA ESTE NOMBRE para que coincida con tu índice:
      'turno': Timestamp.fromDate(
        DateTime(
          fechaSeleccionada.year,
          fechaSeleccionada.month,
          fechaSeleccionada.day,
          horaSeleccionada.hour,
          horaSeleccionada.minute,
        ),
      ),
    });
  }

  LatLng _ubicacionSeleccionada = const LatLng(-38.9333, -67.9833);
  GoogleMapController? mapController;
  bool _mapaExpandido = false;
  String? operadorSeleccionado;
  String? ciudadSeleccionada;
  List<Map<String, dynamic>> trabajosAgregados = [];

  final List<String> operadores = ['Juan', 'Pedro', 'Maria'];
  final List<String> ciudades = [
    'Cipolletti',
    'Neuquén',
    'General Roca',
    'Fernández Oro',
  ];
  final List<String> catalogoTrabajos = [
    'Auto Full',
    'Auto SemiFull',
    'Auto Básico',
    'Alfombra Decorativa',
    'Alfombra x m2',
    'Sillas con respaldo',
    'Sillas sin respaldo',
    'Sillón',
    'Colchón 1 plaza',
    'Colchón 1 plaza y media',
    'Colchón 2 plazas',
  ];

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _pisoController = TextEditingController();
  final TextEditingController _deptoController = TextEditingController();

  DateTime fechaSeleccionada = DateTime.now();
  TimeOfDay horaSeleccionada = TimeOfDay.now();

  Future<void> _ubicarCliente(String texto) async {
    if (texto.contains("q=")) {
      try {
        final partes = texto.split("q=")[1].split("&")[0].split(",");
        double lat = double.parse(partes[0]);
        double lng = double.parse(partes[1]);
        setState(() {
          _ubicacionSeleccionada = LatLng(lat, lng);
          _mapaExpandido = true;
        });
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_ubicacionSeleccionada, 17),
        );
        return;
      } catch (e) {
        debugPrint("Error link");
      }
    }
    if (texto.length > 6) {
      try {
        String busqueda =
            "$texto, ${ciudadSeleccionada ?? 'Cipolletti'}, Rio Negro, Argentina";
        List<Location> locations = await locationFromAddress(busqueda);
        if (locations.isNotEmpty) {
          var loc = locations.first;
          setState(() {
            _ubicacionSeleccionada = LatLng(loc.latitude, loc.longitude);
            _mapaExpandido = true;
          });
          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_ubicacionSeleccionada, 16),
          );
        }
      } catch (e) {}
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (picked != null && picked != fechaSeleccionada) {
      setState(() => fechaSeleccionada = picked);
    }
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada,
    );
    if (picked != null && picked != horaSeleccionada) {
      setState(() => horaSeleccionada = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tapilimpio - Nueva Orden"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ListaOrdenes()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GestionOperadores(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _mapaExpandido = !_mapaExpandido),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: _mapaExpandido ? 250 : 100,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _ubicacionSeleccionada,
                  zoom: 14,
                ),
                onMapCreated: (controller) => mapController = controller,
                onTap: (pos) => setState(() => _ubicacionSeleccionada = pos),
                markers: {
                  Marker(
                    markerId: const MarkerId("seleccion"),
                    position: _ubicacionSeleccionada,
                  ),
                },
                zoomControlsEnabled: false,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: "Nombre del Cliente",
                  ),
                ),
                TextField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Teléfono"),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('operadores')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const CircularProgressIndicator();
                    var docs = snapshot.data!.docs;

                    return DropdownButtonFormField(
                      value: operadorSeleccionado,
                      decoration: const InputDecoration(labelText: "Operador"),
                      items: docs.map((e) {
                        return DropdownMenuItem(
                          value: e['nombre'].toString(),
                          child: Text(e['nombre'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => operadorSeleccionado = val as String?),
                    );
                  },
                ),
                DropdownButtonFormField(
                  value: ciudadSeleccionada,
                  decoration: const InputDecoration(labelText: "Ciudad"),
                  items: ciudades
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => ciudadSeleccionada = val as String?),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _direccionController,
                        onChanged: (val) => _ubicarCliente(val),
                        decoration: const InputDecoration(
                          labelText: "Dirección",
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.location_searching),
                      onPressed: () =>
                          _ubicarCliente(_direccionController.text),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pisoController,
                        decoration: const InputDecoration(labelText: "Piso"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _deptoController,
                        decoration: const InputDecoration(labelText: "Depto"),
                      ),
                    ),
                  ],
                ),

                const Text(
                  "Programar Servicio:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          "${fechaSeleccionada.day}/${fechaSeleccionada.month}/${fechaSeleccionada.year}",
                        ),
                        onPressed: () async {
                          DateTime? p = await showDatePicker(
                            context: context,
                            initialDate: fechaSeleccionada,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2027),
                          );
                          if (p != null) setState(() => fechaSeleccionada = p);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(horaSeleccionada.format(context)),
                        onPressed: () async {
                          TimeOfDay? t = await showTimePicker(
                            context: context,
                            initialTime: horaSeleccionada,
                          );
                          if (t != null) setState(() => horaSeleccionada = t);
                        },
                      ),
                    ),
                  ],
                ),

                const Divider(height: 30),
                ...trabajosAgregados.asMap().entries.map((entry) {
                  int idx = entry.key;
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButton(
                          value: trabajosAgregados[idx]["tipo"],
                          items: catalogoTrabajos
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) => setState(
                            () => trabajosAgregados[idx]["tipo"] = val,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 40,
                        child: TextField(
                          decoration: const InputDecoration(labelText: "Cant"),
                          keyboardType: TextInputType.number,
                          onChanged: (val) =>
                              trabajosAgregados[idx]["cantidad"] =
                                  int.tryParse(val) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Precio",
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => trabajosAgregados[idx]["precio"] =
                              double.tryParse(val) ?? 0.0,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                TextButton.icon(
                  onPressed: () => setState(
                    () => trabajosAgregados.add({
                      "tipo": "Sillón",
                      "cantidad": 1,
                      "precio": 0.0,
                    }),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar Trabajo"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.all(15),
                  ),
                  onPressed: () async {
                    await _guardarEnFirebase();
                    setState(() {
                      // Limpieza de textos
                      _nombreController.clear();
                      _telefonoController.clear();
                      _direccionController.clear();
                      _pisoController.clear();
                      _deptoController.clear();

                      // RESET DE SELECCIONES (Agregá estas dos líneas)
                      operadorSeleccionado = null;
                      ciudadSeleccionada = null;

                      // Limpieza de lista de trabajos
                      trabajosAgregados = [];
                    });

                    // Opcional: Un aviso de que se guardó
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Orden creada correctamente"),
                      ),
                    );
                  },
                  child: const Text(
                    "CREAR ORDEN",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListaOrdenes extends StatefulWidget {
  const ListaOrdenes({super.key});

  @override
  State<ListaOrdenes> createState() => _ListaOrdenesState();
}

class _ListaOrdenesState extends State<ListaOrdenes> {
  bool mostrarSoloPendientes = true; // Por defecto vemos lo pendiente
  String?
  filtroOperador; // Esta variable guardará el filtro seleccionado (inicia en null)

  Stream<List<String>> getOperadoresStream() {
    return FirebaseFirestore.instance
        .collection('operadores')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc['nombre'] as String).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Órdenes"),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          StreamBuilder<List<String>>(
            stream: getOperadoresStream(),
            builder: (context, snapshot) {
              List<String> listaDinamica = snapshot.data ?? [];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: DropdownButtonFormField<String>(
                  value: filtroOperador,
                  decoration: const InputDecoration(
                    labelText: "Filtrar por Operador",
                    prefixIcon: Icon(Icons.person_search),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Todos los Operadores"),
                    ),
                    ...listaDinamica.map(
                      (op) => DropdownMenuItem(value: op, child: Text(op)),
                    ),
                  ],
                  onChanged: (val) => setState(() => filtroOperador = val),
                ),
              );
            },
          ),
          // BARRA DE FILTROS VISIBLE
          Container(
            color: Colors.blueGrey[50],
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilterChip(
                  label: const Text("PENDIENTES"),
                  selected: mostrarSoloPendientes,
                  selectedColor: Colors.orangeAccent,
                  onSelected: (val) =>
                      setState(() => mostrarSoloPendientes = true),
                ),
                FilterChip(
                  label: const Text("TODAS"),
                  selected: !mostrarSoloPendientes,
                  selectedColor: Colors.blueAccent[100],
                  onSelected: (val) =>
                      setState(() => mostrarSoloPendientes = false),
                ),
              ],
            ),
          ),

          // LA LISTA
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('ordenes')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                // Aplicamos el filtro en la lógica
                if (mostrarSoloPendientes) {
                  docs = docs.where((d) => d['estado'] == 'pendiente').toList();
                }

                if (filtroOperador != null) {
                  docs = docs
                      .where((d) => d['operador'] == filtroOperador)
                      .toList();
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool esCompletado = data['estado'] == 'completado';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: esCompletado ? Colors.green[50] : Colors.white,
                      child: ListTile(
                        leading: Icon(
                          esCompletado ? Icons.check_circle : Icons.timer,
                          color: esCompletado ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          data['cliente_nombre'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: esCompletado
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          "${data['direccion']}\nEstado: ${data['estado']}",
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetalleOrden(orden: data, docId: doc.id),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DetalleOrden extends StatelessWidget {
  final Map<String, dynamic> orden;
  final String docId;

  const DetalleOrden({super.key, required this.orden, required this.docId});

  void _confirmarBorrado(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("¿Borrar orden?"),
          content: const Text("Esta acción no se puede deshacer."),
          actions: [
            TextButton(
              child: const Text("CANCELAR"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("BORRAR", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('ordenes')
                    .doc(docId) // Usamos el ID que ya tenés
                    .delete();

                Navigator.pop(context); // Cierra el cartel
                Navigator.pop(context); // Vuelve a la lista de órdenes
              },
            ),
          ],
        );
      },
    );
  }

  void _abrirEditor(BuildContext context) {
    final TextEditingController nombreCtrl = TextEditingController(
      text: orden['cliente_nombre'],
    );
    final TextEditingController telCtrl = TextEditingController(
      text: orden['cliente_telefono'],
    );
    final TextEditingController dirCtrl = TextEditingController(
      text: orden['direccion'],
    );
    final TextEditingController pisoCtrl = TextEditingController(
      text: orden['piso'] ?? "",
    );
    final TextEditingController deptoCtrl = TextEditingController(
      text: orden['depto'] ?? "",
    );

    // 1. LISTA FIJA DE CIUDADES (Modificá estos nombres a tu gusto)
    List<String> ciudades = [
      "Cipolletti",
      "Neuquén",
      "General Roca",
      "Plottier",
    ];

    // Verificamos que la ciudad de la orden exista en la lista, si no, usamos la primera
    String? ciudadSeleccionada = ciudades.contains(orden['ciudad'])
        ? orden['ciudad']
        : ciudades[0];

    String? operadorSeleccionado = orden['operador'];
    DateTime fechaSeleccionada = (orden['turno'] as Timestamp).toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "EDITAR ORDEN",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: "Cliente"),
                    ),
                    TextField(
                      controller: telCtrl,
                      decoration: const InputDecoration(labelText: "Teléfono"),
                    ),
                    TextField(
                      controller: dirCtrl,
                      decoration: const InputDecoration(labelText: "Dirección"),
                    ),

                    const SizedBox(height: 10),

                    // 2. DROPDOWN DE CIUDADES (Lista Fija)
                    DropdownButtonFormField<String>(
                      value: ciudadSeleccionada,
                      decoration: const InputDecoration(labelText: "Ciudad"),
                      items: ciudades
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => ciudadSeleccionada = val),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pisoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Piso",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: deptoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Depto",
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 3. DROPDOWN DE OPERADORES (Sigue siendo Dinámico desde Firebase)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('operadores')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();

                        List<String> listaOperadores = snapshot.data!.docs
                            .map((doc) => doc['nombre'].toString())
                            .toList();

                        if (!listaOperadores.contains(operadorSeleccionado)) {
                          operadorSeleccionado = listaOperadores.isNotEmpty
                              ? listaOperadores[0]
                              : null;
                        }

                        return DropdownButtonFormField<String>(
                          value: operadorSeleccionado,
                          decoration: const InputDecoration(
                            labelText: "Asignar Operador",
                          ),
                          items: listaOperadores
                              .map(
                                (op) => DropdownMenuItem(
                                  value: op,
                                  child: Text(op),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setModalState(() => operadorSeleccionado = val),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    ListTile(
                      tileColor: Colors.blue[50],
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.blue,
                      ),
                      title: Text(
                        "Turno: ${fechaSeleccionada.day}/${fechaSeleccionada.month} - ${fechaSeleccionada.hour}:${fechaSeleccionada.minute.toString().padLeft(2, '0')} hs",
                      ),
                      onTap: () async {
                        DateTime? pDate = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (pDate == null) return;
                        TimeOfDay? pTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            fechaSeleccionada,
                          ),
                        );
                        if (pTime == null) return;
                        setModalState(
                          () => fechaSeleccionada = DateTime(
                            pDate.year,
                            pDate.month,
                            pDate.day,
                            pTime.hour,
                            pTime.minute,
                          ),
                        );
                      },
                    ),

                    // ... (dentro del Column del modal)
                    const Divider(),
                    const Text(
                      "TRABAJOS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // Mostramos los trabajos que ya tiene la orden
                    ...List.generate(orden['trabajos'].length, (index) {
                      var t = orden['trabajos'][index];
                      return ListTile(
                        title: Text("${t['tipo']} x${t['cantidad']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              orden['trabajos'].removeAt(
                                index,
                              ); // Quita el servicio de la lista local
                            });
                          },
                        ),
                      );
                    }),

                    // BOTÓN PARA AGREGAR UN NUEVO SERVICIO
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Añadir otro servicio"),
                      onPressed: () {
                        _mostrarDialogoNuevoServicio(context, (nuevoServicio) {
                          setModalState(() {
                            orden['trabajos'].add(
                              nuevoServicio,
                            ); // Agrega el servicio a la lista local
                          });
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // ... (luego viene el botón de GUARDAR CAMBIOS que ya tenías)
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('ordenes')
                            .doc(docId)
                            .update({
                              'cliente_nombre': nombreCtrl.text,
                              'cliente_telefono': telCtrl.text,
                              'direccion': dirCtrl.text,
                              'piso': pisoCtrl.text,
                              'depto': deptoCtrl.text,
                              'operador': operadorSeleccionado,
                              'ciudad': ciudadSeleccionada,
                              'turno': Timestamp.fromDate(fechaSeleccionada),
                            });
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "GUARDAR CAMBIOS",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoNuevoServicio(
    BuildContext context,
    Function(Map<String, dynamic>) onAgregar,
  ) {
    String tipo = "Limpieza Alfombras"; // Valor por defecto
    int cantidad = 1;
    double precio = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Tipo de trabajo"),
              onChanged: (val) => tipo = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Cantidad"),
              keyboardType: TextInputType.number,
              onChanged: (val) => cantidad = int.tryParse(val) ?? 1,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Precio Unitario"),
              keyboardType: TextInputType.number,
              onChanged: (val) => precio = double.tryParse(val) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () {
              onAgregar({'tipo': tipo, 'cantidad': cantidad, 'precio': precio});
              Navigator.pop(context);
            },
            child: const Text("AGREGAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recuperamos la lista de trabajos de la orden
    List trabajos = orden['trabajos'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de la Orden"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () =>
                _confirmarBorrado(context), // Función que crearemos ahora
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _abrirEditor(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CARTEL NARANJA DEL OPERADOR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.engineering, color: Colors.orange),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "OPERADOR ASIGNADO",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${orden['operador'] ?? 'Sin asignar'}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 2. DATOS DEL CLIENTE
            const Text(
              "DATOS DEL CLIENTE",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const Divider(),
            Text(
              orden['cliente_nombre'] ?? 'Sin nombre',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text("📍 ${orden['direccion']}, ${orden['ciudad']}"),
            Text("📞 Tel: ${orden['cliente_telefono'] ?? 'N/A'}"),

            const SizedBox(height: 25),

            // 3. DETALLE DE TRABAJOS (RESTAURADO)
            const Text(
              "DETALLE DE TRABAJOS",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const Divider(),

            // Generamos la lista de trabajos dinámicamente
            ...trabajos.map((t) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cleaning_services_outlined, size: 20),
                title: Text("${t['tipo']} (x${t['cantidad']})"),
                trailing: Text(
                  "\$${(t['precio'] ?? 0) * (t['cantidad'] ?? 1)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),

            const Divider(),

            // Total de la orden al final del detalle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TOTAL A COBRAR:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    "\$${trabajos.fold(0.0, (prev, element) => prev + (element['precio'] ?? 0) * (element['cantidad'] ?? 1))}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
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

class GestionOperadores extends StatefulWidget {
  const GestionOperadores({super.key});

  @override
  State<GestionOperadores> createState() => _GestionOperadoresState();
}

class _GestionOperadoresState extends State<GestionOperadores> {
  final TextEditingController _nuevoOpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Operadores"),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nuevoOpController,
                    decoration: const InputDecoration(
                      labelText: "Nombre del nuevo operador",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.green,
                    size: 40,
                  ),
                  onPressed: () {
                    if (_nuevoOpController.text.isNotEmpty) {
                      // Aquí irá la función de agregar
                      _agregarOperador(_nuevoOpController.text);
                      _nuevoOpController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('operadores')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(doc['nombre']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            doc.reference.delete(), // Borra de Firebase
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _agregarOperador(String nombre) {
    FirebaseFirestore.instance.collection('operadores').add({'nombre': nombre});
  }
}
