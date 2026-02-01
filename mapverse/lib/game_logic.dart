// game_logic.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ItemType { mysteryBox, snack, waterBottle, badge, ticket, gem }

/// POI kinds (global/TR friendly)
enum PoiKind {
  cafe,
  pub,
  restaurant,

  // ✅ new detail
  fastFood,
  mall,
  cinema,
  museum,

  cannabis,
  liquor,
  grocery,
  gym,
  clothing,
  barber,
  pawn,
  park,
  beach,
  station,
  airport,
  upgrade,
  other,
}

enum LabelKind { majorDistrict, minorArea, road }

class InventoryEntry {
  final ItemType type;
  final String name;
  final int rewardCoins;
  final int collectedAtSec;

  InventoryEntry({
    required this.type,
    required this.name,
    required this.rewardCoins,
    required this.collectedAtSec,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'rewardCoins': rewardCoins,
        't': collectedAtSec,
      };

  static InventoryEntry fromJson(Map<String, dynamic> j) => InventoryEntry(
        type: ItemType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => ItemType.mysteryBox,
        ),
        name: (j['name'] as String?) ?? 'ITEM',
        rewardCoins: (j['rewardCoins'] as num?)?.toInt() ?? 0,
        collectedAtSec: (j['t'] as num?)?.toInt() ?? 0,
      );
}

class GameItem {
  final String id;
  final ItemType type;
  final String name;
  final LatLng ll;
  final int rewardCoins;
  bool collected;

  GameItem({
    required this.id,
    required this.type,
    required this.name,
    required this.ll,
    required this.rewardCoins,
    this.collected = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'lat': ll.latitude,
        'lng': ll.longitude,
        'rewardCoins': rewardCoins,
        'collected': collected,
      };

  static GameItem fromJson(Map<String, dynamic> j) => GameItem(
        id: (j['id'] as String?) ?? 'it_${DateTime.now().millisecondsSinceEpoch}',
        type: ItemType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => ItemType.mysteryBox,
        ),
        name: (j['name'] as String?) ?? 'MYSTERY BOX',
        ll: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        rewardCoins: (j['rewardCoins'] as num?)?.toInt() ?? 0,
        collected: (j['collected'] as bool?) ?? false,
      );
}

class CityPoi {
  final String id;
  final String name;
  final PoiKind kind;
  final LatLng ll;
  final int importance;

  const CityPoi({
    required this.id,
    required this.name,
    required this.kind,
    required this.ll,
    required this.importance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'lat': ll.latitude,
        'lng': ll.longitude,
        'imp': importance,
      };

  static CityPoi fromJson(Map<String, dynamic> j) => CityPoi(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'PLACE',
        kind: PoiKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => PoiKind.other,
        ),
        ll: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        importance: (j['imp'] as num?)?.toInt() ?? 50,
      );
}

class MapLabel {
  final String id;
  final LabelKind kind;
  final String name;
  final LatLng ll;
  final int importance;

  const MapLabel({
    required this.id,
    required this.kind,
    required this.name,
    required this.ll,
    required this.importance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'lat': ll.latitude,
        'lng': ll.longitude,
        'imp': importance,
      };

  static MapLabel fromJson(Map<String, dynamic> j) => MapLabel(
        id: j['id'] as String,
        kind: LabelKind.values.firstWhere((e) => e.name == j['kind']),
        name: j['name'] as String,
        ll: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        importance: (j['imp'] as num).toInt(),
      );
}

class LabelCacheEntry {
  final String key;
  final int savedAtSec;
  final List<MapLabel> labels;

  LabelCacheEntry({
    required this.key,
    required this.savedAtSec,
    required this.labels,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        't': savedAtSec,
        'labels': labels.map((e) => e.toJson()).toList(),
      };

  static LabelCacheEntry fromJson(Map<String, dynamic> j) => LabelCacheEntry(
        key: j['key'] as String,
        savedAtSec: (j['t'] as num).toInt(),
        labels: ((j['labels'] as List).cast<dynamic>())
            .map((x) => MapLabel.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// ===== POI TILE CACHE (WORLD-SCALE) =====
class PoiTileEntry {
  final String key; // "z/x/y"
  final int savedAtSec;
  final List<CityPoi> pois;

  PoiTileEntry({required this.key, required this.savedAtSec, required this.pois});

  Map<String, dynamic> toJson() => {
        'k': key,
        't': savedAtSec,
        'p': pois.map((e) => e.toJson()).toList(),
      };

  static PoiTileEntry fromJson(Map<String, dynamic> j) => PoiTileEntry(
        key: j['k'] as String,
        savedAtSec: (j['t'] as num).toInt(),
        pois: ((j['p'] as List).cast<dynamic>())
            .map((x) => CityPoi.fromJson((x as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// ===============================
/// GAME LOGIC SINGLETON
/// ===============================
class GameLogic {
  GameLogic._();
  static final GameLogic I = GameLogic._();

  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  void _touch() => tick.value++;

  // Persisted
  int coins = 0;
  bool unlockMinorLabels = false;
  bool unlockExtraDetails = false;

  // Intro / progression
  bool seenIntro = false;
  int totalCollected = 0;

  // Home
  String homeName = '';
  String homeAddress = '';
  double _homeLat = 0;
  double _homeLng = 0;

  LatLng? get homeLL =>
      (_homeLat == 0 || _homeLng == 0) ? null : LatLng(_homeLat, _homeLng);

  // Walking
  double walkedTodayM = 0;
  double _walkBucketM = 0;
  int _walkDayKey = 0; // yyyyMMdd
  static const double dailyGoalM = 2500;
  static const double coinPerMeters = 120.0; // 120m => 1 coin

  // Gameplay
  final List<InventoryEntry> inventory = [];
  final List<GameItem> activeItems = [];
  final List<CityPoi> cityPois = [];

  // Labels cache
  final Map<String, LabelCacheEntry> _labelCacheMap = {};

  // POI tile cache
  final Map<String, PoiTileEntry> _poiTiles = {};
  final Set<String> _poiInFlight = {};
  int _poiRetryAfterSec = 0;
  int _lastOverpassPostSec = 0;

  // Tuning
  static const double collectRadiusM = 55.0;
  static const int hardMaxActiveItems = 36;

  static const int maxLabelCacheEntries = 40;
  static const int labelCacheTtlSec = 3 * 24 * 3600; // 3 days

  static const int maxPoiTileEntries = 36; // keep last N tiles persisted
  static const int poiTileTtlSec = 3 * 24 * 3600; // 3 days

  // Loot anchor (legacy fields, kept for backward-compat / save)
  double _lootAnchorLat = 0;
  double _lootAnchorLng = 0;
  int _lastLootSpawnSec = 0;

  final Distance _dist = const Distance();
  final Random _rng = Random();

  int get nowSec => DateTime.now().millisecondsSinceEpoch ~/ 1000;
  double distanceMeters(LatLng a, LatLng b) => _dist.as(LengthUnit.Meter, a, b);

  LatLng? get lootAnchor => (_lootAnchorLat == 0 && _lootAnchorLng == 0)
      ? null
      : LatLng(_lootAnchorLat, _lootAnchorLng);

  // Keys
  static const _kCoins = 'mv_coins_v7';
  static const _kMinor = 'mv_unlock_minor_v7';
  static const _kExtra = 'mv_unlock_extra_v7';

  static const _kInv = 'mv_inv_v7';
  static const _kItems = 'mv_items_v7';

  static const _kLabels = 'mv_label_cache_map_v2';

  static const _kWalked = 'mv_walked_today_v2';
  static const _kWalkBucket = 'mv_walk_bucket_v2';
  static const _kWalkDay = 'mv_walk_day_v2';

  static const _kIntroSeen = 'mv_intro_seen_v1';
  static const _kCollectedTotal = 'mv_collected_total_v1';

  static const _kLootAnchorLat = 'mv_loot_anchor_lat_v1';
  static const _kLootAnchorLng = 'mv_loot_anchor_lng_v1';
  static const _kLastLootSpawn = 'mv_last_loot_spawn_v1';

  // Home keys
  static const _kHomeName = 'mv_home_name_v1';
  static const _kHomeAddress = 'mv_home_address_v1';
  static const _kHomeLat = 'mv_home_lat_v1';
  static const _kHomeLng = 'mv_home_lng_v1';

  // POI tiles key
  static const _kPoiTiles = 'mv_poi_tiles_v2';

  // ===== Stable loot world seed + collected stable ids =====
  static const _kWorldSeed = 'mv_world_seed_v1';
  static const _kCollectedStableIds = 'mv_collected_stable_ids_v1';
  int _worldSeed = 0;
  final Set<String> _collectedStableIds = {};

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();

    coins = sp.getInt(_kCoins) ?? 0;
    unlockMinorLabels = sp.getBool(_kMinor) ?? false;
    unlockExtraDetails = sp.getBool(_kExtra) ?? false;

    seenIntro = sp.getBool(_kIntroSeen) ?? false;
    totalCollected = sp.getInt(_kCollectedTotal) ?? 0;

    // Home
    homeName = sp.getString(_kHomeName) ?? '';
    homeAddress = sp.getString(_kHomeAddress) ?? '';
    _homeLat = sp.getDouble(_kHomeLat) ?? 0;
    _homeLng = sp.getDouble(_kHomeLng) ?? 0;

    walkedTodayM = sp.getDouble(_kWalked) ?? 0;
    _walkBucketM = sp.getDouble(_kWalkBucket) ?? 0;
    _walkDayKey = sp.getInt(_kWalkDay) ?? _todayKey();
    _rollDayIfNeeded();

    _lootAnchorLat = sp.getDouble(_kLootAnchorLat) ?? 0;
    _lootAnchorLng = sp.getDouble(_kLootAnchorLng) ?? 0;
    _lastLootSpawnSec = sp.getInt(_kLastLootSpawn) ?? 0;

    // World seed
    _worldSeed = sp.getInt(_kWorldSeed) ?? 0;
    if (_worldSeed == 0) {
      _worldSeed = DateTime.now().millisecondsSinceEpoch ^ _rng.nextInt(1 << 30);
      await sp.setInt(_kWorldSeed, _worldSeed);
    }

    // Collected stable ids
    _collectedStableIds.clear();
    final rawCollected = sp.getStringList(_kCollectedStableIds) ?? const <String>[];
    _collectedStableIds.addAll(rawCollected);

    inventory.clear();
    final rawInv = sp.getString(_kInv);
    if (rawInv != null && rawInv.isNotEmpty) {
      try {
        final list = (jsonDecode(rawInv) as List).cast<dynamic>();
        for (final x in list) {
          inventory.add(InventoryEntry.fromJson((x as Map).cast<String, dynamic>()));
        }
      } catch (_) {}
    }

    activeItems.clear();
    final rawItems = sp.getString(_kItems);
    if (rawItems != null && rawItems.isNotEmpty) {
      try {
        final list = (jsonDecode(rawItems) as List).cast<dynamic>();
        for (final x in list) {
          activeItems.add(GameItem.fromJson((x as Map).cast<String, dynamic>()));
        }
      } catch (_) {}
    }

    _labelCacheMap.clear();
    final rawLabels = sp.getString(_kLabels);
    if (rawLabels != null && rawLabels.isNotEmpty) {
      try {
        final m = (jsonDecode(rawLabels) as Map).cast<String, dynamic>();
        for (final kv in m.entries) {
          _labelCacheMap[kv.key] =
              LabelCacheEntry.fromJson((kv.value as Map).cast<String, dynamic>());
        }
      } catch (_) {}
    }

    // Load POI tile cache
    _poiTiles.clear();
    final rawTiles = sp.getString(_kPoiTiles);
    if (rawTiles != null && rawTiles.isNotEmpty) {
      try {
        final m = (jsonDecode(rawTiles) as Map).cast<String, dynamic>();
        for (final kv in m.entries) {
          _poiTiles[kv.key] = PoiTileEntry.fromJson((kv.value as Map).cast<String, dynamic>());
        }
        _enforcePoiTileLimit(); // prune old on load
      } catch (_) {}
    }

    // Build initial cityPois from cached tiles (thinned)
    _rebuildCityPoisFromTiles(limit: 2600);

    _touch();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();

    await sp.setInt(_kCoins, coins);
    await sp.setBool(_kMinor, unlockMinorLabels);
    await sp.setBool(_kExtra, unlockExtraDetails);

    await sp.setBool(_kIntroSeen, seenIntro);
    await sp.setInt(_kCollectedTotal, totalCollected);

    // Home
    await sp.setString(_kHomeName, homeName);
    await sp.setString(_kHomeAddress, homeAddress);
    await sp.setDouble(_kHomeLat, _homeLat);
    await sp.setDouble(_kHomeLng, _homeLng);

    await sp.setDouble(_kWalked, walkedTodayM);
    await sp.setDouble(_kWalkBucket, _walkBucketM);
    await sp.setInt(_kWalkDay, _walkDayKey);

    await sp.setString(_kInv, jsonEncode(inventory.map((e) => e.toJson()).toList()));
    await sp.setString(_kItems, jsonEncode(activeItems.map((e) => e.toJson()).toList()));

    await sp.setDouble(_kLootAnchorLat, _lootAnchorLat);
    await sp.setDouble(_kLootAnchorLng, _lootAnchorLng);
    await sp.setInt(_kLastLootSpawn, _lastLootSpawnSec);

    await sp.setInt(_kWorldSeed, _worldSeed);
    await sp.setStringList(_kCollectedStableIds, _collectedStableIds.toList(growable: false));

    _enforceLabelCacheLimit();
    final outLabels = <String, dynamic>{};
    for (final kv in _labelCacheMap.entries) {
      outLabels[kv.key] = kv.value.toJson();
    }
    await sp.setString(_kLabels, jsonEncode(outLabels));

    _enforcePoiTileLimit();
    final outTiles = <String, dynamic>{};
    for (final kv in _poiTiles.entries) {
      outTiles[kv.key] = kv.value.toJson();
    }
    await sp.setString(_kPoiTiles, jsonEncode(outTiles));

    _touch();
  }

  // ================= HOME =================
  Future<String?> setHomeManual({
    required LatLng ll,
    required String name,
    String address = '',
  }) async {
    homeName = name.trim().isEmpty ? 'HOME' : name.trim().toUpperCase();
    homeAddress = address.trim();
    _homeLat = ll.latitude;
    _homeLng = ll.longitude;
    await save();
    return null;
  }

  // ================= INTRO =================
  Future<void> markIntroSeen() async {
    if (seenIntro) return;
    seenIntro = true;
    await save();
  }

  // ================= WALKING =================
  int _todayKey() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  void _rollDayIfNeeded() {
    final today = _todayKey();
    if (_walkDayKey != today) {
      _walkDayKey = today;
      walkedTodayM = 0;
      _walkBucketM = 0;
    }
  }

  Future<void> addWalkDistanceMeters(double meters) async {
    if (!meters.isFinite || meters <= 0) return;

    _rollDayIfNeeded();
    walkedTodayM += meters;

    _walkBucketM += meters;
    while (_walkBucketM >= coinPerMeters) {
      _walkBucketM -= coinPerMeters;
      coins += 1;
    }
    await save();
  }

  double get dailyProgress => (walkedTodayM / dailyGoalM).clamp(0.0, 1.0);

  // ================= COINS / INVENTORY =================
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    if (coins < amount) return false;
    coins -= amount;
    await save();
    return true;
  }

  // ================= ITEMS (LOOT) =================
  bool canCollect(GameItem it, LatLng user) {
    if (it.collected) return false;
    return distanceMeters(user, it.ll) <= collectRadiusM;
  }

  Future<String> tryCollect(GameItem it, LatLng user) async {
    if (it.collected) return 'ALREADY COLLECTED';
    final d = distanceMeters(user, it.ll);
    if (d > collectRadiusM) return 'GET CLOSER TO COLLECT';
    await _collect(it);
    return 'COLLECTED +${it.rewardCoins} COINS';
  }

  Future<int> _collect(GameItem it) async {
    if (it.collected) return 0;
    it.collected = true;

    // stable id (tile-based): never spawn again after collected
    _collectedStableIds.add(it.id);

    coins += it.rewardCoins;
    totalCollected += 1;

    inventory.insert(
      0,
      InventoryEntry(
        type: it.type,
        name: it.name,
        rewardCoins: it.rewardCoins,
        collectedAtSec: nowSec,
      ),
    );

    activeItems.removeWhere((x) => x.collected);
    await save();
    return it.rewardCoins;
  }

  int _desiredActiveItemCap() {
    final base = 10;
    final bonus = (totalCollected ~/ 3).clamp(0, 26);
    return (base + bonus).clamp(8, hardMaxActiveItems);
  }

  // ===== TILE-BASED STABLE LOOT (fix spam + repeat spawn) =====
  static const double _lootTileM = 420.0; // density control
  static const int _maxSnapPerEnsure = 2;

  static const double _R = 6378137.0;
  double _deg2rad(double d) => d * pi / 180.0;

  Point<double> _llToMeters(LatLng ll) {
    final x = _R * _deg2rad(ll.longitude);
    final y = _R * log(tan(pi / 4 + _deg2rad(ll.latitude) / 2));
    return Point<double>(x, y);
  }

  LatLng _metersToLl(Point<double> p) {
    final lon = (p.x / _R) * 180.0 / pi;
    final lat = (2 * atan(exp(p.y / _R)) - pi / 2) * 180.0 / pi;
    return LatLng(lat, lon);
  }

  int _hash32(int x) {
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    return x & 0x7fffffff;
  }

  int _mix(int a, int b, int c) {
    int x = a;
    x = _hash32(x ^ b);
    x = _hash32(x ^ c);
    return x;
  }

  double _lootRadiusForZoom(double z) {
    if (z < 12.2) return 0;
    if (z < 13.2) return 4200;
    if (z < 14.2) return 3200;
    if (z < 15.2) return 2500;
    return 1800;
  }

  double _tileSpawnChance() {
    final c = totalCollected.clamp(0, 200);
    return (0.18 + (c / 900.0)).clamp(0.18, 0.32);
  }

  bool _hasActiveOrCollected(String id) {
    if (_collectedStableIds.contains(id)) return true;
    for (final it in activeItems) {
      if (it.id == id) return true;
    }
    return false;
  }

  ({ItemType t, String name, int min, int max}) _pickItemDeterministic(Random r) {
    final c = totalCollected.clamp(0, 200);
    final rareBoost = (c / 220.0).clamp(0.0, 0.65);

    final pool = <({ItemType t, String name, int min, int max, double w})>[
      (t: ItemType.mysteryBox, name: 'PICASSO NOTE (RARE)', min: 900, max: 1600, w: 0.06 + 0.06 * rareBoost),
      (t: ItemType.mysteryBox, name: 'OLD CASH ENVELOPE', min: 120, max: 380, w: 0.18),
      (t: ItemType.gem, name: 'SILVER RING', min: 180, max: 520, w: 0.12 + 0.05 * rareBoost),
      (t: ItemType.badge, name: 'CITY BADGE', min: 90, max: 260, w: 0.14),
      (t: ItemType.ticket, name: 'EVENT TICKET', min: 60, max: 210, w: 0.16),
      (t: ItemType.snack, name: 'ENERGY SNACK', min: 25, max: 80, w: 0.20),
      (t: ItemType.waterBottle, name: 'WATER BOTTLE', min: 20, max: 70, w: 0.14),
    ];

    double totalW = 0;
    for (final p in pool) totalW += p.w;

    double x = r.nextDouble() * totalW;
    ({ItemType t, String name, int min, int max, double w}) pick = pool.first;
    for (final p in pool) {
      x -= p.w;
      if (x <= 0) {
        pick = p;
        break;
      }
    }
    return (t: pick.t, name: pick.name, min: pick.min, max: pick.max);
  }

  GameItem _makeLootItemStable({
    required String id,
    required LatLng ll,
    required int seed,
  }) {
    final r = Random(seed);
    final pick = _pickItemDeterministic(r);
    final reward = pick.min + r.nextInt((pick.max - pick.min) + 1);

    return GameItem(
      id: id,
      type: pick.t,
      name: pick.name,
      ll: ll,
      rewardCoins: reward,
      collected: false,
    );
  }

  Future<void> ensureItems(LatLng user, {double zoom = 15.0}) async {
    activeItems.removeWhere((x) => x.collected);

    final desiredCap = _desiredActiveItemCap();
    if (activeItems.length >= desiredCap) return;

    final now = nowSec;
    if (now - _lastLootSpawnSec < 6) return;

    final radius = _lootRadiusForZoom(zoom);
    if (radius <= 0) return;

    final c = _llToMeters(user);

    final minX = c.x - radius;
    final maxX = c.x + radius;
    final minY = c.y - radius;
    final maxY = c.y + radius;

    final tx0 = (minX / _lootTileM).floor();
    final tx1 = (maxX / _lootTileM).floor();
    final ty0 = (minY / _lootTileM).floor();
    final ty1 = (maxY / _lootTileM).floor();

    final chance = _tileSpawnChance();

    final tiles = <({int tx, int ty, double d2})>[];
    for (int tx = tx0; tx <= tx1; tx++) {
      for (int ty = ty0; ty <= ty1; ty++) {
        final cx = (tx + 0.5) * _lootTileM;
        final cy = (ty + 0.5) * _lootTileM;
        final dx = cx - c.x;
        final dy = cy - c.y;
        final d2 = dx * dx + dy * dy;
        if (d2 > radius * radius) continue;
        tiles.add((tx: tx, ty: ty, d2: d2));
      }
    }
    tiles.sort((a, b) => a.d2.compareTo(b.d2));

    int snapBudget = _maxSnapPerEnsure;
    int added = 0;

    for (final t in tiles) {
      if (activeItems.length >= desiredCap) break;
      if (snapBudget <= 0) break;

      final seed = _mix(_worldSeed, t.tx, t.ty);
      final r = Random(seed);

      if (r.nextDouble() > chance) continue;

      final id = 't_${t.tx}_${t.ty}';
      if (_hasActiveOrCollected(id)) continue;

      final px = (t.tx + 0.18 + r.nextDouble() * 0.64) * _lootTileM;
      final py = (t.ty + 0.18 + r.nextDouble() * 0.64) * _lootTileM;
      final llRaw = _metersToLl(Point<double>(px, py));

      bool tooClose = false;
      for (final it in activeItems) {
        if (distanceMeters(it.ll, llRaw) < 140) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;

      final snapped = await snapToWalkable(llRaw, maxDistM: 280);
      snapBudget--;
      if (snapped == null) continue;

      activeItems.add(_makeLootItemStable(id: id, ll: snapped, seed: seed ^ totalCollected));
      added++;

      if (added >= 2) break;
    }

    if (added > 0) {
      _lastLootSpawnSec = now;
      await save();
    }
  }

  Future<LatLng?> snapToWalkable(LatLng ll, {double maxDistM = 250}) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/nearest/v1/foot/${ll.longitude},${ll.latitude}?number=1',
    );

    try {
      final res = await http.get(
        url,
        headers: {'User-Agent': 'com.efeapps.mapverse'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final wps = (data['waypoints'] as List?) ?? [];
      if (wps.isEmpty) return null;

      final loc = (wps.first as Map)['location'];
      if (loc is! List || loc.length < 2) return null;

      final lon = (loc[0] as num).toDouble();
      final lat = (loc[1] as num).toDouble();
      final snapped = LatLng(lat, lon);

      final d = distanceMeters(ll, snapped);
      if (d > maxDistM) return null;

      return snapped;
    } catch (_) {
      return null;
    }
  }

  // ================= POI WORLD FETCH =================

  int _clampRetryAfter(int? sec) {
    if (sec == null) return 90;
    return sec.clamp(30, 600);
  }

  int _tileZForZoom(double z) {
    if (z < 12.2) return 12; // big tiles
    if (z < 14.0) return 13;
    return 14; // detailed tiles
  }

  int _maxPoisPerTile(double z) {
    if (z < 11.2) return 35;
    if (z < 12.2) return 60;
    if (z < 14.0) return 150;
    return 260; // ✅ keep lower to avoid spam on dense downtown
  }

  bool _tileValid(PoiTileEntry e) {
    final age = nowSec - e.savedAtSec;
    return age <= poiTileTtlSec;
  }

  void _enforcePoiTileLimit() {
    if (_poiTiles.length <= maxPoiTileEntries) return;
    final entries = _poiTiles.values.toList()
      ..sort((a, b) => a.savedAtSec.compareTo(b.savedAtSec));
    final removeCount = _poiTiles.length - maxPoiTileEntries;
    for (int i = 0; i < removeCount; i++) {
      _poiTiles.remove(entries[i].key);
    }
  }

  /// ✅ Strong anti-spam: global dedupe + per-kind budget + spacing (no same places clustered)
  void _rebuildCityPoisFromTiles({required int limit}) {
    final all = <String, CityPoi>{};
    for (final t in _poiTiles.values) {
      if (!_tileValid(t)) continue;
      for (final p in t.pois) {
        all[p.id] = p;
      }
    }

    final sorted = all.values.toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));

    final thinned = _thinPoisForDisplay(sorted, hardLimit: limit);

    cityPois
      ..clear()
      ..addAll(thinned);
  }

  List<CityPoi> _thinPoisForDisplay(List<CityPoi> sorted, {required int hardLimit}) {
    String norm(String s) => s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    // Drop generic fallback names for “name-required” kinds
    const generic = <String>{
      'SHOP',
      'PLACE',
      'FOOD',
      'BAR',
      'CAFE',
      'FAST FOOD',
      'MALL',
      'CINEMA',
      'MUSEUM',
      'GYM',
      'CLOTHING',
      'BARBER',
      'PAWN',
      'LIQUOR',
      'CANNABIS',
    };

    bool allowNameless(PoiKind k) =>
        k == PoiKind.park || k == PoiKind.beach || k == PoiKind.station || k == PoiKind.airport;

    // Per-kind caps (keeps variety global / TR)
    final caps = <PoiKind, int>{
      PoiKind.airport: 80,
      PoiKind.station: 160,
      PoiKind.park: 220,
      PoiKind.beach: 120,
      PoiKind.mall: 150,
      PoiKind.cinema: 140,
      PoiKind.museum: 140,
      PoiKind.pub: 220,
      PoiKind.liquor: 180,
      PoiKind.cannabis: 180,
      PoiKind.grocery: 220,
      PoiKind.gym: 200,
      PoiKind.clothing: 180,
      PoiKind.barber: 180,
      PoiKind.pawn: 160,
      PoiKind.cafe: 260,
      PoiKind.fastFood: 260,
      PoiKind.restaurant: 280,
      PoiKind.other: 220,
      PoiKind.upgrade: 80,
    };

    // Minimum spacing per kind (meters)
    final minDist = <PoiKind, double>{
      PoiKind.airport: 260,
      PoiKind.station: 140,
      PoiKind.park: 90,
      PoiKind.beach: 120,
      PoiKind.mall: 110,
      PoiKind.cinema: 110,
      PoiKind.museum: 120,
      PoiKind.pub: 85,
      PoiKind.restaurant: 85,
      PoiKind.fastFood: 85,
      PoiKind.cafe: 75,
      PoiKind.grocery: 95,
      PoiKind.gym: 95,
      PoiKind.clothing: 90,
      PoiKind.barber: 90,
      PoiKind.pawn: 110,
      PoiKind.cannabis: 110,
      PoiKind.liquor: 105,
      PoiKind.other: 95,
      PoiKind.upgrade: 220,
    };

    // Global spacing to prevent icon stacks (meters)
    const globalMin = 32.0;

    final kept = <CityPoi>[];
    final byKind = <PoiKind, List<CityPoi>>{};
    final usedNameCell = <String>{};

    String cellKey(LatLng ll, double meters) {
      final latStep = meters / 111000.0;
      final lonStep = meters / (111000.0 * cos(ll.latitude * pi / 180.0)).clamp(0.2, 1e9);
      final a = (ll.latitude / latStep).floor();
      final b = (ll.longitude / lonStep).floor();
      return '$a:$b';
    }

    bool tooCloseToAny(LatLng ll) {
      // cheap early break (kept is not huge)
      for (final k in kept) {
        if (distanceMeters(ll, k.ll) < globalMin) return true;
      }
      return false;
    }

    bool tooCloseToSameKind(PoiKind kind, LatLng ll) {
      final list = byKind[kind];
      if (list == null || list.isEmpty) return false;
      final md = minDist[kind] ?? 90;
      for (final k in list) {
        if (distanceMeters(ll, k.ll) < md) return true;
      }
      return false;
    }

    final counts = <PoiKind, int>{};

    for (final p in sorted) {
      if (kept.length >= hardLimit) break;

      final k = p.kind;
      final cap = caps[k] ?? 200;
      final c = counts[k] ?? 0;
      if (c >= cap) continue;

      // drop generic names unless allowed
      if (!allowNameless(k)) {
        final n2 = norm(p.name);
        if (generic.contains(n2)) continue;
      }

      // extra dedupe: kind + name + nearby cell
      final nameCell = '${k.name}:${cellKey(p.ll, k == PoiKind.airport ? 260 : 55)}:${norm(p.name)}';
      if (!usedNameCell.add(nameCell)) continue;

      if (tooCloseToAny(p.ll)) continue;
      if (tooCloseToSameKind(k, p.ll)) continue;

      kept.add(p);
      (byKind[k] ??= <CityPoi>[]).add(p);
      counts[k] = c + 1;
    }

    return kept;
  }

  /// Public: ensure POIs for current visible view (tile cached).
  Future<void> ensurePoisForView({
    required double south,
    required double west,
    required double north,
    required double east,
    required double zoom,
  }) async {
    if (nowSec < _poiRetryAfterSec) return;

    final tileZ = _tileZForZoom(zoom);

    // visible tiles range
    final min = _llToTileXY(LatLng(north, west), tileZ);
    final max = _llToTileXY(LatLng(south, east), tileZ);

    int x0 = min.$1, y0 = min.$2;
    int x1 = max.$1, y1 = max.$2;

    if (x0 > x1) {
      final t = x0;
      x0 = x1;
      x1 = t;
    }
    if (y0 > y1) {
      final t = y0;
      y0 = y1;
      y1 = t;
    }

    // guard: don't explode tiles
    final maxTiles = zoom < 12.2 ? 9 : 16; // 3x3 or 4x4
    final tiles = <String>[];
    for (int x = x0; x <= x1; x++) {
      for (int y = y0; y <= y1; y++) {
        tiles.add('$tileZ/$x/$y');
      }
    }

    if (tiles.length > maxTiles) {
      final cx = ((x0 + x1) / 2).round();
      final cy = ((y0 + y1) / 2).round();
      tiles.sort((a, b) {
        final pa = _parseTileKey(a);
        final pb = _parseTileKey(b);
        final da = (pa.$1 - cx).abs() + (pa.$2 - cy).abs();
        final db = (pb.$1 - cx).abs() + (pb.$2 - cy).abs();
        return da.compareTo(db);
      });
      tiles.removeRange(maxTiles, tiles.length);
    }

    // fetch missing/expired tiles
    final need = <String>[];
    for (final k in tiles) {
      final cached = _poiTiles[k];
      if (cached == null || !_tileValid(cached)) need.add(k);
    }

    final batch = need.take(4).toList();
    bool changed = false;

    for (final k in batch) {
      if (_poiInFlight.contains(k)) continue;
      _poiInFlight.add(k);
      try {
        final parsed = _parseTileKey(k);
        final z = int.parse(k.split('/')[0]);
        final b = _tileBounds(parsed.$1, parsed.$2, z);
        final got = await _fetchOverpassPoisForBbox(
          south: b.$1,
          west: b.$2,
          north: b.$3,
          east: b.$4,
          zoom: zoom,
          cap: _maxPoisPerTile(zoom),
        );
        _poiTiles[k] = PoiTileEntry(key: k, savedAtSec: nowSec, pois: got);
        changed = true;
      } finally {
        _poiInFlight.remove(k);
      }
    }

    // rebuild display list (thinned)
    _rebuildCityPoisFromTiles(limit: 5000);

    if (changed) {
      _enforcePoiTileLimit();
      await save();
    } else {
      _touch();
    }
  }

  // ---- Tile math (WebMercator) ----
  (int, int) _llToTileXY(LatLng ll, int z) {
    final lat = ll.latitude.clamp(-85.05112878, 85.05112878);
    final lon = ll.longitude;
    final n = pow(2.0, z).toDouble();
    final x = ((lon + 180.0) / 360.0 * n).floor();

    final latRad = lat * pi / 180.0;
    final y = ((1.0 - log(tan(latRad) + (1 / cos(latRad))) / pi) / 2.0 * n).floor();

    return (x, y);
  }

  (int, int) _parseTileKey(String k) {
    final parts = k.split('/');
    return (int.parse(parts[1]), int.parse(parts[2]));
  }

  (double, double, double, double) _tileBounds(int x, int y, int z) {
    final n = pow(2.0, z).toDouble();

    double lonDeg(int xx) => (xx / n) * 360.0 - 180.0;
    double latDeg(int yy) {
      final a = pi - (2.0 * pi * yy) / n;
      return (180.0 / pi) * atan(0.5 * (exp(a) - exp(-a)));
    }

    final west = lonDeg(x);
    final east = lonDeg(x + 1);
    final north = latDeg(y);
    final south = latDeg(y + 1);
    return (south, west, north, east);
  }

  // ---- Overpass IO ----
  Future<http.Response?> _postOverpass(String ep, String query) async {
    final now = nowSec;
    final delta = now - _lastOverpassPostSec;
    if (delta < 2) {
      await Future.delayed(Duration(milliseconds: (2 - delta) * 1000));
    }
    _lastOverpassPostSec = nowSec;

    try {
      final res = await http
          .post(
            Uri.parse(ep),
            body: {'data': query},
            headers: {'User-Agent': 'com.efeapps.mapverse'},
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 429) {
        final ra = int.tryParse(res.headers['retry-after'] ?? '');
        _poiRetryAfterSec = nowSec + _clampRetryAfter(ra);
        return null;
      }
      if (res.statusCode == 200) return res;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _bestName(Map<String, dynamic> tags, PoiKind kind) {
    String? pick(String k) {
      final v = tags[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
      return null;
    }

    final name = pick('name') ?? pick('brand') ?? pick('operator') ?? pick('short_name');
    if (name != null) return name.toUpperCase();

    if (kind == PoiKind.airport) {
      final iata = pick('iata');
      if (iata != null) return 'AIRPORT $iata'.toUpperCase();
      final ref = pick('ref');
      if (ref != null) return 'AIRPORT $ref'.toUpperCase();
      return 'AIRPORT';
    }

    switch (kind) {
      case PoiKind.cafe:
        return 'CAFE';
      case PoiKind.pub:
        return 'BAR';
      case PoiKind.restaurant:
        return 'FOOD';
      case PoiKind.fastFood:
        return 'FAST FOOD';
      case PoiKind.mall:
        return 'MALL';
      case PoiKind.cinema:
        return 'CINEMA';
      case PoiKind.museum:
        return 'MUSEUM';
      case PoiKind.cannabis:
        return 'CANNABIS';
      case PoiKind.liquor:
        return 'LIQUOR';
      case PoiKind.grocery:
        return 'SHOP';
      case PoiKind.gym:
        return 'GYM';
      case PoiKind.clothing:
        return 'CLOTHING';
      case PoiKind.barber:
        return 'BARBER';
      case PoiKind.pawn:
        return 'PAWN';
      case PoiKind.park:
        return 'PARK';
      case PoiKind.beach:
        return 'BEACH';
      case PoiKind.station:
        return (pick('ref') ?? 'STATION').toUpperCase();
      case PoiKind.airport:
        return 'AIRPORT';
      case PoiKind.upgrade:
        return 'UPGRADE';
      case PoiKind.other:
        return 'PLACE';
    }
  }

  Future<List<CityPoi>> _fetchOverpassPoisForBbox({
    required double south,
    required double west,
    required double north,
    required double east,
    required double zoom,
    required int cap,
  }) async {
    // small pad to avoid edge popping
    final s = south - 0.002;
    final w = west - 0.002;
    final n = north + 0.002;
    final e = east + 0.002;

    final majorOnly = zoom < 12.2;
    final medium = zoom >= 12.2 && zoom < 14.0;
    final detailed = zoom >= 14.0;

    // ✅ curated query (NO "shop" all / NO "amenity" all) -> big anti-spam + perf
    final q = StringBuffer();
    q.writeln('[out:json][timeout:20];(');

    // airports / stations / nature
    q.writeln('nwr["aeroway"="aerodrome"]($s,$w,$n,$e);');
    q.writeln('nwr["aeroway"="terminal"]["name"]($s,$w,$n,$e);');
    q.writeln('nwr["railway"="station"]($s,$w,$n,$e);');
    q.writeln('nwr["public_transport"="station"]($s,$w,$n,$e);');
    q.writeln('nwr["leisure"="park"]($s,$w,$n,$e);');
    q.writeln('nwr["natural"="beach"]($s,$w,$n,$e);');

    // tourism (museum included)
    q.writeln(
      'nwr["tourism"~"museum|gallery|attraction|viewpoint|zoo|aquarium|theme_park"]($s,$w,$n,$e);',
    );

    if (!majorOnly) {
      // food + nightlife + cinema
      q.writeln(
        'nwr["amenity"~"cafe|restaurant|fast_food|bar|pub|ice_cream|nightclub|biergarten|food_court|cinema"]($s,$w,$n,$e);',
      );
      q.writeln('nwr["leisure"="fitness_centre"]($s,$w,$n,$e);');
      q.writeln('nwr["amenity"~"pharmacy|bank|atm"]($s,$w,$n,$e);');
    }

    if (medium || detailed) {
      // shops (curated, includes mall)
      q.writeln(
        'nwr["shop"~"supermarket|convenience|mall|department_store|bakery|alcohol|cannabis|clothes|shoes|electronics|mobile_phone|beauty|hairdresser|variety_store|gift|jewelry|sports|outdoor|kiosk"]($s,$w,$n,$e);',
      );
    }

    if (detailed) {
      // extra detail categories (still curated)
      q.writeln(
        'nwr["amenity"~"clinic|doctors|dentist|hospital|library|post_office|police|fire_station|parking"]($s,$w,$n,$e);',
      );
      q.writeln(
        'nwr["shop"~"books|toys|computer|hardware|furniture|second_hand|confectionery|greengrocer|butcher|seafood"]($s,$w,$n,$e);',
      );
    }

    q.writeln(');out center tags;');

    final endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.openstreetmap.ru/api/interpreter',
    ];

    http.Response? res;
    for (final ep in endpoints) {
      res = await _postOverpass(ep, q.toString());
      if (res != null) break;
    }
    if (res == null) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? [];

    final out = <CityPoi>[];
    final seen = <String>{};

    for (final el in elements) {
      final m = (el as Map).cast<String, dynamic>();
      final type = (m['type'] as String?) ?? '';
      final rawId = '${type}_${m['id']}';
      if (!seen.add(rawId)) continue;

      double? lat2;
      double? lon2;

      if (type == 'node') {
        lat2 = (m['lat'] as num?)?.toDouble();
        lon2 = (m['lon'] as num?)?.toDouble();
      } else {
        final center2 = (m['center'] as Map?)?.cast<String, dynamic>();
        lat2 = (center2?['lat'] as num?)?.toDouble();
        lon2 = (center2?['lon'] as num?)?.toDouble();
      }
      if (lat2 == null || lon2 == null) continue;

      final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final kind = _poiKindFromTags(tags);
      final imp = _importanceForKind(kind);
      final name = _bestName(tags, kind);

      out.add(
        CityPoi(
          id: rawId,
          name: name,
          kind: kind,
          ll: LatLng(lat2, lon2),
          importance: imp,
        ),
      );
    }

    // Tile-level dedupe (cheap)
    String norm(String s) => s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    String cellKey(LatLng ll, double meters) {
      final latStep = meters / 111000.0;
      final lonStep = meters / (111000.0 * cos(ll.latitude * pi / 180.0)).clamp(0.2, 1e9);
      final a = (ll.latitude / latStep).floor();
      final b = (ll.longitude / lonStep).floor();
      return '$a:$b';
    }

    final dedup = <String, CityPoi>{};
    for (final p in out) {
      final cell = cellKey(p.ll, p.kind == PoiKind.airport ? 260 : 55);
      final k = '${p.kind.name}:$cell:${norm(p.name)}';
      final prev = dedup[k];
      if (prev == null || p.importance > prev.importance) dedup[k] = p;
    }

    final fixed = dedup.values.toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));

    return fixed.take(cap).toList();
  }

  PoiKind _poiKindFromTags(Map<String, dynamic> tags) {
    final amenity = (tags['amenity'] as String?) ?? '';
    final shop = (tags['shop'] as String?) ?? '';
    final leisure = (tags['leisure'] as String?) ?? '';
    final natural = (tags['natural'] as String?) ?? '';
    final railway = (tags['railway'] as String?) ?? '';
    final pt = (tags['public_transport'] as String?) ?? '';
    final aeroway = (tags['aeroway'] as String?) ?? '';
    final tourism = (tags['tourism'] as String?) ?? '';

    if (aeroway == 'aerodrome' || aeroway == 'terminal') return PoiKind.airport;

    if (amenity == 'cinema') return PoiKind.cinema;
    if (tourism == 'museum') return PoiKind.museum;

    if (leisure == 'fitness_centre') return PoiKind.gym;
    if (leisure == 'park') return PoiKind.park;
    if (natural == 'beach') return PoiKind.beach;

    if (railway == 'station' || pt == 'station') return PoiKind.station;

    if (amenity == 'cafe') return PoiKind.cafe;

    if (amenity == 'pub' ||
        amenity == 'bar' ||
        amenity == 'nightclub' ||
        amenity == 'biergarten') {
      return PoiKind.pub;
    }

    // ✅ separate fast food
    if (amenity == 'fast_food' || amenity == 'food_court' || amenity == 'ice_cream') {
      return PoiKind.fastFood;
    }

    if (amenity == 'restaurant') return PoiKind.restaurant;

    if (shop == 'mall') return PoiKind.mall;

    if (shop == 'cannabis') return PoiKind.cannabis;
    if (shop == 'alcohol') return PoiKind.liquor;
    if (shop == 'supermarket' || shop == 'convenience') return PoiKind.grocery;
    if (shop == 'clothes' || shop == 'shoes') return PoiKind.clothing;
    if (shop == 'hairdresser' || shop == 'beauty') return PoiKind.barber;
    if (shop == 'pawnshop') return PoiKind.pawn;

    if (tourism.isNotEmpty) return PoiKind.other;

    return PoiKind.other;
  }

  int _importanceForKind(PoiKind k) {
    switch (k) {
      case PoiKind.airport:
        return 160;
      case PoiKind.station:
        return 135;

      case PoiKind.mall:
        return 125;
      case PoiKind.museum:
      case PoiKind.cinema:
        return 122;

      case PoiKind.beach:
      case PoiKind.park:
        return 120;

      case PoiKind.cannabis:
      case PoiKind.liquor:
      case PoiKind.pub:
        return 118;

      case PoiKind.cafe:
      case PoiKind.restaurant:
        return 110;

      case PoiKind.fastFood:
        return 108;

      case PoiKind.gym:
      case PoiKind.grocery:
        return 100;

      case PoiKind.clothing:
      case PoiKind.barber:
      case PoiKind.pawn:
        return 90;

      case PoiKind.upgrade:
        return 90;

      case PoiKind.other:
        return 75;
    }
  }

  // ================= LABELS (OVERPASS) OFFLINE CACHE MAP =================
  String _labelKey(LatLng center, double zoom) {
    final zb = zoom < 13.5 ? 12 : (zoom < 15.5 ? 14 : 16);
    final lat = (center.latitude * 160).round() / 160;
    final lng = (center.longitude * 160).round() / 160;
    return 'z$zb:$lat,$lng';
  }

  bool _cacheValid(LabelCacheEntry c) => (nowSec - c.savedAtSec) <= labelCacheTtlSec;

  void _enforceLabelCacheLimit() {
    if (_labelCacheMap.length <= maxLabelCacheEntries) return;
    final entries = _labelCacheMap.values.toList()
      ..sort((a, b) => a.savedAtSec.compareTo(b.savedAtSec));
    final removeCount = _labelCacheMap.length - maxLabelCacheEntries;
    for (int i = 0; i < removeCount; i++) {
      _labelCacheMap.remove(entries[i].key);
    }
  }

  Future<List<MapLabel>> ensureLabelsForView({
    required LatLng center,
    required double south,
    required double west,
    required double north,
    required double east,
    required double zoom,
    required bool wantMinor,
  }) async {
    final key = _labelKey(center, zoom);
    final cached = _labelCacheMap[key];

    if (cached != null && _cacheValid(cached)) return cached.labels;

    final fetched = await _fetchOverpassLabels(
      center: center,
      south: south,
      west: west,
      north: north,
      east: east,
      zoom: zoom,
      wantMinor: wantMinor,
    ).timeout(const Duration(seconds: 12));

    if (fetched.isEmpty) {
      if (cached != null) return cached.labels;
      return const [];
    }

    final filtered = _spacedFilter(fetched, zoom, wantMinor);
    _labelCacheMap[key] = LabelCacheEntry(key: key, savedAtSec: nowSec, labels: filtered);
    await save();
    return filtered;
  }

  Future<List<MapLabel>> _fetchOverpassLabels({
    required LatLng center,
    required double south,
    required double west,
    required double north,
    required double east,
    required double zoom,
    required bool wantMinor,
  }) async {
    if (zoom < 12.2) {
      final lat0 = center.latitude;
      final lon0 = center.longitude;
      final radius = zoom < 11.2 ? 38000 : 24000;

      final query = '''
[out:json][timeout:20];
(
  nwr(around:$radius,$lat0,$lon0)["place"~"city|town|suburb"]["name"];
);
out center;
''';

      final endpoints = [
        'https://overpass-api.de/api/interpreter',
        'https://overpass.kumi.systems/api/interpreter',
        'https://overpass.openstreetmap.ru/api/interpreter',
      ];

      http.Response? res;
      for (final ep in endpoints) {
        res = await _postOverpass(ep, query);
        if (res != null) break;
      }
      if (res == null) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List?) ?? [];
      final out = <MapLabel>[];

      for (final el in elements) {
        final m = (el as Map).cast<String, dynamic>();
        final type = (m['type'] as String?) ?? '';
        final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? {};
        final nameRaw = (tags['name'] as String?)?.trim();
        if (nameRaw == null || nameRaw.isEmpty) continue;

        double? lat;
        double? lon;
        if (type == 'node') {
          lat = (m['lat'] as num).toDouble();
          lon = (m['lon'] as num).toDouble();
        } else {
          final c = (m['center'] as Map?)?.cast<String, dynamic>();
          if (c == null) continue;
          lat = (c['lat'] as num).toDouble();
          lon = (c['lon'] as num).toDouble();
        }

        final place = (tags['place'] as String?) ?? '';
        final imp = (place == 'city') ? 150 : (place == 'town' ? 125 : 100);

        out.add(MapLabel(
          id: 'pz_${m['id']}',
          kind: LabelKind.majorDistrict,
          name: nameRaw.toUpperCase(),
          ll: LatLng(lat, lon),
          importance: imp,
        ));
      }

      out.sort((a, b) => b.importance.compareTo(a.importance));
      return out.take(18).toList();
    }

    final s = south - 0.015;
    final w = west - 0.015;
    final n = north + 0.015;
    final e = east + 0.015;

    final roadRegex = (zoom < 15)
        ? 'motorway|trunk|primary|secondary'
        : (zoom < 16)
            ? 'motorway|trunk|primary|secondary|tertiary'
            : (wantMinor
                ? 'motorway|trunk|primary|secondary|tertiary|residential|unclassified|service|living_street'
                : 'motorway|trunk|primary|secondary|tertiary|residential');

    final placeRegex =
        wantMinor ? 'city|town|suburb|neighbourhood|quarter' : 'city|town|suburb|quarter';

    final lat0 = center.latitude;
    final lon0 = center.longitude;
    final detailRadius = zoom >= 15.2 ? 1800 : 0;

    final query = '''
[out:json][timeout:20];
(
  nwr["place"~"$placeRegex"]["name"]($s,$w,$n,$e);
  way["highway"~"$roadRegex"]["name"]($s,$w,$n,$e);
  ${detailRadius > 0 ? 'way(around:$detailRadius,$lat0,$lon0)["highway"~"residential|unclassified|service|living_street|tertiary"]["name"];' : ''}
);
out center;
''';

    final endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.openstreetmap.ru/api/interpreter',
    ];

    http.Response? res;
    for (final ep in endpoints) {
      res = await _postOverpass(ep, query);
      if (res != null) break;
    }
    if (res == null) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? [];

    final out = <MapLabel>[];

    for (final el in elements) {
      final m = (el as Map).cast<String, dynamic>();
      final type = (m['type'] as String?) ?? '';
      final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final nameRaw = (tags['name'] as String?)?.trim();
      if (nameRaw == null || nameRaw.isEmpty) continue;

      final name = nameRaw.toUpperCase();

      double? lat;
      double? lon;

      if (type == 'node') {
        lat = (m['lat'] as num).toDouble();
        lon = (m['lon'] as num).toDouble();
      } else {
        final center2 = (m['center'] as Map?)?.cast<String, dynamic>();
        if (center2 == null) continue;
        lat = (center2['lat'] as num).toDouble();
        lon = (center2['lon'] as num).toDouble();
      }

      if (tags.containsKey('highway')) {
        out.add(MapLabel(
          id: 'r_${m['id']}',
          kind: LabelKind.road,
          name: name,
          ll: LatLng(lat, lon),
          importance: 45,
        ));
        continue;
      }

      final place = (tags['place'] as String?) ?? '';
      final kind = (place == 'neighbourhood' || place == 'quarter')
          ? LabelKind.minorArea
          : LabelKind.majorDistrict;

      final imp = (place == 'city')
          ? 135
          : (place == 'town')
              ? 115
              : (place == 'suburb')
                  ? 95
                  : 75;

      out.add(MapLabel(
        id: 'p_${m['id']}',
        kind: kind,
        name: name,
        ll: LatLng(lat, lon),
        importance: imp,
      ));
    }

    out.sort((a, b) => b.importance.compareTo(a.importance));
    return out;
  }

  List<MapLabel> _spacedFilter(List<MapLabel> labels, double zoom, bool wantMinor) {
    final maxMajor = zoom < 14 ? 14 : 24;
    final maxMinor = (wantMinor && zoom >= 15.0) ? 34 : 0;
    final maxRoads = zoom < 15 ? 12 : (zoom < 16 ? 22 : 32);

    int major = 0, minor = 0, roads = 0;
    final kept = <MapLabel>[];

    final minMajor = zoom < 14 ? 850 : 560;
    final minMinor = zoom < 16 ? 520 : 360;
    final minRoad = zoom < 15 ? 780 : 560;

    bool ok(MapLabel l) {
      for (final k in kept) {
        final d = distanceMeters(l.ll, k.ll);
        final minD = (l.kind == LabelKind.majorDistrict)
            ? minMajor
            : (l.kind == LabelKind.minorArea)
                ? minMinor
                : minRoad;
        if (d < minD) return false;
      }
      return true;
    }

    for (final l in labels) {
      if (!ok(l)) continue;

      switch (l.kind) {
        case LabelKind.majorDistrict:
          if (major >= maxMajor) continue;
          major++;
          kept.add(l);
          break;
        case LabelKind.minorArea:
          if (minor >= maxMinor) continue;
          minor++;
          kept.add(l);
          break;
        case LabelKind.road:
          if (roads >= maxRoads) continue;
          roads++;
          kept.add(l);
          break;
      }
    }

    return kept;
  }
}
