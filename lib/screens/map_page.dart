import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsbm_connect/theme.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import '../services/map_cache_manager_service.dart'; 

class MapPage extends StatefulWidget {
  final String? destinationLabel;
  const MapPage({super.key, this.destinationLabel});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final double coordinateScale = 3.779528;
  late TransformationController _transformationController;

  Map<String, dynamic> _nodes = {};
  Map<String, dynamic> _adjacencies = {};
  List<dynamic> _floors = [];
  final Map<String, Size> _imageSizes = {};
  final Map<String, File> _downloadedFiles = {}; 

  String? startRoom;
  String? endRoom;
  List<String> _fullPathIds = [];
  String? currentFloorId;
  bool _isDataLoaded = false;
  bool _isDownloading = true;

  double _minScale = 0.1;
  final double _mapPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _initializeMapSystem();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _initializeMapSystem() async {
    await MapCacheManager().syncMaps();

    await _loadMapData();

    await _verifyAndLoadImages();
  }

  Future<void> _loadMapData() async {
    try {
      String jsonString;
      try {
        final ref = FirebaseStorage.instance.ref().child('metadata/map_navigation.json');
        final Uint8List? bytes = await ref.getData();
        if (bytes != null) {
          jsonString = utf8.decode(bytes);
        } else {
          throw Exception("Empty bytes");
        }
      } catch (e) {
        jsonString = await rootBundle.loadString('assets/data/map_navigation.json');
      }

      final data = json.decode(jsonString);
      _floors = data['floors'];
      _nodes = data['nodes'];
      _adjacencies = data['adjacencies'];

      if (widget.destinationLabel != null) {
        final matches = _nodes.keys.where((k) => _nodes[k]['label'] == widget.destinationLabel);
        if (matches.isNotEmpty) endRoom = matches.first;
      }
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  Future<void> _verifyAndLoadImages() async {
    try {
      for (var floor in _floors) {
        String fileName = floor['image'].split('/').last; 
        File? file = await MapCacheManager().getMapFile(fileName);

        if (file != null && await file.exists()) {
          _downloadedFiles[floor['id']] = file;
          _imageSizes[floor['id']] = await _calculateFileImageDimension(file);
        }
      }

      if (mounted) {
        setState(() {
          currentFloorId = _floors[0]['id'];
          _isDownloading = false;
          _isDataLoaded = true;
        });
        Future.delayed(Duration.zero, () => _resetMapPosition());
      }
    } catch (e) {
      debugPrint("Error loading image files: $e");
    }
  }

  Future<Size> _calculateFileImageDimension(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo fi = await codec.getNextFrame();
    return Size(fi.image.width.toDouble(), fi.image.height.toDouble());
  }

  void _resetMapPosition() {
    if (!_isDataLoaded || currentFloorId == null || !_imageSizes.containsKey(currentFloorId)) return;

    final Size imgSize = _imageSizes[currentFloorId]!;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double boxW = renderBox.size.width - (_mapPadding * 2);
    final double boxH = renderBox.size.height - 200;

    double scaleX = boxW / imgSize.width;
    double scaleY = boxH / imgSize.height;
    double fillScale = scaleX > scaleY ? scaleX : scaleY;

    final double offsetX = (boxW - (imgSize.width * fillScale)) / 2;
    final double offsetY = (boxH - (imgSize.height * fillScale)) / 2;

    setState(() {
      _minScale = fillScale;
      _transformationController.value = Matrix4.identity()
        ..translate(offsetX, offsetY)
        ..scale(fillScale);
    });
  }

  void findPath() {
    if (startRoom == null || endRoom == null) return;
    List<String> queue = [startRoom!];
    Map<String, String?> cameFrom = {startRoom!: null};

    while (queue.isNotEmpty) {
      String current = queue.removeAt(0);
      if (current == endRoom) break;
      for (String next in (_adjacencies[current] ?? [])) {
        if (!cameFrom.containsKey(next)) {
          cameFrom[next] = current;
          queue.add(next);
        }
      }
    }

    if (!cameFrom.containsKey(endRoom)) return;

    List<String> pathIds = [];
    String? temp = endRoom;
    while (temp != null) {
      pathIds.add(temp);
      temp = cameFrom[temp];
    }

    setState(() {
      _fullPathIds = pathIds.reversed.toList();
      String newFloor = _nodes[startRoom!]['floor'];
      if (currentFloorId != newFloor) {
        currentFloorId = newFloor;
        _resetMapPosition();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded || _isDownloading || currentFloorId == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 20),
              Text("Syncing Map Data...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    Size imgSize = _imageSizes[currentFloorId]!;
    File mapFile = _downloadedFiles[currentFloorId]!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildControls(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(_mapPadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      constrained: false,
                      boundaryMargin: EdgeInsets.zero,
                      minScale: _minScale,
                      maxScale: 5.0,
                      child: Stack(
                        children: [
                          Image.file(
                            mapFile,
                            width: imgSize.width,
                            height: imgSize.height,
                            fit: BoxFit.none,
                          ),
                          SizedBox(
                            width: imgSize.width,
                            height: imgSize.height,
                            child: CustomPaint(
                              painter: MapPainter(_fullPathIds, _nodes, currentFloorId!, coordinateScale),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 15.0, bottom: 15.0),
        child: _buildFloorSwitcher(),
      ),
    );
  }


  Widget? _buildFloorSwitcher() {
    Set<String> floorsInPath = _fullPathIds.map((id) => _nodes[id]['floor'] as String).toSet();
    if (floorsInPath.length <= 1) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _floors.where((f) => floorsInPath.contains(f['id'])).map((f) {
        bool isActive = currentFloorId == f['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SizedBox(
            height: 38,
            child: FloatingActionButton.extended(
              heroTag: f['id'],
              onPressed: () {
                setState(() => currentFloorId = f['id']);
                _resetMapPosition();
              },
              label: Text(f['id'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              icon: Icon(isActive ? Icons.visibility : Icons.visibility_off, size: 16),
              backgroundColor: isActive ? AppColors.primary : Colors.grey[400],
              foregroundColor: Colors.white,
              elevation: 2,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 25, 16, 16),
      decoration: BoxDecoration(color: Colors.grey[80]),
      child: Column(
        children: [
          _buildDropdown("🔴 Start Point", startRoom, (v) => setState(() => startRoom = v)),
          const SizedBox(height: 12),
          _buildDropdown("🟢 Destination", endRoom, (v) => setState(() => endRoom = v)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: findPath,
            icon: const Icon(Icons.navigation),
            label: const Text("Show Route"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? selectedValue, ValueChanged<String?> onChanged) {
    List<DropdownMenuItem<String>> items = [];
    for (var floor in _floors) {
      items.add(DropdownMenuItem(
        enabled: false,
        child: Text(
          floor['name'].toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
        ),
      ));
      var rooms = _nodes.keys.where((k) => _nodes[k]['floor'] == floor['id'] && !k.contains('_p')).toList()..sort();
      for (var room in rooms) {
        items.add(DropdownMenuItem(
          value: room,
          child: Text("  ${_nodes[room]['label']}", style: const TextStyle(fontSize: 14)),
        ));
      }
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: selectedValue,
      onChanged: onChanged,
      items: items,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final List<String> pathIds;
  final Map<String, dynamic> nodes;
  final String currentFloorId;
  final double scale;

  MapPainter(this.pathIds, this.nodes, this.currentFloorId, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (pathIds.isEmpty) return;
    final linePaint = Paint()
      ..color = AppColors.secondary.withOpacity(0.8)
      ..strokeWidth = 15.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final glowPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3)
      ..strokeWidth = 25.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < pathIds.length - 1; i++) {
      var n1 = nodes[pathIds[i]];
      var n2 = nodes[pathIds[i + 1]];
      if (n1['floor'] == currentFloorId && n2['floor'] == currentFloorId) {
        Offset p1 = Offset(n1['x'] * scale, n1['y'] * scale);
        Offset p2 = Offset(n2['x'] * scale, n2['y'] * scale);
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, linePaint);
      }
    }
    if (nodes[pathIds.first]['floor'] == currentFloorId) {
      var start = nodes[pathIds.first];
      canvas.drawCircle(Offset(start['x'] * scale, start['y'] * scale), 25, Paint()..color = Colors.red);
    }
    if (nodes[pathIds.last]['floor'] == currentFloorId) {
      var end = nodes[pathIds.last];
      canvas.drawCircle(Offset(end['x'] * scale, end['y'] * scale), 25, Paint()..color = Colors.green);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
