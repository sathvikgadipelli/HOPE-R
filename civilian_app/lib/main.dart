import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

String apiBaseUrl() => 'https://hope-r-api.onrender.com';

void main() {
  runApp(const HopeRApp());
}

// =========================================================
// NETWORK CONFIGURATION
// =========================================================

class NetworkConfig {
  static const Duration requestTimeout = Duration(seconds: 90);
  static const Duration locationTimeout = Duration(seconds: 20);

  static const int maxRequestAttempts = 3;

  static Duration retryDelay(int attempt) {
    return Duration(seconds: attempt * 3);
  }
}

// =========================================================
// API SERVICE
// =========================================================

class ApiService {
  static Future<String> sendEmergencyRequest(
    String body,
  ) async {
    Object? lastError;

    for (
      int attempt = 1;
      attempt <= NetworkConfig.maxRequestAttempts;
      attempt++
    ) {
      http.Client? client;

      try {
        final uri = Uri.parse(
          '${apiBaseUrl()}/requests',
        );

        client = http.Client();

        final response = await client
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(
              NetworkConfig.requestTimeout,
            );

        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          return response.body;
        }

        if (response.statusCode >= 400 &&
            response.statusCode < 500) {
          return response.body;
        }

        lastError = Exception(
          'Response center returned HTTP '
          '${response.statusCode}.',
        );
      } catch (e) {
        lastError = e;
      } finally {
        client?.close();
      }

      if (attempt < NetworkConfig.maxRequestAttempts) {
        await Future.delayed(
          NetworkConfig.retryDelay(attempt),
        );
      }
    }

    throw Exception(
      'Unable to connect to the response center. '
      '${_formatNetworkError(lastError)}',
    );
  }

  static String _formatNetworkError(
    Object? error,
  ) {
    if (error == null) {
      return 'Please try again.';
    }

    final message = error.toString();

    if (message.contains('Failed host lookup')) {
      return 'The response server could not be found. '
          'Please check your internet connection.';
    }

    if (message.contains('SocketException')) {
      return 'Network connection failed. '
          'Please check your internet connection.';
    }

    if (message.contains('TimeoutException')) {
      return 'The response center is taking longer than expected. '
          'Please try again.';
    }

    return message.replaceFirst(
      'Exception: ',
      '',
    );
  }
}

// =========================================================
// APP
// =========================================================

class HopeRApp extends StatelessWidget {
  const HopeRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HOPE-R',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xfff5f7fb),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1456d9),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// =========================================================
// HOME SCREEN
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? position;
  bool locating = false;

  Future<void> captureLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Please turn on location services.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required.',
        );
      }

      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        NetworkConfig.locationTimeout,
      );

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Current location captured successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          locating = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  void openEmergencyRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyRequestScreen(
          initialPosition: position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 40 : 22,
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        _topBar(),
                        const SizedBox(height: 28),
                        _heroSection(),
                        const SizedBox(height: 28),
                        _emergencyButton(),
                        const SizedBox(height: 28),
                        _locationCard(),
                        const SizedBox(height: 24),
                        _infoCards(wide),
                        const SizedBox(height: 30),
                        const Text(
                          'HOPE-R Emergency Response',
                          style: TextStyle(
                            color: Color(0xff7b8494),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'One request can help coordinate an entire incident.',
                          style: TextStyle(
                            color: Color(0xff9aa2af),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xff1456d9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOPE-R',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff101828),
                ),
              ),
              Text(
                'Emergency Response',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xff667085),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.menu_rounded,
            color: Color(0xff344054),
          ),
        ),
      ],
    );
  }

  Widget _heroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff071a3d),
            Color(0xff123f91),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  color: Color(0xff58d68d),
                  size: 9,
                ),
                SizedBox(width: 7),
                Text(
                  'RESPONSE NETWORK ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'When every second matters.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Send an emergency request and share your location '
            'with the response authorities.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergencyButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: openEmergencyRequest,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffd92d3d),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffd92d3d)
                      .withValues(alpha: 0.28),
                  blurRadius: 35,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sos_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                  SizedBox(height: 5),
                  Text(
                    'EMERGENCY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'REQUEST EMERGENCY HELP',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xff101828),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap the button to create an emergency request',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xff667085),
          ),
        ),
      ],
    );
  }

  Widget _locationCard() {
    final hasLocation = position != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffe4e7ec),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hasLocation
                  ? const Color(0xffe9f8ef)
                  : const Color(0xffeef4ff),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              color: hasLocation
                  ? const Color(0xff159455)
                  : const Color(0xff1456d9),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your location',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xff101828),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLocation
                      ? '${position!.latitude.toStringAsFixed(6)}, '
                          '${position!.longitude.toStringAsFixed(6)}'
                      : 'Location not captured',
                  style: const TextStyle(
                    color: Color(0xff667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: locating ? null : captureLocation,
            child: Text(
              locating ? 'WAIT...' : 'CAPTURE',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCards(bool wide) {
    final cards = [
      (
        Icons.gps_fixed_rounded,
        'Precise Location',
        'Share your current GPS location with responders.',
      ),
      (
        Icons.groups_rounded,
        'People First',
        'Tell responders how many people need help.',
      ),
      (
        Icons.hub_rounded,
        'Smart Coordination',
        'Nearby requests can be grouped into one incident.',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((item) {
        return SizedBox(
          width: wide ? 310 : double.infinity,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xffe4e7ec),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.$1,
                  color: const Color(0xff1456d9),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: Color(0xff667085),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =========================================================
// EMERGENCY REQUEST SCREEN
// =========================================================

class EmergencyRequestScreen extends StatefulWidget {
  final Position? initialPosition;

  const EmergencyRequestScreen({
    super.key,
    this.initialPosition,
  });

  @override
  State<EmergencyRequestScreen> createState() =>
      _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState
    extends State<EmergencyRequestScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final detailsController = TextEditingController();

  String type = 'Medical Emergency';

  Position? position;

  int people = 1;
  int injured = 0;
  int trapped = 0;

  bool locating = false;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  Future<void> captureLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Please turn on location services.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required.',
        );
      }

      final newPosition =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        NetworkConfig.locationTimeout,
      );

      if (!mounted) return;

      setState(() {
        position = newPosition;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Current location captured successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          locating = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  Future<void> sendRequest() async {
    if (sending) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final details = detailsController.text.trim();

    if (name.isEmpty) {
      _error('Please enter your name.');
      return;
    }

    if (phone.isEmpty) {
      _error('Please enter your phone number.');
      return;
    }

    if (phone.length < 10) {
      _error('Please enter a valid phone number.');
      return;
    }

    if (position == null) {
      _error(
        'Please capture your current location.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      sending = true;
    });

    final body = jsonEncode({
      'name': name,
      'phone': phone,
      'type': type,
      'description': details,
      'latitude': position!.latitude,
      'longitude': position!.longitude,
      'people': people,
      'injured': injured,
      'trapped': trapped,
    });

    try {
      final responseBody =
          await ApiService.sendEmergencyRequest(body);

      Map<String, dynamic> data;

      try {
        final decoded = jsonDecode(responseBody);

        if (decoded is! Map) {
          throw Exception();
        }

        data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        throw Exception(
          'Response center returned an invalid response. '
          'Please try again.',
        );
      }

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'Emergency request could not be registered.',
        );
      }

      final requestId = data['requestId'];
      final disasterId = data['disasterId'];
      final action = data['action'];

      if (requestId == null || disasterId == null) {
        throw Exception(
          'Emergency request was received, but '
          'the response was incomplete.',
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestSuccessScreen(
            requestId: requestId,
            disasterId: disasterId,
            action: action ?? 'RECEIVED',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Emergency Request',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 760,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _progressHeader(),
                    const SizedBox(height: 22),
                    _sectionTitle(
                      'What happened?',
                      'Select the emergency type.',
                    ),
                    const SizedBox(height: 12),
                    _emergencyTypes(),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'Your details',
                      'Help responders identify and contact you.',
                    ),
                    const SizedBox(height: 12),
                    _detailsCard(),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'People affected',
                      'Provide the best estimate you can.',
                    ),
                    const SizedBox(height: 12),
                    _peopleCard(),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'Emergency location',
                      'Your GPS location is used to coordinate response.',
                    ),
                    const SizedBox(height: 12),
                    _locationCard(),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton.icon(
                        onPressed:
                            sending ? null : sendRequest,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xffd92d3d),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        icon: sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.sos_rounded,
                              ),
                        label: Text(
                          sending
                              ? 'CONNECTING TO RESPONSE CENTER...'
                              : 'SEND EMERGENCY REQUEST',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Your request will be securely sent to the response center.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff667085),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xffeef4ff),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xff1456d9),
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Stay calm. Provide accurate information so responders can act quickly.',
              style: TextStyle(
                color: Color(0xff344054),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xff101828),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xff667085),
          ),
        ),
      ],
    );
  }

  Widget _emergencyTypes() {
    final types = [
      ('Medical Emergency',
          Icons.medical_services_rounded),
      ('Fire', Icons.local_fire_department_rounded),
      ('Flood', Icons.water_rounded),
      ('Building Collapse',
          Icons.domain_disabled_rounded),
      ('Road Accident', Icons.car_crash_rounded),
      ('Rescue Needed', Icons.sos_rounded),
      ('Other', Icons.more_horiz_rounded),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((item) {
        final selected = type == item.$1;

        return GestureDetector(
          onTap: () {
            setState(() {
              type = item.$1;
            });
          },
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xff1456d9)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xff1456d9)
                    : const Color(0xffd0d5dd),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$2,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : const Color(0xff475467),
                ),
                const SizedBox(width: 7),
                Text(
                  item.$1,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xff344054),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textInputAction:
                TextInputAction.next,
            decoration:
                const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
              ),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType:
                TextInputType.phone,
            textInputAction:
                TextInputAction.next,
            decoration:
                const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(
                Icons.phone_outlined,
              ),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 4,
            decoration:
                const InputDecoration(
              labelText:
                  'Additional details (optional)',
              hintText:
                  'Describe what is happening...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleCard() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _counter(
            'People affected',
            people,
            (value) {
              setState(() {
                people = value;
              });
            },
            Icons.groups_rounded,
          ),
          const Divider(height: 1),
          _counter(
            'Injured',
            injured,
            (value) {
              setState(() {
                injured = value;
              });
            },
            Icons.personal_injury_rounded,
          ),
          const Divider(height: 1),
          _counter(
            'Trapped',
            trapped,
            (value) {
              setState(() {
                trapped = value;
              });
            },
            Icons.lock_rounded,
          ),
        ],
      ),
    );
  }

  Widget _counter(
    String label,
    int value,
    void Function(int) onChanged,
    IconData icon,
  ) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xff1456d9),
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: value > 0
                ? () => onChanged(value - 1)
                : null,
            icon: const Icon(
              Icons.remove_circle_outline,
            ),
          ),
          SizedBox(
            width: 30,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed:
                () => onChanged(value + 1),
            icon: const Icon(
              Icons.add_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color:
                      const Color(0xffeaf1ff),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xff1456d9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current GPS location',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      position == null
                          ? 'Location not captured'
                          : '${position!.latitude.toStringAsFixed(6)}, '
                              '${position!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xff667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  locating ? null : captureLocation,
              icon: locating
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.gps_fixed_rounded,
                    ),
              label: Text(
                locating
                    ? 'CAPTURING LOCATION...'
                    : position == null
                        ? 'USE CURRENT LOCATION'
                        : 'UPDATE LOCATION',
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xffe4e7ec),
      ),
    );
  }
}

// =========================================================
// SUCCESS SCREEN
// =========================================================

class RequestSuccessScreen extends StatelessWidget {
  final dynamic requestId;
  final dynamic disasterId;
  final dynamic action;

  const RequestSuccessScreen({
    super.key,
    required this.requestId,
    required this.disasterId,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xfff5f7fb),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 560,
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xffe9f8ef),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xff159455),
                      size: 55,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'REQUEST SENT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w900,
                      color: Color(0xff101828),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your emergency request has reached '
                    'the response center.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff667085),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            const Color(0xffe4e7ec),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'INCIDENT',
                          style: TextStyle(
                            color:
                                Color(0xff667085),
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '#$disasterId',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight:
                                FontWeight.w900,
                            color:
                                Color(0xff1456d9),
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        _statusRow(
                          Icons
                              .assignment_turned_in_rounded,
                          'Request registered',
                        ),
                        _statusRow(
                          Icons
                              .location_on_rounded,
                          'Location received',
                        ),
                        _statusRow(
                          Icons
                              .account_balance_rounded,
                          'Response center notified',
                        ),
                        const Divider(
                          height: 28,
                        ),
                        Row(
                          children: [
                            const Text(
                              'Request ID',
                              style: TextStyle(
                                color:
                                    Color(0xff667085),
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '#$requestId',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                color:
                                    Color(0xff667085),
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xffe9f8ef,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                '$action',
                                style:
                                    const TextStyle(
                                  color:
                                      Color(0xff159455),
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () {
                        Navigator
                            .pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusRow(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xff159455),
            size: 20,
          ),
          const SizedBox(width: 10),
          Icon(
            icon,
            color: const Color(0xff667085),
            size: 19,
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff344054),
            ),
          ),
        ],
      ),
    );
  }
}