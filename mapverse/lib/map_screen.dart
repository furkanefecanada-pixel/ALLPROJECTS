import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart' as fm
    show RichAttributionWidget, TextSourceAttribution;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'game_logic.dart';

/// ================= SEARCH RESULT MODEL =================
class SearchResult {
  final String title;
  final String subtitle;
  final LatLng ll;

  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.ll,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _mapReady = false;
  LatLng? _pendingCenterMove;

  final mapController = MapController();
  final logic = GameLogic.I;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;

  LatLng? _user;
  LatLng? _prevUser;
  double _headingDeg = 0;

  double _zoom = 15.0;
  bool _follow = true;

  LatLng? _target;
  CityPoi? _targetSnapPoi;

  LatLng? _destination;
  List<LatLng> _route = [];
  double _routeMeters = 0;
  bool _routeBusy = false;
  String _routeKey = '';

  bool _pickingHome = false;

  List<MapLabel> _labels = const [];
  Timer? _labelDebounce;
  bool _labelsBusy = false;

  bool _poisBusy = false;
  Timer? _poiDebounce;

  // anti-spam gates
  int _lastEnsureItemsSec = 0;

  int _lastLabelFetchSec = 0;
  LatLng? _lastLabelCenter;
  double _lastLabelZoom = 0;

  int _lastCamPoiFetchSec = 0;
  LatLng? _lastCamPoiCenter;

  // position race lock (queue)
  bool _posBusy = false;
  Position? _queuedPos;

  // compass throttle
  int _lastHeadingMs = 0;

  // ================= SEARCH (Nominatim) =================
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searchBusy = false;
  List<SearchResult> _searchResults = const [];
  bool _searchOpen = false;
  int _lastSearchMs = 0;

  // ================= NAV / REROUTE =================
  int _lastRerouteSec = 0;
  bool _rerouteBusy = false;

  static const purple = Color(0xFFB24CFF);
  static const neon = Color(0xFFB24CFF);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _labelDebounce?.cancel();
    _poiDebounce?.cancel();
    _searchDebounce?.cancel();

    _posSub?.cancel();
    _compassSub?.cancel();

    _searchCtrl.dispose();
    _searchFocus.dispose();

    super.dispose();
  }

  Future<void> _boot() async {
    final ok = await _ensureLocationPermission();
    if (!ok) {
      // Still show the map, but user won't move.
    }

    _compassSub = FlutterCompass.events?.listen((e) {
      final h = e.heading;
      if (h == null || !mounted) return;

      // throttle to avoid rebuild spam
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastHeadingMs < 120) return;
      _lastHeadingMs = nowMs;

      // ignore tiny jitter
      if ((h - _headingDeg).abs() < 1.2) return;
      setState(() => _headingDeg = h);
    });

    Position p;
    try {
      p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
    } catch (_) {
      p = await Geolocator.getLastKnownPosition() ??
          Position(
            latitude: 49.2827,
            longitude: -123.1207,
            timestamp: DateTime.now(),
            accuracy: 20,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
    }

    await _onPositionQueued(p);

    // Home setup first launch
    if (logic.homeLL == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      await _showHomeSetupSheet(initialUser: _user);
    }

    // Intro sheet
    if (!logic.seenIntro && mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _showIntroSheet();
      await logic.markIntroSeen();
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      unawaited(_onPositionQueued(pos));
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return false;
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // ===== position queue (prevents overlapping async runs) =====
  Future<void> _onPositionQueued(Position p) async {
    if (_posBusy) {
      _queuedPos = p;
      return;
    }
    _posBusy = true;
    try {
      await _onPosition(p);
    } finally {
      _posBusy = false;
      if (_queuedPos != null) {
        final next = _queuedPos!;
        _queuedPos = null;
        // run latest only
        unawaited(_onPositionQueued(next));
      }
    }
  }

  Future<void> _onPosition(Position p) async {
    final ll = LatLng(p.latitude, p.longitude);

    // walking -> coins
    if (_prevUser != null) {
      final d = const Distance().as(LengthUnit.Meter, _prevUser!, ll);
      if (d.isFinite && d > 0.5 && d < 80) {
        await logic.addWalkDistanceMeters(d);
      }
    }
    _prevUser = ll;

    if (!mounted) return;
    if (_user == null || logic.distanceMeters(_user!, ll) >= 1.5) {
      setState(() => _user = ll);
    } else {
      _user = ll;
    }

    // Loot - THROTTLED
    final now = logic.nowSec;
    if ((now - _lastEnsureItemsSec) >= 8) {
      _lastEnsureItemsSec = now;
      await logic.ensureItems(ll, zoom: _zoom);
      if (mounted) setState(() {}); // update loot markers
    }

    // ===== NAV PROGRESS + REROUTE =====
    if (_destination != null && _route.length >= 2) {
      _updateRemainingRoute(ll);
      _maybeReroute(ll);
    }

    // follow camera (camera change will trigger onPositionChanged => labels/pois refresh)
    if (_follow) {
      if (_mapReady) {
        mapController.move(ll, _zoom);
      } else {
        _pendingCenterMove = ll;
      }
    }
  }

  // ================= SEARCH (Nominatim) =================
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();

    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchOpen = false;
      });
      return;
    }

    setState(() => _searchOpen = true);

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    // Rate limit (Nominatim policy)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSearchMs < 1200) return;
    _lastSearchMs = nowMs;

    if (_searchBusy) return;
    _searchBusy = true;
    if (mounted) setState(() {});

    try {
      LatLngBounds? vb;
      if (_mapReady) vb = mapController.camera.visibleBounds;
      final results = await _nominatimSearch(query, view: vb);

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchOpen = true;
      });
    } finally {
      _searchBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<List<SearchResult>> _nominatimSearch(String q,
      {LatLngBounds? view}) async {
    // viewbox: west,south,east,north
    String viewbox = '';
    String bounded = '';
    if (view != null) {
      viewbox =
          '&viewbox=${view.west.toStringAsFixed(6)},${view.south.toStringAsFixed(6)},'
          '${view.east.toStringAsFixed(6)},${view.north.toStringAsFixed(6)}';
      bounded = '&bounded=1';
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=jsonv2'
      '&addressdetails=1'
      '&limit=8'
      '&q=${Uri.encodeComponent(q)}'
      '$viewbox$bounded',
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          'User-Agent': 'com.efeapps.mapverse (support@efeapps.com)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return const [];

      final body = utf8.decode(res.bodyBytes);
      final list = (jsonDecode(body) as List).cast<Map<String, dynamic>>();

      return list.map((m) {
        final lat = double.tryParse('${m['lat']}') ?? 0;
        final lon = double.tryParse('${m['lon']}') ?? 0;

        final display = (m['display_name'] ?? '').toString();
        final parts = display.split(',');
        final title = parts.isNotEmpty ? parts.first.trim() : display;
        final subtitle =
            parts.length > 1 ? parts.skip(1).take(3).join(',').trim() : '';

        return SearchResult(
          title: title.isEmpty ? display : title,
          subtitle: subtitle,
          ll: LatLng(lat, lon),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _selectSearchResult(SearchResult r) async {
    setState(() {
      _follow = false;
      _searchOpen = false;
      _searchResults = const [];
    });
    _searchFocus.unfocus();

    if (_mapReady) {
      mapController.move(r.ll, (_zoom < 15.5 ? 15.8 : _zoom));
    }

    await _setDestination(r.ll);
  }

  // ================= POIs (CAMERA / VIEWPORT) =================
  void _schedulePoisRefreshForCamera({bool force = false}) {
    if (!_mapReady) return;
    _poiDebounce?.cancel();
    _poiDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;

      final cam = mapController.camera;
      final vb = cam.visibleBounds;
      final c = cam.center;
      final now = logic.nowSec;

      final moved = _lastCamPoiCenter == null
          ? 999999.0
          : logic.distanceMeters(_lastCamPoiCenter!, c);

      final timeOk = (now - _lastCamPoiFetchSec) >= (force ? 0 : 45);
      final movedOk = moved >= (force ? 0 : 1400);

      if (!force && !timeOk && !movedOk) return;

      _lastCamPoiFetchSec = now;
      _lastCamPoiCenter = c;

      if (_poisBusy) return;
      _poisBusy = true;

      try {
        await logic.ensurePoisForView(
          south: vb.south,
          west: vb.west,
          north: vb.north,
          east: vb.east,
          zoom: _zoom,
        );
      } finally {
        _poisBusy = false;
        if (mounted) setState(() {});
      }
    });
  }

  // ================= ROUTING =================
  Future<void> _setDestinationFromCrosshair() async {
    final c = _target ??
        (_mapReady
            ? mapController.camera.center
            : (_user ?? const LatLng(49.2827, -123.1207)));

    final snap = _findNearestPoi(c, maxMeters: 90);
    final dest = snap?.ll ?? c;

    await _setDestination(dest);
  }

  Future<void> _setDestination(LatLng dest) async {
    setState(() {
      _destination = dest;
      _route = [];
      _routeMeters = 0;
    });

    if (_user == null) return;
    await _buildRoute(from: _user!, to: dest);
  }

  Future<void> _buildRoute({required LatLng from, required LatLng to}) async {
    final key =
        '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}'
        '->'
        '${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';

    if (_routeBusy) return;
    if (_routeKey == key && _route.isNotEmpty) return;

    _routeBusy = true;
    _routeKey = key;

    try {
      final path = await _osrmRoute(from, to);
      if (!mounted) return;

      final points = path.isNotEmpty ? path : [from, to];
      setState(() {
        _route = points;
        _routeMeters = _polylineMeters(points);
      });
    } finally {
      _routeBusy = false;
    }
  }

  double _polylineMeters(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    double s = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      s += logic.distanceMeters(pts[i], pts[i + 1]);
    }
    return s;
  }

  Future<List<LatLng>> _osrmRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final res = await http
          .get(url, headers: {'User-Agent': 'com.efeapps.mapverse'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? [];
      if (routes.isEmpty) return [];
      final geom = routes.first['geometry'] as Map<String, dynamic>;
      final coords = (geom['coordinates'] as List).cast<List>();
      return coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ================= NAV: progress + reroute =================
  void _updateRemainingRoute(LatLng user) {
    if (_route.length < 2) return;

    final closest = _closestPointOnPolyline(user, _route);
    if (closest == null) return;

    final segIndex = closest.$1;
    final snapped = closest.$2;

    final remaining = <LatLng>[snapped, ..._route.sublist(segIndex + 1)];
    final newMeters = _polylineMeters(remaining);

    if ((newMeters - _routeMeters).abs() >= 3) {
      setState(() {
        _route = remaining;
        _routeMeters = newMeters;
      });
    } else {
      _routeMeters = newMeters;
    }
  }

  void _maybeReroute(LatLng user) {
    if (_destination == null) return;
    if (_route.length < 2) return;
    if (_rerouteBusy) return;

    final now = logic.nowSec;
    if (now - _lastRerouteSec < 12) return;

    final closest = _closestPointOnPolyline(user, _route);
    if (closest == null) return;

    final distToRoute = closest.$3;

    // rotadan 55m+ uzaksa -> reroute
    if (distToRoute < 55) return;

    _rerouteBusy = true;
    _lastRerouteSec = now;

    unawaited(() async {
      try {
        await _buildRoute(from: user, to: _destination!);
      } finally {
        _rerouteBusy = false;
      }
    }());
  }

  (int, LatLng, double)? _closestPointOnPolyline(LatLng p, List<LatLng> poly) {
    if (poly.length < 2) return null;

    double bestD = double.infinity;
    int bestI = 0;
    LatLng bestSnap = poly.first;

    for (int i = 0; i < poly.length - 1; i++) {
      final a = poly[i];
      final b = poly[i + 1];

      final snap = _snapToSegmentMeters(p, a, b);
      final d = logic.distanceMeters(p, snap);

      if (d < bestD) {
        bestD = d;
        bestI = i;
        bestSnap = snap;
      }
    }

    return (bestI, bestSnap, bestD);
  }

  LatLng _snapToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    // equirectangular projection (yakın mesafelerde yeterli)
    final lat0 = p.latitude * math.pi / 180.0;
    const R = 6371000.0;

    ui.Offset toXY(LatLng ll) {
      final x = (ll.longitude * math.pi / 180.0) * math.cos(lat0) * R;
      final y = (ll.latitude * math.pi / 180.0) * R;
      return ui.Offset(x, y);
    }

    final P = toXY(p);
    final A = toXY(a);
    final B = toXY(b);

    final AB = B - A;
    final AP = P - A;

    final ab2 = (AB.dx * AB.dx + AB.dy * AB.dy);
    if (ab2 <= 0.0001) return a;

    double t = (AP.dx * AB.dx + AP.dy * AB.dy) / ab2;
    t = t.clamp(0.0, 1.0);

    final S = ui.Offset(A.dx + AB.dx * t, A.dy + AB.dy * t);

    final lat = (S.dy / R) * 180.0 / math.pi;
    final lon = (S.dx / (R * math.cos(lat0))) * 180.0 / math.pi;

    return LatLng(lat, lon);
  }

  // ================= LABELS =================
  void _scheduleLabelsRefresh({bool force = false}) {
    if (!_mapReady) return;
    _labelDebounce?.cancel();
    _labelDebounce = Timer(const Duration(milliseconds: 520), () async {
      if (!mounted) return;
      await _refreshLabels(force: force);
    });
  }

  Future<void> _refreshLabels({bool force = false}) async {
    if (_labelsBusy) return;

    final cam = mapController.camera;
    final center = cam.center;
    final vb = cam.visibleBounds;

    final now = logic.nowSec;
    final moved = _lastLabelCenter == null
        ? 999999.0
        : logic.distanceMeters(_lastLabelCenter!, center);

    final timeOk = (now - _lastLabelFetchSec) >= (force ? 0 : 12);
    final zoomChanged = (_zoom - _lastLabelZoom).abs() >= 0.8;

    if (!force && !timeOk && moved < 900 && !zoomChanged) return;

    _labelsBusy = true;
    try {
      final wantMinor = (logic.unlockMinorLabels || _zoom >= 15.2);

      final fetched = await logic.ensureLabelsForView(
        center: center,
        south: vb.south,
        west: vb.west,
        north: vb.north,
        east: vb.east,
        zoom: _zoom,
        wantMinor: wantMinor,
      );

      if (!mounted) return;
      setState(() => _labels = fetched);

      _lastLabelFetchSec = now;
      _lastLabelCenter = center;
      _lastLabelZoom = _zoom;
    } finally {
      _labelsBusy = false;
    }
  }

  // ================= POI / TARGET =================
  CityPoi? _findNearestPoi(LatLng target, {required double maxMeters}) {
    if (logic.cityPois.isEmpty) return null;

    CityPoi? best;
    double bestD = double.infinity;

    for (final p in logic.cityPois) {
      final d = logic.distanceMeters(target, p.ll);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best == null) return null;
    if (bestD > maxMeters) return null;
    return best;
  }

  // ================= UI HELPERS =================
  bool _showPoiAtZoom(CityPoi p) {
  // Her zoomda büyük landmarklar kalsın
  if (_zoom < 11.2) return p.importance >= 135; 
  if (_zoom < 12.2) return p.importance >= 120;

  // FOOD çok spam -> geç aç
  final isFood = (p.kind == PoiKind.restaurant ||
      p.kind == PoiKind.cafe ||
      p.kind == PoiKind.pub);

  if (isFood) {
    if (_zoom < 14.2) return false;         // 14.2'den önce hiç gösterme
    if (_zoom < 15.0) return p.importance >= 112; // biraz seçici
    return p.importance >= 100;
  }

  // diğerleri (park, beach, station, cinema vs) daha erken görünebilir
  if (_zoom < 13.6) return p.importance >= 110;
  if (_zoom < 14.6) return p.importance >= 98;
  return true;
}


  int _poiBudget() {
    if (_zoom < 11.2) return 35;
    if (_zoom < 12.2) return 70;
    if (_zoom < 13.6) return 140;
    if (_zoom < 14.6) return 240;
    if (_zoom < 15.6) return 420;
    return 900;
  }

  List<CityPoi> _visiblePoisCulled() {
    if (!_mapReady) return const [];
    if (logic.cityPois.isEmpty) return const [];

    final b = mapController.camera.visibleBounds;

    final candidates = <CityPoi>[];
    for (final p in logic.cityPois) {
      if (!_showPoiAtZoom(p)) continue;
      if (p.ll.latitude < b.south || p.ll.latitude > b.north) continue;
      if (p.ll.longitude < b.west || p.ll.longitude > b.east) continue;
      candidates.add(p);
    }

    if (candidates.isEmpty) return const [];

    final center = mapController.camera.center;
    candidates.sort((a, b2) {
      final imp = b2.importance.compareTo(a.importance);
      if (imp != 0) return imp;
      final da = logic.distanceMeters(center, a.ll);
      final db = logic.distanceMeters(center, b2.ll);
      return da.compareTo(db);
    });

    final budget = _poiBudget();
    return candidates.length <= budget ? candidates : candidates.take(budget).toList();
  }

  // ===== CLUSTER =====
  List<Marker> _buildClusteredPoiMarkers(List<CityPoi> visibles) {
    final doCluster = _zoom < 16.0;

    if (!doCluster) {
      return visibles.map((p) {
        final isHot = (_targetSnapPoi?.id == p.id);
        return Marker(
          point: p.ll,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _openPoiSheet(p),
            child: _PoiMarker(
              icon: _poiIcon(p.kind),
              color: _poiColor(p.kind),
              highlight: isHot,
            ),
          ),
        );
      }).toList();
    }

    final cellM = _zoom < 11.2
        ? 4500.0
        : (_zoom < 12.2
            ? 2400.0
            : (_zoom < 13.6
                ? 1200.0
                : (_zoom < 14.6 ? 650.0 : 260.0)));

    final buckets = <String, List<CityPoi>>{};
    for (final p in visibles) {
      final key = _cellKey(p.ll, cellM);
      (buckets[key] ??= []).add(p);
    }

    final markers = <Marker>[];
    for (final list in buckets.values) {
      if (list.isEmpty) continue;
      list.sort((a, b) => b.importance.compareTo(a.importance));
      final anchor = list.first;

      if (list.length == 1) {
        final p = anchor;
        markers.add(Marker(
          point: p.ll,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _openPoiSheet(p),
            child: _PoiMarker(
              icon: _poiIcon(p.kind),
              color: _poiColor(p.kind),
              highlight: false,
            ),
          ),
        ));
      } else {
        markers.add(Marker(
          point: anchor.ll,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () {
              mapController.move(anchor.ll, (_zoom + 1.1).clamp(10, 18));
            },
            child: _ClusterBubble(count: list.length),
          ),
        ));
      }
    }
    return markers;
  }

  String _cellKey(LatLng ll, double cellM) {
    final latStep = cellM / 111000.0;
    final lonStep = cellM /
        (111000.0 * math.cos(ll.latitude * math.pi / 180.0)).clamp(0.2, 1e9);
    final a = (ll.latitude / latStep).floor();
    final b = (ll.longitude / lonStep).floor();
    return '$a:$b';
  }

  IconData _poiIcon(PoiKind k) {
  switch (k) {
    case PoiKind.fastFood:
      return Icons.fastfood;
    case PoiKind.mall:
      return Icons.local_mall;
    case PoiKind.cinema:
      return Icons.local_movies;
    case PoiKind.museum:
      return Icons.museum;

    case PoiKind.cafe:
      return Icons.local_cafe;
    case PoiKind.pub:
      return Icons.sports_bar;
    case PoiKind.restaurant:
      return Icons.restaurant;

    case PoiKind.cannabis:
      return Icons.grass; // fallback: Icons.local_florist
    case PoiKind.liquor:
      return Icons.liquor; // fallback: Icons.local_bar

    case PoiKind.grocery:
      return Icons.storefront;
    case PoiKind.gym:
      return Icons.fitness_center;
    case PoiKind.clothing:
      return Icons.checkroom;
    case PoiKind.barber:
      return Icons.content_cut;
    case PoiKind.pawn:
      return Icons.monetization_on;

    case PoiKind.park:
      return Icons.park;
    case PoiKind.beach:
      return Icons.beach_access;
    case PoiKind.station:
      return Icons.directions_transit;
    case PoiKind.airport:
      return Icons.local_airport;

    case PoiKind.upgrade:
      return Icons.upgrade;
    case PoiKind.other:
      return Icons.place;
  }
}


  Color _poiColor(PoiKind k) {
    if (k == PoiKind.cannabis || k == PoiKind.liquor || k == PoiKind.pub) return neon;
    if (k == PoiKind.airport || k == PoiKind.station) {
      return Colors.white.withOpacity(0.92);
    }
    if (k == PoiKind.park || k == PoiKind.beach) {
      return Colors.white.withOpacity(0.90);
    }
    return Colors.white.withOpacity(0.88);
  }

  Future<void> _openPoiSheet(CityPoi p) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1217),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(_poiIcon(p.kind)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            p.kind.name.toUpperCase(),
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.65)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          unawaited(_setDestination(p.ll));
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('NAVIGATE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.info_outline),
                        label: const Text('DETAILS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _tapLoot(GameItem it) async {
    if (_user == null) return;
    final msg = await logic.tryCollect(it, _user!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
        backgroundColor: Colors.black.withOpacity(0.85),
      ),
    );
    setState(() {});
  }

  String _focusName() {
    if (!_mapReady) return '';
    final c = mapController.camera.center;

    MapLabel? bestRoad;
    double bestRoadD = double.infinity;

    MapLabel? bestArea;
    double bestAreaD = double.infinity;

    for (final l in _labels) {
      final d = logic.distanceMeters(c, l.ll);
      if (l.kind == LabelKind.road) {
        if (d < bestRoadD) {
          bestRoadD = d;
          bestRoad = l;
        }
      } else {
        if (d < bestAreaD) {
          bestAreaD = d;
          bestArea = l;
        }
      }
    }

    if (bestRoad != null && bestRoadD < 420) return bestRoad.name;
    if (bestArea != null && bestAreaD < 900) return bestArea.name;

    final snap = _findNearestPoi(c, maxMeters: 220);
    if (snap != null) return snap.name;

    return '';
  }

  // ================= HOME SETUP / EDIT =================
  Future<void> _showHomeSetupSheet({LatLng? initialUser}) async {
    final nameCtrl = TextEditingController(
      text: logic.homeName.isEmpty ? 'HOME' : logic.homeName,
    );
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1217),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setModal) {
          void setBusy(bool v) => setModal(() => busy = v);

          Future<void> saveByCurrent() async {
            final u = initialUser ?? _user;
            if (u == null) return;
            setBusy(true);
            await logic.setHomeManual(ll: u, name: nameCtrl.text, address: '');
            setBusy(false);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) setState(() {});
          }

          Future<void> pickOnMap() async {
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {
              _pickingHome = true;
              _follow = false;
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('SET HOME',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Home name',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : pickOnMap,
                          icon: const Icon(Icons.center_focus_strong),
                          label: const Text('PICK ON MAP'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : saveByCurrent,
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location),
                          label: const Text('USE CURRENT'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _showIntroSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1217),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('WELCOME TO MAPVERSE',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '• Walk in real life → earn coins.\n'
                    '• Shops appear as real points on the map.\n'
                    '• Loot spawns around streets & shops.\n'
                    '• Get closer to collect. Some loot is RARE.\n'
                    '• Use coins to unlock map layers.\n'
                    '• Set home by picking on map.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('GOT IT'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeCenter = _user ?? const LatLng(49.2827, -123.1207);

    _target = _mapReady ? mapController.camera.center : safeCenter;
    _targetSnapPoi = (_mapReady && _zoom >= 14.8 && _target != null)
        ? _findNearestPoi(_target!, maxMeters: 85)
        : null;

    final polylines = <Polyline>[];
    if (_route.length >= 2) {
      polylines.add(Polyline(
          points: _route, strokeWidth: 14, color: purple.withOpacity(0.16)));
      polylines.add(Polyline(
          points: _route, strokeWidth: 8, color: purple.withOpacity(0.42)));
      polylines.add(Polyline(points: _route, strokeWidth: 4.6, color: purple));
    }

    final visiblePois = _visiblePoisCulled();
    final poiMarkers = _buildClusteredPoiMarkers(visiblePois);

    final itemMarkers = <Marker>[];
    if (_zoom >= 12.2) {
      for (final it in logic.activeItems.where((x) => !x.collected)) {
        itemMarkers.add(
          Marker(
            point: it.ll,
            width: 38,
            height: 38,
            child: GestureDetector(
              onTap: () => _tapLoot(it),
              child: _LootMarker(near: _user != null && logic.canCollect(it, _user!)),
            ),
          ),
        );
      }
    }

    final labelMarkers = _buildLabelMarkers(_labels);

    final userMarkers = <Marker>[];
    if (_user != null) {
      userMarkers.add(
        Marker(
          point: _user!,
          width: 50,
          height: 50,
          child: Transform.rotate(
            angle: _headingDeg * math.pi / 180,
            child: const _PlayerArrow(),
          ),
        ),
      );
    }

    // Home marker
    final homeMarkers = <Marker>[];
    final home = logic.homeLL;
    if (home != null) {
      homeMarkers.add(
        Marker(
          point: home,
          width: 220,
          height: 110,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home, size: 26, color: Color(0xFFB24CFF)),
                const SizedBox(height: 4),
                _OutlinedText(
                  text: logic.homeName.isEmpty ? 'HOME' : logic.homeName,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final focus = _focusName();

    return ValueListenableBuilder(
      valueListenable: logic.tick,
      builder: (_, __, ___) {
        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: safeCenter,
                  initialZoom: _zoom,
                  minZoom: 10,
                  maxZoom: 18,
                  onMapReady: () {
                    _mapReady = true;

                    if (_pendingCenterMove != null) {
                      mapController.move(_pendingCenterMove!, _zoom);
                      _pendingCenterMove = null;
                    }

                    if (mounted) setState(() {});
                    _scheduleLabelsRefresh(force: true);
                    _schedulePoisRefreshForCamera(force: true);
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (pos, hasGesture) {
                    final newZoom = pos.zoom;
                    final zoomChanged = (newZoom - _zoom).abs() >= 0.05;
                    _zoom = newZoom;

                    if (hasGesture && _follow) {
                      setState(() => _follow = false);
                    } else if (zoomChanged) {
                      if (mounted) setState(() {});
                    }

                    _scheduleLabelsRefresh();
                    _schedulePoisRefreshForCamera();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.efeapps.mapverse',
                  ),
                  if (logic.unlockExtraDetails && _zoom >= 13.8)
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.efeapps.mapverse',
                      tileBuilder: (context, widget, tile) =>
                          Opacity(opacity: 0.18, child: widget),
                    ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: poiMarkers),
                  MarkerLayer(markers: itemMarkers),
                  MarkerLayer(markers: labelMarkers),
                  MarkerLayer(markers: homeMarkers),
                  MarkerLayer(markers: userMarkers),
                  fm.RichAttributionWidget(
                    attributions: const [
                      fm.TextSourceAttribution('© OpenStreetMap contributors'),
                      fm.TextSourceAttribution('© CARTO'),
                    ],
                  ),
                ],
              ),

              const Positioned.fill(child: IgnorePointer(child: _CenterCrosshair())),

              if (_targetSnapPoi != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CrosshairGlowPainter(color: neon.withOpacity(0.85)),
                    ),
                  ),
                ),

              // ===== SEARCH BAR =====
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                right: 12,
                child: _SearchBar(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  busy: _searchBusy,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchResults = const [];
                      _searchOpen = false;
                    });
                  },
                ),
              ),

              if (_searchOpen && _searchResults.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 58,
                  left: 12,
                  right: 12,
                  child: _SearchResultsCard(
                    results: _searchResults,
                    onTap: _selectSearchResult,
                  ),
                ),

              // ===== TOP HUD (moved down because of search) =====
              Positioned(
                top: MediaQuery.of(context).padding.top + 110,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _CoinChip(coins: logic.coins, onTap: _openLayersSheet),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HintBar(
                        text: _pickingHome
                            ? 'MOVE MAP | SET HOME HERE'
                            : (_destination == null
                                ? 'MOVE MAP | PRESS SET'
                                : 'ROUTE READY | PRESS SET'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if ((_labelsBusy && _labels.isEmpty) ||
                        (_poisBusy && logic.cityPois.isEmpty))
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                  ],
                ),
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 156,
                left: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: logic.dailyProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    color: purple,
                  ),
                ),
              ),

              if (focus.isNotEmpty)
                Positioned(
                  left: 14,
                  bottom: 230,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      focus,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ),
                ),

              if (_routeMeters > 0 && !_pickingHome)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 176,
                  child: _RouteBar(meters: _routeMeters),
                ),

              Positioned(
                bottom: 116,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () async {
                      setState(() => _follow = false);

                      if (_pickingHome) {
                        final c = _target ??
                            (_mapReady ? mapController.camera.center : safeCenter);
                        await logic.setHomeManual(
                          ll: c,
                          name: logic.homeName.isEmpty ? 'HOME' : logic.homeName,
                          address: '',
                        );
                        if (!mounted) return;
                        setState(() => _pickingHome = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'HOME SET: ${logic.homeName.isEmpty ? 'HOME' : logic.homeName}',
                            ),
                            duration: const Duration(milliseconds: 900),
                            backgroundColor: Colors.black.withOpacity(0.85),
                          ),
                        );
                        return;
                      }

                      await _setDestinationFromCrosshair();
                    },
                    icon: Icon(_pickingHome ? Icons.home : Icons.center_focus_strong),
                    label: Text(
                      _pickingHome
                          ? 'SET HOME HERE'
                          : (_targetSnapPoi != null
                              ? 'SET: ${_targetSnapPoi!.name}'
                              : 'SET DESTINATION'),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 12,
                bottom: 150,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'recenter',
                      onPressed: () {
                        if (_user == null) return;
                        setState(() => _follow = true);
                        mapController.move(_user!, _zoom);
                        _schedulePoisRefreshForCamera(force: true);
                        _scheduleLabelsRefresh(force: true);
                      },
                      child: Icon(_follow ? Icons.gps_fixed : Icons.gps_not_fixed),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'home',
                      onPressed: () {
                        final h = logic.homeLL;
                        if (h == null) return;
                        setState(() => _follow = false);
                        mapController.move(h, (_zoom < 15 ? 15.5 : _zoom));
                        _schedulePoisRefreshForCamera(force: true);
                        _scheduleLabelsRefresh(force: true);
                      },
                      child: const Icon(Icons.home),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'layers',
                      onPressed: _openLayersSheet,
                      child: const Icon(Icons.layers),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'clear',
                      onPressed: () => setState(() {
                        _destination = null;
                        _route = [];
                        _routeMeters = 0;
                        _pickingHome = false;
                      }),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== LABEL MARKERS (collision reduced) =====
  List<Marker> _buildLabelMarkers(List<MapLabel> labels) {
    if (!_mapReady || labels.isEmpty) return const [];

    final showMajor = _zoom >= 10.8;
    final showMinor = (logic.unlockMinorLabels || _zoom >= 15.2);
    final showRoads = _zoom >= 14.2;

    // priority: major > minor > road
    int prio(LabelKind k) {
      switch (k) {
        case LabelKind.majorDistrict:
          return 3;
        case LabelKind.minorArea:
          return 2;
        case LabelKind.road:
          return 1;
      }
    }

    final candidates = <MapLabel>[];
    for (final l in labels) {
      if (l.kind == LabelKind.majorDistrict && !showMajor) continue;
      if (l.kind == LabelKind.minorArea && !showMinor) continue;
      if (l.kind == LabelKind.road && !showRoads) continue;
      candidates.add(l);
    }
    if (candidates.isEmpty) return const [];

    // sort by kind priority, then by distance to center (closer first)
    final center = mapController.camera.center;
    candidates.sort((a, b) {
      final p = prio(b.kind).compareTo(prio(a.kind));
      if (p != 0) return p;
      final da = logic.distanceMeters(center, a.ll);
      final db = logic.distanceMeters(center, b.ll);
      return da.compareTo(db);
    });

    // simple screen-space collision culling
    final taken = <Rect>[];
    final out = <Marker>[];

    double fontSizeFor(LabelKind k) =>
        (k == LabelKind.majorDistrict) ? 18.0 : (k == LabelKind.minorArea ? 14.0 : 12.0);
    FontWeight weightFor(LabelKind k) =>
        (k == LabelKind.majorDistrict) ? FontWeight.w900 : FontWeight.w800;

    // budget by zoom
    final budget = _zoom < 12.5 ? 16 : (_zoom < 14.0 ? 28 : (_zoom < 15.5 ? 55 : 90));
    final trimmed = candidates.length <= budget ? candidates : candidates.take(budget);

    for (final l in trimmed) {
      final fs = fontSizeFor(l.kind);
      final fw = weightFor(l.kind);

      // approximate rect size (good enough)
      final approxW = (l.name.characters.length.clamp(3, 26)) * fs * 0.62 + 26;
      final approxH = fs * 1.6 + 18;

      // project to screen (FIXED)
final cam = mapController.camera;
final pt = cam.project(l.ll);
final origin = cam.pixelOrigin;

final screen = Offset(
  (pt.x - origin.x).toDouble(),
  (pt.y - origin.y).toDouble(),
);

final rect = Rect.fromCenter(
  center: screen + (l.kind == LabelKind.road ? const Offset(0, -8) : Offset.zero),
  width: approxW,
  height: approxH,
);


      bool collides = false;
      for (final r in taken) {
        if (r.overlaps(rect)) {
          collides = true;
          break;
        }
      }
      if (collides) continue;

      taken.add(rect);

      out.add(
        Marker(
          point: l.ll,
          width: approxW,
          height: approxH,
          child: IgnorePointer(
            child: Center(
              child: _OutlinedText(
                text: l.name,
                fontSize: fs,
                fontWeight: fw,
              ),
            ),
          ),
        ),
      );
    }

    return out;
  }

  Future<void> _openLayersSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1217),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.layers),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'MAP LAYERS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text('COINS: ${logic.coins}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.home, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              logic.homeName.isEmpty ? 'HOME' : logic.homeName,
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Tap EDIT to pick home on map.',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showHomeSetupSheet(initialUser: _user);
                          if (mounted) setState(() {});
                        },
                        child: const Text('EDIT'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _layerRow(
                  title: 'Minor Labels',
                  desc: 'Neighbourhood names appear when zoomed in.',
                  owned: logic.unlockMinorLabels,
                  cost: 150,
                  onBuy: () async {
                    final ok = await logic.spendCoins(150);
                    if (!ok) return;
                    logic.unlockMinorLabels = true;
                    await logic.save();
                    if (mounted) Navigator.pop(context);
                    _scheduleLabelsRefresh(force: true);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _layerRow(
                  title: 'Extra Details',
                  desc: 'Subtle extra detail overlay on map.',
                  owned: logic.unlockExtraDetails,
                  cost: 200,
                  onBuy: () async {
                    final ok = await logic.spendCoins(200);
                    if (!ok) return;
                    logic.unlockExtraDetails = true;
                    await logic.save();
                    if (mounted) Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _layerRow({
    required String title,
    required String desc,
    required bool owned,
    required int cost,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ]),
          ),
          const SizedBox(width: 10),
          owned
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('OWNED',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                )
              : FilledButton(
                  onPressed: logic.coins >= cost ? onBuy : null,
                  child: Text('$cost'),
                ),
        ],
      ),
    );
  }
}

/// ================= UI PARTS =================

class _ClusterBubble extends StatelessWidget {
  final int count;
  const _ClusterBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFB24CFF).withOpacity(0.95),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const _OutlinedText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'GTA',
      fontFamilyFallback: const ['NotoSans', 'Roboto', 'Arial'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.15,
    );

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.black.withOpacity(0.75);

    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(foreground: strokePaint),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _CenterCrosshair extends StatelessWidget {
  const _CenterCrosshair();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CrosshairPainter());
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const gap = 10.0;
    const len = 18.0;

    canvas.drawLine(Offset(c.dx - len, c.dy), Offset(c.dx - gap, c.dy), paint);
    canvas.drawLine(Offset(c.dx + gap, c.dy), Offset(c.dx + len, c.dy), paint);

    canvas.drawLine(Offset(c.dx, c.dy - len), Offset(c.dx, c.dy - gap), paint);
    canvas.drawLine(Offset(c.dx, c.dy + gap), Offset(c.dx, c.dy + len), paint);

    final dot = Paint()..color = Colors.white.withOpacity(0.12);
    canvas.drawCircle(c, 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrosshairGlowPainter extends CustomPainter {
  final Color color;
  _CrosshairGlowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final glow = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    canvas.drawCircle(c, 24, glow);
    canvas.drawCircle(c, 24, p);
  }

  @override
  bool shouldRepaint(covariant _CrosshairGlowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PlayerArrow extends StatelessWidget {
  const _PlayerArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArrowPainter(),
      child: const SizedBox(width: 50, height: 50),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    final glow = Paint()
      ..color = const Color(0xFFB24CFF).withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final fill = Paint()..color = Colors.white;

    final ui.Path path = ui.Path()
      ..moveTo(c.dx, c.dy - 18)
      ..lineTo(c.dx + 12, c.dy + 16)
      ..lineTo(c.dx, c.dy + 10)
      ..lineTo(c.dx - 12, c.dy + 16)
      ..close();

    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);

    final ui.Path innerPath = ui.Path()
      ..moveTo(c.dx, c.dy - 10)
      ..lineTo(c.dx + 6.5, c.dy + 10)
      ..lineTo(c.dx, c.dy + 7)
      ..lineTo(c.dx - 6.5, c.dy + 10)
      ..close();

    final inner = Paint()..color = const Color(0xFF0B0B0B);
    canvas.drawPath(innerPath, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PoiMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool highlight;

  const _PoiMarker({
    required this.icon,
    required this.color,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (highlight)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB24CFF), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB24CFF).withOpacity(0.32),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        Icon(icon, size: 20, color: color),
      ],
    );
  }
}

class _LootMarker extends StatelessWidget {
  final bool near;
  const _LootMarker({required this.near});

  @override
  Widget build(BuildContext context) {
    final glow = near ? const Color(0xFFB24CFF) : Colors.white.withOpacity(0.9);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glow.withOpacity(near ? 0.9 : 0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: glow.withOpacity(near ? 0.35 : 0.12),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Icon(
          Icons.inventory_2,
          size: 20,
          color: Colors.white.withOpacity(0.92),
        ),
      ],
    );
  }
}

class _CoinChip extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;

  const _CoinChip({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, size: 16),
              const SizedBox(width: 6),
              Text('$coins', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBar extends StatelessWidget {
  final String text;
  const _HintBar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.05,
        ),
      ),
    );
  }
}

class _RouteBar extends StatelessWidget {
  final double meters;
  const _RouteBar({required this.meters});

  @override
  Widget build(BuildContext context) {
    final mins = (meters / 80.0).round().clamp(1, 999);
    final eta = mins == 1 ? '1 MIN' : '$mins MIN';
    final dist = meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(2)} KM'
        : '${meters.toStringAsFixed(0)} M';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, size: 18),
          const SizedBox(width: 10),
          const Text('ETA', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Text(eta, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(
            dist,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.82),
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= SEARCH UI =================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.60),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: 'Search street, neighbourhood, place...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  final List<SearchResult> results;
  final ValueChanged<SearchResult> onTap;

  const _SearchResultsCard({
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F1217),
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, __) =>
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
          itemBuilder: (_, i) {
            final r = results[i];
            return ListTile(
              dense: true,
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: r.subtitle.isEmpty
                  ? null
                  : Text(r.subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onTap(r),
            );
          },
        ),
      ),
    );
  }
}
