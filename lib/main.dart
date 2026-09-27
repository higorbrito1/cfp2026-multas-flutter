import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const remoteDatabaseUrl =
    'https://raw.githubusercontent.com/higorbrito1/cfp2026-multas-flutter/main/assets/data/ctb-mbft.json';
const appName = 'Consulta CTB/MBFT';
const tacticalGreen = Color(0xff111414);
const tacticalPetrol = Color(0xffd7dddd);
const canvas = Color(0xff090b0b);
const darkSurface = Color(0xff151818);
const darkSurfaceAlt = Color(0xff202424);
const darkTextMuted = Color(0xffb9c1c1);
const darkAccent = Color(0xfff0f3f3);
const border = Color(0xff414848);

void main() => runApp(const CfpMultasApp());

class FineRecord {
  FineRecord(this.data);
  final Map<String, dynamic> data;
  String get id => '${data['id'] ?? ''}';
  String get title => '${data['title'] ?? data['summary'] ?? ''}';
  String get article => '${data['article'] ?? ''}';
  String get severity => '${data['severity'] ?? ''}';
  String get summary => '${data['summary'] ?? ''}';
  String value(String key) => '${data[key] ?? ''}'.trim();
}

class CfpMultasApp extends StatelessWidget {
  const CfpMultasApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: appName,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
              seedColor: tacticalGreen, brightness: Brightness.dark),
          scaffoldBackgroundColor: canvas,
          appBarTheme: const AppBarTheme(
              backgroundColor: tacticalGreen,
              foregroundColor: Colors.white,
              elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: tacticalGreen, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: border, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: tacticalGreen, width: 2)),
          ),
        ),
        home: const FineShell(),
      );
}

class FineShell extends StatefulWidget {
  const FineShell({super.key});
  @override
  State<FineShell> createState() => _FineShellState();
}

class _FineShellState extends State<FineShell> {
  final searchController = TextEditingController();
  List<FineRecord> records = [];
  Set<String> favorites = {};
  String query = '';
  String severityFilter = 'Todas';
  String databaseVersion = 'Base incluída no app';
  int selectedTab = 0;
  bool loading = true;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    _loadDatabase();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<FineRecord> _decodeRecords(String raw) => (jsonDecode(raw) as List)
      .map((item) => FineRecord(Map<String, dynamic>.from(item as Map)))
      .toList();

  Future<void> _loadDatabase() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('ctb_mbft_database');
    final raw =
        saved ?? await rootBundle.loadString('assets/data/ctb-mbft.json');
    final decoded = _decodeRecords(raw);
    if (!mounted) return;
    setState(() {
      records = decoded;
      databaseVersion = preferences.getString('ctb_mbft_version') ??
          (saved == null ? 'Base incluída no app' : 'Base atualizada');
      favorites =
          (preferences.getStringList('ctb_mbft_favorites') ?? []).toSet();
      loading = false;
    });
  }

  Future<void> _updateDatabase() async {
    setState(() => updating = true);
    try {
      final response = await http.get(Uri.parse(remoteDatabaseUrl));
      if (response.statusCode != 200) {
        throw Exception('Servidor respondeu ${response.statusCode}');
      }
      final decoded = _decodeRecords(response.body);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('ctb_mbft_database', response.body);
      final stamp =
          'Atualizada em ${DateTime.now().toLocal().toString().substring(0, 16)}';
      await preferences.setString('ctb_mbft_version', stamp);
      if (!mounted) return;
      setState(() {
        records = decoded;
        databaseVersion = stamp;
      });
      _showMessage('Base atualizada com ${decoded.length} fichas.');
    } catch (_) {
      if (mounted) {
        _showMessage('Sem conexão. A base offline continua disponível.');
      }
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> _toggleFavorite(FineRecord fine) async {
    final wasFavorite = favorites.contains(fine.id);
    setState(() => favorites.contains(fine.id)
        ? favorites.remove(fine.id)
        : favorites.add(fine.id));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('ctb_mbft_favorites', favorites.toList());
    _showMessage(wasFavorite
        ? 'Infração removida dos favoritos.'
        : 'Infração adicionada aos favoritos.');
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  void _openSearch([String initialQuery = '']) => setState(() {
        selectedTab = 1;
        query = initialQuery;
        searchController.text = initialQuery;
      });

  List<FineRecord> get filteredRecords {
    final tokens =
        normalize(query).split(' ').where((token) => token.isNotEmpty).toList();
    return records.where((fine) {
      final matchesSeverity = severityFilter == 'Todas' ||
          normalize(fine.severity) == normalize(severityFilter);
      final searchable = normalize(fine.data.values.join(' '));
      return matchesSeverity && tokens.every(searchable.contains);
    }).toList();
  }

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  void _openDetails(FineRecord fine) => showDialog<void>(
      context: context,
      builder: (context) => FineDetailsDialog(
          fine: fine,
          favorite: favorites.contains(fine.id),
          onFavorite: () => _toggleFavorite(fine)));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      HomeView(
        records: records,
        databaseVersion: databaseVersion,
        updating: updating,
        favoriteCount: favorites.length,
        onSearch: _openSearch,
        onUpdate: _updateDatabase,
      ),
      ConsultationView(
          controller: searchController,
          query: query,
          records: filteredRecords,
          severityFilter: severityFilter,
          favorites: favorites,
          onQuery: (value) => setState(() => query = value),
          onFilter: (value) => setState(() => severityFilter = value),
          onFavorite: _toggleFavorite,
          onDetails: _openDetails),
      FavoritesView(
          records:
              records.where((fine) => favorites.contains(fine.id)).toList(),
          onDetails: _openDetails,
          onFavorite: _toggleFavorite),
      MoreView(
          databaseVersion: databaseVersion,
          updating: updating,
          onUpdate: _updateDatabase),
    ];
    return Scaffold(
      body: SafeArea(top: false, child: pages[selectedTab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xff3a4040),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Consultar'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
        ],
      ),
    );
  }
}

class TacticalHeader extends StatelessWidget {
  const TacticalHeader({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: tacticalGreen,
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/icon/app_icon.png',
                  width: 28, height: 28, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: darkTextMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.cloud_done, color: darkAccent),
        ],
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView(
      {required this.records,
      required this.databaseVersion,
      required this.updating,
      required this.favoriteCount,
      required this.onSearch,
      required this.onUpdate,
      super.key});
  final List<FineRecord> records;
  final String databaseVersion;
  final bool updating;
  final int favoriteCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: TacticalHeader(
            title: appName,
            subtitle: 'CONSULTA OFFLINE DE LEGISLAÇÃO DE TRÂNSITO',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _databaseCard(),
              const SizedBox(height: 14),
              TextField(
                readOnly: true,
                onTap: () => onSearch(''),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Digite código (ex.: 501-00)',
                  suffixIcon: Icon(Icons.dialpad),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => onSearch(''),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: tacticalGreen,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xff000000), width: 2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.manage_search, color: darkAccent, size: 38),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'CONSULTAR\nINFRAÇÕES',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: .95),
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 34),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ATALHOS OPERACIONAIS RÁPIDOS',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: darkTextMuted,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              _shortcut(Icons.bookmark, 'Favoritos', '$favoriteCount salvas'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _databaseCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: darkSurface,
          border: const Border(
              left: BorderSide(color: tacticalGreen, width: 7),
              top: BorderSide(color: border),
              right: BorderSide(color: border),
              bottom: BorderSide(color: border)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle, color: tacticalGreen),
          SizedBox(width: 8),
          Text('Base CTB & MBFT pronta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))
        ]),
        const SizedBox(height: 8),
        Text(databaseVersion,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${records.length} infrações disponíveis offline',
            style: const TextStyle(
                color: darkAccent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: updating ? null : onUpdate,
            icon: updating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            label: Text(updating ? 'ATUALIZANDO...' : 'ATUALIZAR BASE'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: darkAccent,
                side: const BorderSide(color: darkAccent, width: 1.5)))
      ]));
  Widget _shortcut(IconData icon, String title, String subtitle,
          {VoidCallback? onTap}) =>
      Card(
          margin: EdgeInsets.zero,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: tacticalGreen),
                        const SizedBox(height: 10),
                        Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(subtitle,
                            style: const TextStyle(color: darkTextMuted))
                      ]))));
}

class ConsultationView extends StatelessWidget {
  const ConsultationView(
      {required this.controller,
      required this.query,
      required this.records,
      required this.severityFilter,
      required this.favorites,
      required this.onQuery,
      required this.onFilter,
      required this.onFavorite,
      required this.onDetails,
      super.key});
  final TextEditingController controller;
  final String query;
  final List<FineRecord> records;
  final String severityFilter;
  final Set<String> favorites;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onFilter;
  final ValueChanged<FineRecord> onFavorite;
  final ValueChanged<FineRecord> onDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TacticalHeader(
            title: appName, subtitle: 'Consulta de infrações e enquadramentos'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Código, artigo ou descrição',
              suffixIcon: query.isEmpty
                  ? const Icon(Icons.mic_none)
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['Todas', 'Gravíssima', 'Grave', 'Média', 'Leve']
                .map((filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: severityFilter == filter,
                        onSelected: (_) => onFilter(filter),
                      ),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Text('${records.length} infrações encontradas',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('Ordenar: Código',
                  style: TextStyle(color: darkTextMuted)),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const Center(child: Text('Nenhuma infração encontrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final fine = records[index];
                    return FineCard(
                      fine: fine,
                      favorite: favorites.contains(fine.id),
                      onTap: () => onDetails(fine),
                      onFavorite: () => onFavorite(fine),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class FineCard extends StatelessWidget {
  const FineCard(
      {required this.fine,
      required this.favorite,
      required this.onTap,
      required this.onFavorite,
      super.key});
  final FineRecord fine;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(8)),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          color: darkSurfaceAlt,
                          child: Text(fine.id,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: tacticalGreen))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              color: darkSurfaceAlt,
                              child: Text(fine.article,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)))),
                      IconButton(
                          onPressed: onFavorite,
                          icon: Icon(
                              favorite ? Icons.bookmark : Icons.bookmark_border,
                              color: favorite ? darkAccent : darkTextMuted))
                    ]),
                    const SizedBox(height: 6),
                    SeverityBadge(fine.severity),
                    if (favorite)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(children: [
                            Icon(Icons.bookmark, size: 17, color: darkAccent),
                            SizedBox(width: 5),
                            Text('ADICIONADA AOS FAVORITOS',
                                style: TextStyle(
                                    color: darkAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11))
                          ])),
                    const SizedBox(height: 10),
                    Text(fine.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.25)),
                    const SizedBox(height: 10),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        color: darkSurfaceAlt,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Penalidade: ${fine.value('penalty')}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                  'Medida administrativa: ${fine.value('measure')}'),
                              const SizedBox(height: 6),
                              Text('Constatação: ${fine.value('detection')}')
                            ])),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: Text(fine.value('competence'),
                              style: const TextStyle(
                                  color: darkAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      const Text('DETALHES ›',
                          style: TextStyle(
                              color: tacticalGreen,
                              fontWeight: FontWeight.w800))
                    ])
                  ]))));
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key});
  final String severity;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: severityColor(severity),
      child: Text(severity.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)));
}

Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'gravíssima':
      return const Color(0xff991b1b);
    case 'grave':
      return const Color(0xffc2410c);
    case 'média':
      return const Color(0xffb45309);
    default:
      return const Color(0xff0e7490);
  }
}

class FavoritesView extends StatelessWidget {
  const FavoritesView(
      {required this.records,
      required this.onDetails,
      required this.onFavorite,
      super.key});
  final List<FineRecord> records;
  final ValueChanged<FineRecord> onDetails;
  final ValueChanged<FineRecord> onFavorite;
  @override
  Widget build(BuildContext context) => Column(children: [
        const TacticalHeader(
            title: 'Favoritos',
            subtitle: 'Infrações salvas para consulta rápida'),
        Expanded(
            child: records.isEmpty
                ? const Center(child: Text('Nenhuma infração favorita ainda.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: records
                        .map((fine) => FineCard(
                            fine: fine,
                            favorite: true,
                            onTap: () => onDetails(fine),
                            onFavorite: () => onFavorite(fine)))
                        .toList()))
      ]);
}

class MoreView extends StatelessWidget {
  const MoreView(
      {required this.databaseVersion,
      required this.updating,
      required this.onUpdate,
      super.key});
  final String databaseVersion;
  final bool updating;
  final VoidCallback onUpdate;
  @override
  Widget build(BuildContext context) => Column(children: [
        const TacticalHeader(title: 'Mais', subtitle: 'Configurações'),
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: ListTile(
                  leading: const Icon(Icons.sync, color: darkAccent),
                  title: const Text('Atualizar base CTB/MBFT',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(databaseVersion),
                  trailing: updating
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.chevron_right),
                  onTap: updating ? null : onUpdate)),
          const SizedBox(height: 32),
          const Center(
              child: Text('Feito por Higor Brito',
                  style: TextStyle(color: darkTextMuted, fontSize: 12)))
        ]))
      ]);
}

class FineDetailsDialog extends StatefulWidget {
  const FineDetailsDialog(
      {required this.fine,
      required this.favorite,
      required this.onFavorite,
      super.key});
  final FineRecord fine;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  State<FineDetailsDialog> createState() => _FineDetailsDialogState();
}

class _FineDetailsDialogState extends State<FineDetailsDialog> {
  late bool favorite;

  @override
  void initState() {
    super.initState();
    favorite = widget.favorite;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          insetPadding: const EdgeInsets.all(12),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          title: Row(children: [
            IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close)),
            const Expanded(child: Text('Detalhes do enquadramento')),
            IconButton(
                onPressed: () {
                  setState(() => favorite = !favorite);
                  widget.onFavorite();
                },
                icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border,
                    color: tacticalGreen))
          ]),
          content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: darkSurfaceAlt, border: Border.all(color: border)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('CÓDIGO: ${widget.fine.id}',
                              style: const TextStyle(
                                  color: darkAccent,
                                  fontWeight: FontWeight.w800)),
                          const Spacer(),
                          SeverityBadge(widget.fine.severity)
                        ]),
                        const SizedBox(height: 10),
                        Text(widget.fine.article,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 10),
                        Text(widget.fine.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.3))
                      ]),
                ),
                const SizedBox(height: 14),
                ...[
                  ['Tipificação', widget.fine.title],
                  ['Gravidade', widget.fine.value('severity')],
                  ['Pontuação', widget.fine.value('points')],
                  ['Penalidade', widget.fine.value('penalty')],
                  ['Medida administrativa', widget.fine.value('measure')],
                  ['Infrator', widget.fine.value('offender')],
                  ['Constatação', widget.fine.value('detection')],
                  ['Crime de trânsito', widget.fine.value('crime')],
                  ['Competência', widget.fine.value('competence')]
                ].map((item) => _field(item[0], item[1])),
                const Divider(),
                ...[
                  ['Quando autuar', 'whenToAutuate'],
                  ['Quando não autuar', 'whenNotToAutuate'],
                  ['Definições e procedimentos', 'procedures'],
                  ['Exemplos para observações do AIT', 'examples'],
                  ['Informações complementares', 'additional']
                ].where((item) => widget.fine.value(item[1]).isNotEmpty).map(
                    (item) => ExpansionTile(
                            title: Text(item[0],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            tilePadding: EdgeInsets.zero,
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(widget.fine.value(item[1]),
                                          style:
                                              const TextStyle(height: 1.35))))
                            ]))
              ])),
          actions: [
            OutlinedButton.icon(
                onPressed: () {
                  setState(() => favorite = !favorite);
                  widget.onFavorite();
                },
                icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
                label: Text(favorite ? 'Salvo' : 'Favoritar')),
            FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text:
                          '${widget.fine.id} - ${widget.fine.title}\n${widget.fine.value('penalty')}\n${widget.fine.value('measure')}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informações copiadas.')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'))
          ]);
  Widget _field(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: darkTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
        Text(value.isEmpty ? 'Não informado na ficha' : value,
            style: const TextStyle(fontSize: 15, height: 1.3))
      ]));
}
