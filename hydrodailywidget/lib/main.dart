import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'premium/premium_service.dart'; // path’i kendi projenize göre düzelt
import 'premium/premium_paywall.dart';

import 'lock_draw/lock_draw_page.dart';


/// COLORS
const kBg = Color(0xFFECF4E8);
const kPrimary = Color(0xFFCBF3BB);
const kSecondary = Color(0xFFABE7B2);
const kExtra = Color(0xFF93BFC7);

/// iOS widget connection
const _appGroupChannel = MethodChannel('hydrodaily/appgroup');
const _sharedKey = 'text_from_flutter_app';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final note = data['note'];

  if (note != null) {
    // iOS için BUNU ÇAĞIRMAK RİSKLİ
    print("🔔 background note delivered → $note");
  }
}


Future<void> sendNoteToWidget(String note) async {
  final payload = jsonEncode({'note': note});
  
  try {
    // 1) önce AppGroup'a note verisini yaz
    await _appGroupChannel.invokeMethod('setShared', {
      'key': _sharedKey,
      'value': payload,
    });

    // 2) widget reload ettir: ilk tetik
    await _appGroupChannel.invokeMethod('reloadWidget');

    // 3) ikinci tetik (bazı cihazlarda iOS cache büyük oluyor)
    await Future.delayed(const Duration(milliseconds: 250));
    await _appGroupChannel.invokeMethod('reloadWidget');

    // Terminal log
    debugPrint("📌 widget updated → $note");

  } catch (e) {
    debugPrint("❌ sendNoteToWidget error: $e");
  }
}


void showDelivered(BuildContext context, {String msg = "Delivered 💌"}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      margin: const EdgeInsets.all(16),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      content: Text(
        msg,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

Future<void> sendPushToFriend({
  required String token,
  required String text,
  }) async {
  const url = "https://zooming-charm-production-6359.up.railway.app/sendPush";

  try {
    await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "token": token,
        "note": text,
      }),
     );
     } catch (e) {
     print("push error: $e");
     }
    } 

/// RANDOM INVITE CODE
String generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  int hash = DateTime.now().millisecondsSinceEpoch.hashCode;
  final buf = StringBuffer();
  for (int i = 0; i < 6; i++) {
    hash = 1664525 * hash + 1013904223;
    final index = (hash & 0x7fffffff) % chars.length;
    buf.write(chars[index]);
  }
  return buf.toString();
}

/// ACTIVITY MODEL
class ActivityItem {
  final String id;
  final String type;
  final String text;
  final String? otherName;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.type,
    required this.text,
    required this.createdAt,
    this.otherName,
  });

  factory ActivityItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ActivityItem(
      id: doc.id,
      type: d['type'] ?? 'self_update',
      text: d['text'] ?? '',
      otherName: d['other_name'],
      createdAt:
          (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

Future<void> logActivity({
  required String userId,
  required String type,
  required String text,
  String? otherName,
}) async {
  if (text.trim().isEmpty) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activity')
        .add({
      'type': type,
      'text': text.trim(),
      'other_name': otherName,
      'created_at': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // UI önce açılsın
  runApp(const MyApp());

  // ağır işleri arka planda başlat
  unawaited(_postBoot());
}

Future<void> _postBoot() async {
  try {
    await PremiumService.I.init(); // burada takılıyorsa artık UI açıkken görürsün

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // bunları da UI açıldıktan sonra yap
    await FirebaseMessaging.instance.requestPermission();

    final apns = await FirebaseMessaging.instance.getAPNSToken();
    debugPrint("📍 APNs token = $apns");

    final fcm = await FirebaseMessaging.instance.getToken();
    debugPrint("🔥 FCM token = $fcm");
  } catch (e, st) {
    debugPrint("❌ postBoot error: $e\n$st");
  }
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme() {
    const r = 24.0;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBg,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        background: kBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Write Note For Couples',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: Builder(
      builder: (context) => const RootGate(),
      ),

    );
  }
}

/// ROOT: Auto anonymous login (NO onboarding)
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }
 

  Future<void> savePushToken(String userId) async {
  await FirebaseMessaging.instance.requestPermission();

  // wait until Apple gives device token
  String? apns = await FirebaseMessaging.instance.getAPNSToken();
  print("📍 APNs token = $apns");

  String? token = await FirebaseMessaging.instance.getToken();
  print("🔥 FCM token = $token");

  if (token != null) {
    await FirebaseFirestore.instance.collection("users")
        .doc(userId)
        .set({"push_token": token}, SetOptions(merge: true));
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("♻️ token rotated = $newToken");
    await FirebaseFirestore.instance.collection("users")
        .doc(userId)
        .update({"push_token": newToken});
  });
}




  Future<void> _autoLogin() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .set({
          'name': '',
          'age': '',
          'email': '',
          'username': '',
          'is_anon': true,
          'is_premium': false,
          'invite_code': generateInviteCode(),
          'friend_invites': [],
          'approved_friends': [],
          'main_note': '',
          'notes': {'main': ''},
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await savePushToken(user.uid);
      }

      // ✅ buraya ekle
      await PremiumService.I.bindUser(user!.uid);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainShell(userId: user!.uid),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(child: Text(_error!, style: TextStyle(color: Colors.red))),
      );
    }

    return const SizedBox(); // should not happen
  }
}





/// ─────────────────────────────────────────────────────────────
/// FRIEND MODEL
/// ─────────────────────────────────────────────────────────────
class Friend {
  final String id;
  final String name;
  final String email;

  Friend({
    required this.id,
    required this.name,
    required this.email,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': id,
      'name': name,
      'email': email,
    };
  }
}

/// ─────────────────────────────────────────────────────────────
/// AUTH SCREEN (LOGIN / SIGNUP) – Profile’dan opsiyonel
/// ─────────────────────────────────────────────────────────────
enum AuthMode { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signup;
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _username = '';
  String _email = '';
  String _password = '';

  bool _loading = false;
  String? _error;

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_mode == AuthMode.signup) {
        final current = FirebaseAuth.instance.currentUser;

        // Eğer anonim kullanıcı varsa → mail ile bağla (data kaybolmasın)
        if (current != null && current.isAnonymous) {
          final cred = EmailAuthProvider.credential(
            email: _email.trim(),
            password: _password.trim(),
          );
          final linked = await current.linkWithCredential(cred);
          final user = linked.user!;

          final userRef =
              FirebaseFirestore.instance.collection('users').doc(user.uid);
          final snap = await userRef.get();
          if (snap.exists) {
            await userRef.set(
              {
                'name': _name.trim().isEmpty
                    ? (snap.data()?['name'] ?? '')
                    : _name.trim(),
                'username': _username.trim(),
                'email': _email.trim().toLowerCase(),
                'is_anon': false,
              },
              SetOptions(merge: true),
            );
          } else {
            await userRef.set({
              'name': _name.trim(),
              'username': _username.trim(),
              'email': _email.trim().toLowerCase(),
              'is_anon': false,
              'is_premium': false,
              'invite_code': generateInviteCode(),
              'friend_invites': [],
              'approved_friends': [],
              'main_note': '',
              'notes': {'main': ''},
              'created_at': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Direkt yeni kullanıcı oluşturma
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: _email.trim(),
            password: _password.trim(),
          );
          final user = cred.user!;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'name': _name.trim(),
            'username': _username.trim(),
            'email': _email.trim().toLowerCase(),
            'is_anon': false,
            'is_premium': false,
            'invite_code': generateInviteCode(),
            'friend_invites': [],
            'approved_friends': [],
            'main_note': '',
            'notes': {'main': ''},
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // LOGIN
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Profile’a geri dön
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Auth error';
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == AuthMode.login;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Write Note For Couples',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Send cute notes to your partner & friends.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(AuthMode.login),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLogin ? kPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          child: Text(
                            'Log in',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isLogin ? Colors.black : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(AuthMode.signup),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isLogin ? kPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !isLogin ? Colors.black : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!isLogin) ...[
                          TextFormField(
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            validator: (v) =>
                                (v == null || v.trim().length < 2)
                                    ? 'Enter your name'
                                    : null,
                            onSaved: (v) => _name = v!.trim(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration:
                                const InputDecoration(labelText: 'Username'),
                            validator: (v) =>
                                (v == null || v.trim().length < 3)
                                    ? 'Min 3 characters'
                                    : null,
                            onSaved: (v) => _username = v!.trim(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                          onSaved: (v) => _email = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (v) =>
                              (v == null || v.length < 6)
                                  ? 'Min 6 characters'
                                  : null,
                          onSaved: (v) => _password = v!.trim(),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isLogin ? 'Log in' : 'Create account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MAIN SHELL + NAV
/// ─────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final String userId;
  const MainShell({super.key, required this.userId});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _noteSub;

  @override
  void initState() {
    super.initState();
    _noteSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      final note = (data?['main_note'] as String?) ?? '';
      sendNoteToWidget(note);
    });
  }

  @override
  void dispose() {
    _noteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(userId: widget.userId),
      ShortcutsPage(userId: widget.userId),
      ProfilePage(userId: widget.userId),
      ActivityPage(userId: widget.userId),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Shortcuts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Activity',
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// HOME
/// ─────────────────────────────────────────────────────────────
class HomePage extends StatelessWidget {
  final String userId;
  const HomePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? {};
        final mainNote = (data['main_note'] as String?) ?? '';
        final approvedRaw =
            (data['approved_friends'] as List<dynamic>? ?? []);
        final approved = approvedRaw
            .whereType<Map<String, dynamic>>()
            .map(Friend.fromMap)
            .toList();

        return Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WidgetPreviewCard(note: mainNote),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(color: Colors.black.withOpacity(0.1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WidgetHowToPage(),
                          ),
                        );
                      },
                      child: const Text('How to add widget'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SelfNotePage(
                              userId: userId,
                              initialNote: mainNote,
                            ),
                          ),
                        );
                      },
                      child: const Text('Write note for yourself'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: approved.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SendNoteToFriendPage(
                                    currentUserId: userId,
                                    friends: approved,
                                  ),
                                ),
                              );
                            },
                      child: const Text('+ Send note to friend'),
                    ),
                  ),
                  const SizedBox(height: 12),
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: approved.isEmpty
        ? null
        : () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LockDrawFriendPicker(userId: userId),
              ),
            );
          },
    child: const Text('Draw on Lock Screen (realtime)'),
  ),
),

                  if (approved.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Add a friend from Profile > Invites to start sending notes.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WidgetPreviewCard extends StatelessWidget {
  final String note;
  const _WidgetPreviewCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final showNote =
        note.isEmpty ? 'Your widget note will appear here ✨' : note;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Widget preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.note_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// HOW TO ADD WIDGET
class WidgetHowToPage extends StatelessWidget {
  const WidgetHowToPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HowToStep(
        title: 'Step 1',
        text: 'Go to your Home Screen and long press anywhere.',
        icon: Icons.home_outlined,
      ),
      _HowToStep(
        title: 'Step 2',
        text: 'Tap the "+" button on the top left.',
        icon: Icons.add_circle_outline,
      ),
      _HowToStep(
        title: 'Step 3',
        text: 'Search "Write Note" and add the widget.',
        icon: Icons.search,
      ),
    ];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Add Widget')),
      body: PageView.builder(
        itemCount: pages.length,
        itemBuilder: (_, i) => pages[i],
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const _HowToStep({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 42),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          )
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// SELF NOTE PAGE
/// ─────────────────────────────────────────────────────────────
class SelfNotePage extends StatefulWidget {
  final String userId;
  final String initialNote;
  const SelfNotePage({
    super.key,
    required this.userId,
    required this.initialNote,
  });

  @override
  State<SelfNotePage> createState() => _SelfNotePageState();
}

class _SelfNotePageState extends State<SelfNotePage> {
  final _formKey = GlobalKey<FormState>();
  late String _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);
    try {
      final trimmed = _note.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(
        {
          'main_note': trimmed,
          'notes.main': trimmed,
        },
        SetOptions(merge: true),
      );

      await sendNoteToWidget(trimmed);

      showDelivered(context);

      final snap = await FirebaseFirestore.instance
    .collection("users")
    .doc(widget.userId)
    .get();

     final token = snap["push_token"];
     if (token != null && token.toString().isNotEmpty) {
      sendPushToFriend(token: token, text: trimmed);
      showDelivered(context, msg: "Sent 💌");

     }


      await logActivity(
        userId: widget.userId,
        type: "self_update",
        text: trimmed,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('SelfNote save error: $e');
  
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Your widget note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                initialValue: _note,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Write something...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Write something'
                        : null,
                onSaved: (v) => _note = v!.trim(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save to my widget'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// SEND NOTE TO FRIEND
/// ─────────────────────────────────────────────────────────────
class SendNoteToFriendPage extends StatefulWidget {
  final String currentUserId;
  final List<Friend> friends;
  const SendNoteToFriendPage({
    super.key,
    required this.currentUserId,
    required this.friends,
  });

  @override
  State<SendNoteToFriendPage> createState() => _SendNoteToFriendPageState();
}

class _SendNoteToFriendPageState extends State<SendNoteToFriendPage> {
  Friend? _selected;
  final _formKey = GlobalKey<FormState>();
  String _note = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.friends.isNotEmpty) {
      _selected = widget.friends.first;
    }
  }

  Future<void> _send() async {
    if (_selected == null) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _sending = true);
    try {
      final trimmed = _note.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_selected!.id)
          .update({
        'main_note': trimmed,
        'notes.main': trimmed,
      });

      final snap = await FirebaseFirestore.instance
    .collection("users")
    .doc(_selected!.id)
    .get();

final token = snap["push_token"];

if (token != null && token.toString().isNotEmpty) {
  sendPushToFriend(token: token, text: trimmed);
}


      await logActivity(
        userId: widget.currentUserId,
        type: "sent_to_friend",
        text: trimmed,
        otherName: _selected!.name,
      );

      await logActivity(
        userId: _selected!.id,
        type: "received_from_friend",
        text: trimmed,
        otherName: "You",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note sent to ${_selected!.name}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Send note error: $e');

    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Send note to friend'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            DropdownButtonFormField<Friend>(
              value: _selected,
              decoration: const InputDecoration(
                labelText: 'Friend',
              ),
              items: widget.friends
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text('${f.name} (${f.email})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Have a nice day ❤️',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Write something'
                        : null,
                onSaved: (v) => _note = v!.trim(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// PROFILE
/// ─────────────────────────────────────────────────────────────
class ProfilePage extends StatelessWidget {
  Future<void> logout(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    await FirebaseMessaging.instance.deleteToken();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootGate()),
      (route) => false,
    );
  } catch (e) {
    debugPrint("Logout error: $e");
  }
}


  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? {};
        final name = (data['name'] as String?) ?? '';
        final username = (data['username'] as String?) ?? '';
        final email = (data['email'] as String?) ?? '';
        final inviteCode = (data['invite_code'] as String?) ?? '------';
        final isPremium = data['is_premium'] as bool? ?? false;
        final isAnon = data['is_anon'] as bool? ?? true;

        final invitesRaw =
            (data['friend_invites'] as List<dynamic>? ?? []);
        final invites = invitesRaw.whereType<Map<String, dynamic>>().toList();

        final approvedRaw =
            (data['approved_friends'] as List<dynamic>? ?? []);
        final approved = approvedRaw
            .whereType<Map<String, dynamic>>()
            .map(Friend.fromMap)
            .toList();

        return Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- PREMIUM CARD (satın alma girişi) ---
Card(
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFF6D4CFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPremium ? "Premium Active" : "Go Premium",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPremium
                    ? "Unlimited friends unlocked."
                    : "Free: 1 friend, Premium: 20 friends",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumPaywall()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D4CFF),
            foregroundColor: Colors.white,
          ),
          child: Text(isPremium ? "Manage" : "Upgrade"),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 16),


                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: kPrimary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.person),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'No name' : name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    (username.isEmpty && email.isEmpty)
                                        ? 'Guest mode'
                                        : '@$username · $email',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAnon
                                        ? 'Guest · up to 2 friends'
                                        : 'Account · up to 5 friends',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isPremium
                                          ? Colors.green
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => logout(context),
                              icon: const Icon(Icons.logout),
                             ),  
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isAnon) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create an account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create a free account to keep your data safe and unlock 5 friend slots instead of 2.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AuthScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                      'Create account & unlock 5 friends'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete account?'),
                                content: const Text(
                                  'This will delete your account and notes. This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm != true) return;

                          try {
  final current = FirebaseAuth.instance.currentUser;

  if (current == null) {
    throw Exception("No user");
  }

  // 1) Firestore sil
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .delete();

  // 2) Auth sil (requires-recent-login hatası verebilir)
  await current.delete();

  // 3) Çıkış yap
  await FirebaseAuth.instance.signOut();

} on FirebaseAuthException catch (e) {
  if (e.code == 'requires-recent-login') {
    // Kullanıcıya yeniden giriş yaptır
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in again to delete your account.'),
      ),
    );

    // Login ekranına yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete error: ${e.code}')),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Unexpected error')),
  );
}

                        },
                        child: const Text('Delete account'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _InviteSection(
                      userId: userId,
                      meData: data,
                      inviteCode: inviteCode,
                      invites: invites,
                      approved: approved,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// INVITE SECTION
/// ─────────────────────────────────────────────────────────────
class _InviteSection extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> meData;
  final String inviteCode;
  final List<Map<String, dynamic>> invites;
  final List<Friend> approved;

  const _InviteSection({
    required this.userId,
    required this.meData,
    required this.inviteCode,
    required this.invites,
    required this.approved,
  });

  @override
  State<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<_InviteSection> {
  final _friendInputController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _friendInputController.dispose();
    super.dispose();
  }

  Future<void> removeFriend(String myUid, Friend f) async {
    final meRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final friendRef =
        FirebaseFirestore.instance.collection('users').doc(f.id);

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(meRef, {
      'approved_friends': FieldValue.arrayRemove([f.toMap()])
    });

    batch.update(friendRef, {
      'approved_friends': FieldValue.arrayRemove([
        {
          'userId': myUid,
          'name': '',
          'email': '',
        }
      ])
    });

    await batch.commit();
  }

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: widget.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _sendInvite() async {
    final rawInput = _friendInputController.text.trim();
    if (rawInput.isEmpty) return;

    setState(() => _sending = true);
    try {
      final me = widget.meData;
final myApproved = widget.approved;

final premium =
    (me['is_premium'] as bool? ?? false) || PremiumService.I.isPremium;

const freeLimit = 1;
const premiumLimit = 20;

if (!premium && myApproved.length >= freeLimit) {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PremiumPaywall()),
  );

  final premiumNow =
      (me['is_premium'] as bool? ?? false) || PremiumService.I.isPremium;

  if (!premiumNow) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Free plan: only 1 friend. Upgrade for 20.')),
    );
    return;
  }
}

if (premium && myApproved.length >= premiumLimit) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Premium limit reached (20 friends).')),
  );
  return;
}



      final usersRef = FirebaseFirestore.instance.collection('users');
      QuerySnapshot<Map<String, dynamic>> q;

      if (rawInput.contains('@')) {
        final email = rawInput.toLowerCase();
        q = await usersRef.where('email', isEqualTo: email).limit(1).get();
      } else {
        final code = rawInput.toUpperCase();
        q = await usersRef.where('invite_code', isEqualTo: code).limit(1).get();
      }

      if (q.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final target = q.docs.first;
      final targetId = target.id;
      if (targetId == widget.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot invite yourself.')),
        );
        return;
      }

      final inviteData = {
        'fromUserId': widget.userId,
        'fromName': me['name'] ?? '',
        'fromEmail': me['email'] ?? '',
      };

      await usersRef.doc(targetId).update({
        'friend_invites': FieldValue.arrayUnion([inviteData]),
      });

      _friendInputController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent')),
        );
      }
    } catch (e) {
      debugPrint('Send invite error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn`t send invite')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _approveInvite(Map<String, dynamic> invite) async {
    final fromUserId = invite['fromUserId'] as String?;
    if (fromUserId == null || fromUserId.isEmpty) return;

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final myRef = usersRef.doc(widget.userId);
      final friendRef = usersRef.doc(fromUserId);

      final me = widget.meData;
final myApproved = widget.approved;

final premium =
    (me['is_premium'] as bool? ?? false) || PremiumService.I.isPremium;

const freeLimit = 1;
const premiumLimit = 20;

if (!premium && myApproved.length >= freeLimit) {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PremiumPaywall()),
  );

  final premiumNow =
      (me['is_premium'] as bool? ?? false) || PremiumService.I.isPremium;

  if (!premiumNow) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Free plan: only 1 friend. Upgrade for 20.')),
    );
    return;
  }
}

if (premium && myApproved.length >= premiumLimit) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Premium limit reached (20 friends).')),
  );
  return;
}



      final batch = FirebaseFirestore.instance.batch();

      final myFriendEntry = {
        'userId': fromUserId,
        'name': invite['fromName'] ?? '',
        'email': invite['fromEmail'] ?? '',
      };

      final myEntry = {
        'userId': widget.userId,
        'name': me['name'] ?? '',
        'email': me['email'] ?? '',
      };

      batch.update(myRef, {
        'friend_invites': FieldValue.arrayRemove([invite]),
        'approved_friends': FieldValue.arrayUnion([myFriendEntry]),
      });

      batch.update(friendRef, {
        'approved_friends': FieldValue.arrayUnion([myEntry]),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added')),
        );
      }
    } catch (e) {
      debugPrint('Approve invite error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve invite')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invites = widget.invites;
    final approved = widget.approved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite your friends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Your invite code:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kSecondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.inviteCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _copyInviteCode,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _friendInputController,
                  decoration: const InputDecoration(
                    labelText: 'Friend code or email',
                    hintText: 'ABC123 or friend@email.com',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendInvite,
                    child: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Send invite'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (invites.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Friend requests',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final inv in invites)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(inv['fromName'] ?? 'Unknown'),
                      subtitle: Text(inv['fromEmail'] ?? ''),
                      trailing: TextButton(
                        onPressed: () => _approveInvite(inv),
                        child: const Text('Approve'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (approved.isEmpty)
                  const Text(
                    'No friends yet. Send an invite!',
                    style:
                        TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                for (final f in approved)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.name),
                    subtitle: Text(f.email),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle,
                          color: Colors.red),
                      onPressed: () async {
                        await removeFriend(widget.userId, f);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${f.name} removed')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// SHORTCUTS + ASCII TEMPLATE’LER
/// ─────────────────────────────────────────────────────────────
class ShortcutsPage extends StatelessWidget {
  final String userId;
  const ShortcutsPage({super.key, required this.userId});

  static const templates = [
    {
      "title": "Good Morning ☀️",
      "subtitle": "Cute morning notes",
      "items": [
        "Good morning my love ❤️",
        "Hope your day starts with a smile 😊",
        "I’m thinking of you already ✨",
      ]
    },
    {
      "title": "Motivation 💪",
      "subtitle": "Supportive reminders",
      "items": [
        "You’ve got this. I believe in you.",
        "Small steps today, big wins tomorrow.",
        "Don’t forget how strong you are.",
      ]
    },
    {
      "title": "Sweet & Flirty 😘",
      "subtitle": "Little spicy vibes",
      "items": [
        "I miss you so much right now 😘",
        "You looked amazing today.",
        "Can’t wait to see you again ❤️",
      ]
    },
    {
      "title": "Night 🌙",
      "subtitle": "Before sleep",
      "items": [
        "Good night, sweet dreams 🌙",
        "Sleep well, I’m always with you ❤️",
        "Tomorrow will be even better ✨",
      ]
    },
    {
      "title": "ASCII love art ♡",
      "subtitle": "Cute shapes to send",
      "items": [
        '''
  .:::.   .:::.
 :::::::.:::::::
 :::::::::::::::
 ':::::::::::::'
   ':::::::::'
     ':::::'
       ':'
''',
        '''
ʕ•ᴥ•ʔ  
( づ♡⊂ )
''',
        '''
★·.·´¯`·.·★
   Good Night
 You’re in my heart
★·.·´¯`·.·★
''',
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("Shortcuts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Quick Templates"),
                  content: const Text(
                    "Tap any template to copy it, or long-press to set it as your widget note.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Quick templates",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            "Use ready notes fast. Great for couples & friends.",
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          for (final cat in templates)
            _TemplateCategoryCard(
              userId: userId,
              title: cat["title"] as String,
              subtitle: cat["subtitle"] as String,
              items: (cat["items"] as List),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TemplateCategoryCard extends StatelessWidget {
  final String userId;
  final String title;
  final String subtitle;
  final List items;

  const _TemplateCategoryCard({
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.items,
  });
  
  

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 10),
            for (final t in items)
              GestureDetector(
  onTap: () {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _ShortcutActionSheet(
          userId: userId,
          text: t.toString(),
        );
      },
    );
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      t.toString(),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
class _ShortcutActionSheet extends StatelessWidget {
  final String userId;
  final String text;

  const _ShortcutActionSheet({
    required this.userId,
    required this.text,
  });

  Future<void> _saveToSelf(BuildContext context) async {
    // Firestore kaydı
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'main_note': text, 'notes.main': text});

    await sendNoteToWidget(text);
    showDelivered(context);

    await logActivity(
      userId: userId,
      type: "self_update",
      text: text,
    );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Saved to widget ✅")));
    }
  }

  Future<void> _sendToFriend(BuildContext context) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final approvedRaw =
        (userDoc.data()?['approved_friends'] as List<dynamic>? ?? []);

    final friends = approvedRaw
        .whereType<Map<String, dynamic>>()
        .map(Friend.fromMap)
        .toList();

    if (friends.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have no friends added.")),
      );
      return;
    }

    // Arkadaş seçtir
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Send to a friend",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final f in friends)
              ListTile(
                title: Text(f.name),
                subtitle: Text(f.email),
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(f.id)
                      .update({
                    'main_note': text,
                    'notes.main': text,
                  });
                  final snap = await FirebaseFirestore.instance
                    .collection("users")
                    .doc(f.id)
                    .get();

                  final token = snap["push_token"];

                  if (token != null && token.toString().isNotEmpty) {
                    sendPushToFriend(token: token, text: text);
                    showDelivered(context, msg: "Sent 💌");
                  }

                  await logActivity(
                    userId: userId,
                    type: "sent_to_friend",
                    text: text,
                    otherName: f.name,
                  );

                  await logActivity(
                    userId: f.id,
                    type: "received_from_friend",
                    text: text,
                    otherName: "You",
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Sent to ${f.name} ❤️")),
                    );
                  }
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Save to my widget"),
            onTap: () => _saveToSelf(context),
          ),
          ListTile(
            leading: const Icon(Icons.send),
            title: const Text("Send to a friend"),
            onTap: () => _sendToFriend(context),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// ACTIVITY PAGE
/// ─────────────────────────────────────────────────────────────
class ActivityPage extends StatelessWidget {
  final String userId;
  const ActivityPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activity')
        .orderBy('created_at', descending: true)
        .limit(200);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text("Activity")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Activity could not be loaded.\n\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const _ActivitySkeletonList();
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No activity yet.\nUpdate your note or send it to a friend!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final items = docs.map(ActivityItem.fromDoc).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ActivityTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _ActivitySkeletonList extends StatelessWidget {
  const _ActivitySkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _ActivitySkeletonTile(),
    );
  }
}

class _ActivitySkeletonTile extends StatelessWidget {
  const _ActivitySkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
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

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  const _ActivityTile({super.key, required this.item});

  String get title {
    switch (item.type) {
      case "sent_to_friend":
        return "Sent to ${item.otherName ?? "friend"}";
      case "received_from_friend":
        return "Received from ${item.otherName ?? "friend"}";
      default:
        return "Updated your widget";
    }
  }

  IconData get icon {
    switch (item.type) {
      case "sent_to_friend":
        return Icons.send_rounded;
      case "received_from_friend":
        return Icons.inbox_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color get badgeColor {
    switch (item.type) {
      case "sent_to_friend":
        return kSecondary;
      case "received_from_friend":
        return kExtra;
      default:
        return kPrimary;
    }
  }


  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(item.createdAt).format(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(item.text),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style:
                  const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

