import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

String apiBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:3000';
  }

  return 'http://10.0.2.2:3000';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HopeRGovernmentApp());
}

class HopeRGovernmentApp extends StatelessWidget {
  const HopeRGovernmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF155EEF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HOPE-R Government',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        fontFamily: 'Arial',
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF101828),
          centerTitle: false,
        ),
      ),
      home: const GovernmentConsole(),
    );
  }
}

class GovernmentConsole extends StatefulWidget {
  const GovernmentConsole({super.key});

  @override
  State<GovernmentConsole> createState() => _GovernmentConsoleState();
}

class _GovernmentConsoleState extends State<GovernmentConsole> {
  int selectedPage = 0;

  bool loading = true;
  bool refreshing = false;
  String? error;

  List<dynamic> disasters = [];
  List<dynamic> requests = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<dynamic> getApi(String path) async {
    final response = await http
        .get(
          Uri.parse('${apiBaseUrl()}$path'),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Server returned ${response.statusCode}',
      );
    }

    return jsonDecode(response.body);
  }

  Future<void> loadData({bool silent = false}) async {
    if (loading == false && !silent && mounted) {
      setState(() {
        refreshing = true;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        getApi('/disasters'),
        getApi('/requests'),
      ]);

      final disasterResponse = results[0];
      final requestResponse = results[1];

      if (!mounted) return;

      setState(() {
        disasters = List<dynamic>.from(
          disasterResponse['data'] ?? [],
        );

        requests = List<dynamic>.from(
          requestResponse['data'] ?? [],
        );

        error = null;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = cleanError(e);
        loading = false;
        refreshing = false;
      });
    }
  }

  String cleanError(Object error) {
    final text = error.toString();

    if (text.contains('TimeoutException')) {
      return 'HOPE-R server took too long to respond.';
    }

    if (text.contains('Failed host lookup')) {
      return 'Unable to reach the HOPE-R server.';
    }

    if (text.contains('ClientException')) {
      return 'Unable to connect to the HOPE-R server.';
    }

    return text.replaceFirst('Exception: ', '');
  }

  Future<void> assignService(
    int disasterId,
    String service,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${apiBaseUrl()}/disasters/$disasterId/assign',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'service': service,
            }),
          )
          .timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Assignment failed (${response.statusCode})',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '$service assigned to Incident #$disasterId',
          ),
        ),
      );

      await loadData(silent: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Unable to assign $service',
          ),
        ),
      );
    }
  }

  int get criticalCount {
    return disasters.where((item) {
      return '${item['priority']}' == 'CRITICAL';
    }).length;
  }

  int get activeRequestCount {
    return requests.length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FC),
          body: Row(
            children: [
              if (desktop) buildSideBar(),
              Expanded(
                child: Column(
                  children: [
                    buildTopBar(desktop),
                    Expanded(
                      child: loading
                          ? const LoadingView()
                          : error != null
                              ? ErrorView(
                                  message: error!,
                                  onRetry: loadData,
                                )
                              : buildContent(desktop),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : buildMobileNavigation(),
        );
      },
    );
  }

  Widget buildSideBar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE4E7EC),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            buildBrand(),
            const SizedBox(height: 28),
            buildSideItem(
              icon: Icons.dashboard_rounded,
              label: 'Command Center',
              index: 0,
            ),
            buildSideItem(
              icon: Icons.warning_amber_rounded,
              label: 'Incidents',
              index: 1,
              badge: disasters.length,
            ),
            buildSideItem(
              icon: Icons.assignment_rounded,
              label: 'Emergency Requests',
              index: 2,
              badge: requests.length,
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 19,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Response Console',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Government',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget buildBrand() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF155EEF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOPE-R',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Government Console',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSideItem({
    required IconData icon,
    required String label,
    required int index,
    int? badge,
  }) {
    final selected = selectedPage == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            selectedPage = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF1FF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected
                    ? const Color(0xFF155EEF)
                    : const Color(0xFF667085),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF155EEF)
                        : const Color(0xFF344054),
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badge != null && badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF155EEF)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : const Color(0xFF667085),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopBar(bool desktop) {
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 28 : 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE4E7EC),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!desktop)
            buildBrandMobile()
          else
            Expanded(
              child: Text(
                pageTitle(),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (!desktop) const Spacer(),
          if (refreshing)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => loadData(),
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEAFBF0),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF12B76A),
                ),
                SizedBox(width: 7),
                Text(
                  'SYSTEM ONLINE',
                  style: TextStyle(
                    color: Color(0xFF087443),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBrandMobile() {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF155EEF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'HOPE-R',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  String pageTitle() {
    switch (selectedPage) {
      case 1:
        return 'Active Incidents';
      case 2:
        return 'Emergency Requests';
      default:
        return 'Command Center';
    }
  }

  Widget buildContent(bool desktop) {
    switch (selectedPage) {
      case 1:
        return buildIncidentsPage(desktop);
      case 2:
        return buildRequestsPage(desktop);
      default:
        return buildHomePage(desktop);
    }
  }

  Widget buildHomePage(bool desktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        desktop ? 28 : 18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1250,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              buildHero(desktop),
              const SizedBox(height: 20),
              buildStats(desktop),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active incidents',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Automatically grouped emergency activity',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedPage = 1;
                      });
                    },
                    child: const Text(
                      'View all',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (disasters.isEmpty)
                const EmptyState(
                  title: 'No active incidents',
                  message:
                      'New emergency requests will appear here.',
                  icon: Icons.shield_outlined,
                )
              else
                ...disasters
                    .take(5)
                    .map(buildIncidentCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHero(bool desktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        desktop ? 30 : 22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B1F4D),
            Color(0xFF155EEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'NATIONAL RESPONSE NETWORK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  desktop
                      ? 'Command Center'
                      : 'Response Command',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: desktop ? 34 : 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor emergency requests, identify nearby incidents, '
                  'and coordinate essential response services.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (desktop)
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildStats(bool desktop) {
    final cards = [
      buildStatCard(
        'ACTIVE INCIDENTS',
        disasters.length,
        Icons.warning_amber_rounded,
        const Color(0xFFD92D20),
      ),
      buildStatCard(
        'EMERGENCY REQUESTS',
        activeRequestCount,
        Icons.assignment_rounded,
        const Color(0xFF155EEF),
      ),
      buildStatCard(
        'CRITICAL',
        criticalCount,
        Icons.priority_high_rounded,
        const Color(0xFFF04438),
      ),
    ];

    if (desktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 14),
          Expanded(child: cards[1]),
          const SizedBox(width: 14),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
          ],
        ),
      ],
    );
  }

  Widget buildStatCard(
    String label,
    int value,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

  Widget buildIncidentsPage(bool desktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        desktop ? 28 : 18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1250,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              buildPageHeader(
                'Active Incidents',
                'Emergency requests grouped by nearby location.',
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 18),
              if (disasters.isEmpty)
                const EmptyState(
                  title: 'No active incidents',
                  message:
                      'There are currently no active emergency incidents.',
                  icon: Icons.warning_amber_outlined,
                )
              else
                ...disasters.map(buildIncidentCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRequestsPage(bool desktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        desktop ? 28 : 18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1250,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              buildPageHeader(
                'Emergency Requests',
                'Individual civilian requests received by HOPE-R.',
                Icons.assignment_rounded,
              ),
              const SizedBox(height: 18),
              if (requests.isEmpty)
                const EmptyState(
                  title: 'No emergency requests',
                  message:
                      'New civilian requests will appear here.',
                  icon: Icons.assignment_outlined,
                )
              else
                ...requests.map(buildRequestCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPageHeader(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF155EEF),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildIncidentCard(dynamic disaster) {
    final id = disaster['id'];
    final type = '${disaster['type'] ?? 'Emergency'}';
    final priority =
        '${disaster['priority'] ?? 'MEDIUM'}';

    final requestCount =
        disaster['requestCount'] ?? 0;
    final people = disaster['people'] ?? 0;
    final injured = disaster['injured'] ?? 0;
    final trapped = disaster['trapped'] ?? 0;

    final priorityInfo =
        priorityStyle(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailPage(
                disaster: disaster,
                onAssign: assignService,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4ED),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Incident #$id',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityInfo.color
                          .withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(
                        color: priorityInfo.color,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF98A2B3),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    buildMiniMetric(
                      Icons.assignment_outlined,
                      '$requestCount',
                      'Requests',
                    ),
                    buildDivider(),
                    buildMiniMetric(
                      Icons.groups_rounded,
                      '$people',
                      'People',
                    ),
                    buildDivider(),
                    buildMiniMetric(
                      Icons.medical_services_outlined,
                      '$injured',
                      'Injured',
                    ),
                    buildDivider(),
                    buildMiniMetric(
                      Icons.lock_person_outlined,
                      '$trapped',
                      'Trapped',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${disaster['latitude']}, '
                      '${disaster['longitude']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
                  const Text(
                    'VIEW DETAILS',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF155EEF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMiniMetric(
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF667085),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDivider() {
    return Container(
      height: 28,
      width: 1,
      margin: const EdgeInsets.symmetric(
        horizontal: 9,
      ),
      color: const Color(0xFFE4E7EC),
    );
  }

  Widget buildRequestCard(dynamic request) {
    final civilian = request['civilian'];

    final name =
        civilian?['name'] ?? 'Civilian';
    final phone =
        civilian?['phone'] ?? 'No phone';
    final type =
        '${request['type'] ?? 'Emergency'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF155EEF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$type • #${request['id']}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$name • $phone',
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${request['description'] ?? 'No additional details provided.'}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      requestInfo(
                        'People',
                        '${request['people'] ?? 0}',
                      ),
                      requestInfo(
                        'Injured',
                        '${request['injured'] ?? 0}',
                      ),
                      requestInfo(
                        'Trapped',
                        '${request['trapped'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'GPS  ${request['latitude']}, ${request['longitude']}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Widget requestInfo(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475467),
        ),
      ),
    );
  }

  Widget buildMobileNavigation() {
    return NavigationBar(
      selectedIndex: selectedPage,
      onDestinationSelected: (index) {
        setState(() {
          selectedPage = index;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon:
              Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.warning_amber_outlined),
          selectedIcon:
              Icon(Icons.warning_rounded),
          label: 'Incidents',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.assignment_outlined),
          selectedIcon:
              Icon(Icons.assignment_rounded),
          label: 'Requests',
        ),
      ],
    );
  }

  ({Color color}) priorityStyle(String priority) {
    if (priority == 'CRITICAL') {
      return (
        color: const Color(0xFFD92D20),
      );
    }

    if (priority == 'HIGH') {
      return (
        color: const Color(0xFFDC6803),
      );
    }

    return (
      color: const Color(0xFF155EEF),
    );
  }
}

class IncidentDetailPage extends StatefulWidget {
  final dynamic disaster;

  final Future<void> Function(
    int disasterId,
    String service,
  ) onAssign;

  const IncidentDetailPage({
    super.key,
    required this.disaster,
    required this.onAssign,
  });

  @override
  State<IncidentDetailPage> createState() =>
      _IncidentDetailPageState();
}

class _IncidentDetailPageState
    extends State<IncidentDetailPage> {
  String? assigningService;

  List<dynamic> get incidentRequests {
    return List<dynamic>.from(
      widget.disaster['requests'] ?? [],
    );
  }

  List<dynamic> get assignments {
    return List<dynamic>.from(
      widget.disaster['assignments'] ?? [],
    );
  }

  Future<void> assign(String service) async {
    if (assigningService != null) return;

    setState(() {
      assigningService = service;
    });

    try {
      await widget.onAssign(
        widget.disaster['id'],
        service,
      );
    } finally {
      if (mounted) {
        setState(() {
          assigningService = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude =
        (widget.disaster['latitude'] as num)
            .toDouble();

    final longitude =
        (widget.disaster['longitude'] as num)
            .toDouble();

    final priority =
        '${widget.disaster['priority'] ?? 'MEDIUM'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Incident Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop =
              constraints.maxWidth >= 950;

          return SingleChildScrollView(
            padding: EdgeInsets.all(
              desktop ? 28 : 18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    buildIncidentHeader(priority),
                    const SizedBox(height: 18),
                    buildSummary(),
                    const SizedBox(height: 18),
                    if (desktop)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: buildLocationCard(
                              latitude,
                              longitude,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: buildServicesCard(),
                          ),
                        ],
                      )
                    else ...[
                      buildLocationCard(
                        latitude,
                        longitude,
                      ),
                      const SizedBox(height: 18),
                      buildServicesCard(),
                    ],
                    const SizedBox(height: 20),
                    buildAssignments(),
                    const SizedBox(height: 24),
                    buildRequestsSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildIncidentHeader(String priority) {
    final color = priority == 'CRITICAL'
        ? const Color(0xFFD92D20)
        : priority == 'HIGH'
            ? const Color(0xFFDC6803)
            : const Color(0xFF155EEF);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4ED),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.warning_rounded,
            color: Color(0xFFD92D20),
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.disaster['type']}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Incident #${widget.disaster['id']}',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 32,
          runSpacing: 18,
          children: [
            detailMetric(
              'REQUESTS',
              '${widget.disaster['requestCount'] ?? 0}',
              Icons.assignment_outlined,
            ),
            detailMetric(
              'PEOPLE',
              '${widget.disaster['people'] ?? 0}',
              Icons.groups_rounded,
            ),
            detailMetric(
              'INJURED',
              '${widget.disaster['injured'] ?? 0}',
              Icons.medical_services_outlined,
            ),
            detailMetric(
              'TRAPPED',
              '${widget.disaster['trapped'] ?? 0}',
              Icons.lock_person_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget detailMetric(
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF155EEF),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildLocationCard(
    double latitude,
    double longitude,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF155EEF),
                ),
                SizedBox(width: 8),
                Text(
                  'Incident Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          MapPreview(
            latitude: latitude,
            longitude: longitude,
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXACT GPS COORDINATES',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  '$latitude, $longitude',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildServicesCard() {
    const services = [
      (
        name: 'Ambulance',
        icon: Icons.local_hospital_rounded,
      ),
      (
        name: 'Food',
        icon: Icons.restaurant_rounded,
      ),
      (
        name: 'Clothes',
        icon: Icons.checkroom_rounded,
      ),
      (
        name: 'Service',
        icon: Icons.handyman_rounded,
      ),
      (
        name: 'Rescue Team',
        icon: Icons.groups_rounded,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Response Services',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Assign the required response service.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 15),
            ...services.map(
              (service) {
                final busy =
                    assigningService ==
                        service.name;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 9,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          assigningService != null
                              ? null
                              : () => assign(
                                    service.name,
                                  ),
                      style:
                          OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        alignment:
                            Alignment.centerLeft,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            service.icon,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              service.name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              height: 17,
                              width: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Icon(
                              Icons.add_task_rounded,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAssignments() {
    if (assignments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF12B76A),
                ),
                SizedBox(width: 8),
                Text(
                  'Assigned Services',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...assignments.map(
              (assignment) {
                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFEAFBF0),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: Color(0xFF12B76A),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${assignment['service']}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Text(
                        'ASSIGNED',
                        style: TextStyle(
                          color: Color(0xFF087443),
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRequestsSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Civilian Requests',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Requests automatically grouped into this incident.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 13),
        if (incidentRequests.isEmpty)
          const EmptyState(
            title: 'No underlying requests',
            message:
                'No individual requests were returned for this incident.',
            icon: Icons.assignment_outlined,
          )
        else
          ...incidentRequests.map(
            buildIncidentRequest,
          ),
      ],
    );
  }

  Widget buildIncidentRequest(dynamic request) {
    final civilian = request['civilian'];

    final name =
        civilian?['name'] ?? 'Civilian';
    final phone =
        civilian?['phone'] ?? '';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  child: Icon(
                    Icons.person_rounded,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$phone',
                        style:
                            const TextStyle(
                          color:
                              Color(0xFF667085),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFEAF1FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${request['type']}',
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF155EEF),
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              '${request['description'] ?? 'No additional details provided.'}',
              style: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                infoChip(
                  'People',
                  '${request['people'] ?? 0}',
                ),
                infoChip(
                  'Injured',
                  '${request['injured'] ?? 0}',
                ),
                infoChip(
                  'Trapped',
                  '${request['trapped'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              'Exact GPS: '
              '${request['latitude']}, '
              '${request['longitude']}',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoChip(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475467),
        ),
      ),
    );
  }
}

class MapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;

  const MapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    const zoom = 14;

    final n = math.pow(
      2,
      zoom,
    );

    final x = ((longitude + 180) / 360 * n)
        .floor();

    final latitudeRad =
        latitude * math.pi / 180;

    final y = ((1 -
                (math.log(
                      math.tan(
                            latitudeRad,
                          ) +
                          1 /
                              math.cos(
                                latitudeRad,
                              ),
                    ) /
                    math.pi)) /
            2 *
            n)
        .floor();

    final tileUrl =
        'https://tile.openstreetmap.org/'
        '$zoom/$x/$y.png';

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            tileUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            loadingBuilder:
                (
              context,
              child,
              loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                color: const Color(0xFFF2F4F7),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading map...',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder:
                (
              context,
              error,
              stackTrace,
            ) {
              return Container(
                color: const Color(0xFFF2F4F7),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 35,
                      color: Color(0xFF98A2B3),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Map preview unavailable',
                      style: TextStyle(
                        color:
                            Color(0xFF667085),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Center(
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFD92D20),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.94),
                borderRadius:
                    BorderRadius.circular(9),
              ),
              child: Text(
                '${latitude.toStringAsFixed(5)}, '
                '${longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 15),
          Text(
            'Connecting to HOPE-R',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Loading response data...',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 430,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFF4ED,
                      ),
                      borderRadius:
                          BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFD92D20),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to connect',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      'RETRY',
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
}

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: const Color(0xFF98A2B3),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}