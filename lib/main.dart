import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const MaritimeApp());
}

class MaritimeApp extends StatelessWidget {
  const MaritimeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hormuz Watch', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0b6f83), brightness: Brightness.dark), useMaterial3: true, scaffoldBackgroundColor: const Color(0xff091923)),
    home: supabaseUrl.isEmpty || supabaseAnonKey.isEmpty ? const SetupPage() : const SessionGate(),
  );
}
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: SafeArea(child: Center(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shield_outlined, size: 64), SizedBox(height: 18), Text('HORMUZ WATCH', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), SizedBox(height: 12), Text('Backend not configured. Add Supabase URL and anonymous publishable key using --dart-define. See README.md.', textAlign: TextAlign.center)])))));
}
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) => Supabase.instance.client.auth.currentUser == null ? const LoginPage() : const AccessGate(),
  );
}
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController(), company = TextEditingController();
  bool register = false, busy = false;
  String? message;
  Future<void> submit() async {
    setState(() { busy = true; message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text, data: {'full_name': name.text.trim(), 'company': company.text.trim()});
        setState(() => message = 'Registration submitted. Verify your email, then wait for administrator approval.');
      } else { await auth.signInWithPassword(email: email.text.trim(), password: password.text); }
    } catch (e) { setState(() => message = 'Unable to continue: $e'); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Hormuz Watch • Secure Access')), body: Center(child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    const Icon(Icons.shield, size: 60), const SizedBox(height: 12), const Text('MARITIME SECURITY INTELLIGENCE', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 24),
    if (register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')), TextField(controller: company, decoration: const InputDecoration(labelText: 'Company / department'))],
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Work email')),
    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (at least 8 characters)')),
    const SizedBox(height: 20), FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : register ? 'Request membership' : 'Sign in')),
    TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'Already registered? Sign in' : 'Request team access')),
    if (message != null) Padding(padding: const EdgeInsets.all(12), child: Text(message!, textAlign: TextAlign.center)),
  ]))))));
}
class AccessGate extends StatefulWidget { const AccessGate({super.key}); @override State<AccessGate> createState() => _AccessGateState(); }
class _AccessGateState extends State<AccessGate> {
  Future<Map<String,dynamic>?> load() async => await Supabase.instance.client.from('profiles').select('id,full_name,company,status,role').eq('id', Supabase.instance.client.auth.currentUser!.id).maybeSingle();
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>?>(future: load(), builder: (context, snap) {
    if (!snap.hasData && snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snap.hasError) return Scaffold(body: Center(child: Text('Unable to load membership: ${snap.error}')));
    final p = snap.data;
    if (p?['status'] == 'approved') return Dashboard(profile: p!);
    return Scaffold(appBar: AppBar(title: const Text('Membership approval')), body: Center(child: Padding(padding: const EdgeInsets.all(25), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.hourglass_top, size: 55), const SizedBox(height: 18), Text(p?['status'] == 'rejected' ? 'Access declined' : 'Your account is awaiting administrator approval', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)), const SizedBox(height: 12), const Text('Operational reports are unavailable until your membership is approved.'), TextButton(onPressed: () => setState(() {}), child: const Text('Check status')), TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out'))]))));
  });
}
class Dashboard extends StatefulWidget { final Map<String,dynamic> profile; const Dashboard({super.key, required this.profile}); @override State<Dashboard> createState() => _DashboardState(); }
class _DashboardState extends State<Dashboard> {
  int tab = 0;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('HORMUZ WATCH'), actions: [IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out')]), body: IndexedStack(index: tab, children: [const IncidentFeed(), const SourcesPage(), if (widget.profile['role'] == 'admin') const AdminPage()]), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [const NavigationDestination(icon: Icon(Icons.warning_amber), label: 'Incidents'), const NavigationDestination(icon: Icon(Icons.language), label: 'Sources'), if (widget.profile['role'] == 'admin') const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Approvals')]));
}
class IncidentFeed extends StatefulWidget { const IncidentFeed({super.key}); @override State<IncidentFeed> createState() => _IncidentFeedState(); }
class _IncidentFeedState extends State<IncidentFeed> {
  late Future<List<Map<String,dynamic>>> incidents;
  @override void initState() { super.initState(); refresh(); }
  void refresh() { incidents = Supabase.instance.client.from('incidents').select('id,title,summary,location,event_time,verification,severity,source_name,source_url,imo').order('event_time', ascending: false).limit(100); }
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async { setState(refresh); await incidents; }, child: FutureBuilder<List<Map<String,dynamic>>>(future: incidents, builder: (context, snap) {
    if (snap.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Unable to load incidents: ${snap.error}'))]);
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Source-verified incident register'), subtitle: Text('This feed shows reports entered into your team database. It is NOT an automatic live feed until a data-ingestion service is deployed. Pull down to refresh.'))), const SizedBox(height: 12), if (snap.data!.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No incidents published yet. An administrator can add verified or unverified reports after checking the original source.')),
      ...snap.data!.map((i) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(i['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))), Chip(label: Text(i['verification'] ?? 'unverified'))]), Text('${i['location'] ?? 'Unknown'} • ${i['severity'] ?? 'unknown'}'), Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(i['event_time']).toUtc().add(const Duration(hours: 3))) + ' Qatar'), const SizedBox(height: 8), Text(i['summary'] ?? ''), if (i['imo'] != null) Text('IMO: ${i['imo']}'), if (i['source_url'] != null) TextButton.icon(onPressed: () => launchUrl(Uri.parse(i['source_url']), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: Text('Open ${i['source_name'] ?? 'source'}'))]))))]);
  }));
}
class SourcesPage extends StatelessWidget { const SourcesPage({super.key});
  static const sources = <(String,String)>[('UKMTO','https://www.ukmto.org/recent-incidents'),('Ambrey','https://ambrey.com/'),('IRNA','https://en.irna.ir/'),('Tasnim','https://www.tasnimnews.com/en'),('Al Jazeera','https://www.aljazeera.com/'),('TankerTrackers','https://x.com/TankerTrackers'),('Vanguard','https://www.vanguard-tech.co.uk/'),('Reuters','https://www.reuters.com/'),('Lloyd’s List','https://www.lloydslist.com/'),('TradeWinds','https://www.tradewindsnews.com/')];
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [const ListTile(title: Text('Intelligence sources'), subtitle: Text('Open original sources. Some may require subscriptions or may be inaccessible.')), ...sources.map((s) => Card(child: ListTile(title: Text(s.$1), subtitle: Text(s.$2), trailing: const Icon(Icons.open_in_new), onTap: () => launchUrl(Uri.parse(s.$2), mode: LaunchMode.externalApplication))))]);
}
class AdminPage extends StatefulWidget { const AdminPage({super.key}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> {
  late Future<List<Map<String,dynamic>>> requests;
  @override void initState() { super.initState(); reload(); }
  void reload() { requests = Supabase.instance.client.from('profiles').select('id,full_name,company,status,role').order('created_at', ascending: false); }
  Future<void> decision(String id, String status) async { try { await Supabase.instance.client.from('profiles').update({'status': status}).eq('id', id); setState(reload); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }
  Future<void> addIncident() async {
    final title = TextEditingController(), summary = TextEditingController(), location = TextEditingController(), url = TextEditingController(), source = TextEditingController(), imo = TextEditingController();
    String verification = 'unverified', severity = 'medium';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(title: const Text('Publish incident report'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final pair in <(String,TextEditingController)>[('Title',title),('Summary',summary),('Location',location),('Source name',source),('Source URL (https://)',url),('Vessel IMO (optional)',imo)]) TextField(controller: pair.$2, decoration: InputDecoration(labelText: pair.$1)), DropdownButtonFormField<String>(initialValue: verification, items: ['confirmed','unverified','disputed'].map((v) => DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>update(()=>verification=v!)), DropdownButtonFormField<String>(initialValue: severity, items: ['low','medium','high','critical'].map((v) => DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>update(()=>severity=v!))])), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')), FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Publish'))])));
    if (ok != true) return;
    if (title.text.trim().isEmpty || source.text.trim().isEmpty || !Uri.tryParse(url.text.trim()).toString().startsWith('https://')) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title, source and HTTPS source URL are required.'))); return; }
    try { await Supabase.instance.client.from('incidents').insert({'title':title.text.trim(),'summary':summary.text.trim(),'location':location.text.trim(),'source_name':source.text.trim(),'source_url':url.text.trim(),'imo':imo.text.trim().isEmpty?null:imo.text.trim(),'verification':verification,'severity':severity,'event_time':DateTime.now().toUtc().toIso8601String()}); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident published.'))); } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to publish: $e'))); }
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(future: requests, builder: (context,snap) => ListView(padding: const EdgeInsets.all(16), children: [FilledButton.icon(onPressed: addIncident, icon: const Icon(Icons.add), label: const Text('Publish incident')), TextButton.icon(onPressed:()=>setState(reload), icon: const Icon(Icons.refresh), label: const Text('Refresh membership requests')), if(snap.hasError) Text('Error: ${snap.error}'), if(!snap.hasData && !snap.hasError) const Center(child:CircularProgressIndicator()), ...?snap.data?.map((p)=>Card(child: ListTile(title: Text(p['full_name'] ?? 'Member'), subtitle: Text('${p['company'] ?? ''} • ${p['status']} • ${p['role']}'), trailing: p['status']=='pending' ? Wrap(spacing: 2, children: [IconButton(tooltip:'Approve',onPressed:()=>decision(p['id'],'approved'),icon:const Icon(Icons.check_circle_outline)), IconButton(tooltip:'Reject',onPressed:()=>decision(p['id'],'rejected'),icon:const Icon(Icons.cancel_outlined))]) : p['role']=='admin' ? null : PopupMenuButton<String>(onSelected:(v)=>decision(p['id'],v),itemBuilder:(_)=>['approved','suspended','rejected'].map((v)=>PopupMenuItem(value:v,child:Text(v))).toList()))))]));
}
