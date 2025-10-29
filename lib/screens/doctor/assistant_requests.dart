import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_slot/screens/login_screen.dart';

class DoctorDashboard extends StatefulWidget {
  final String doctorId;
  const DoctorDashboard({
    Key? key,
    required this.doctorId, // named required parameter
  }) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {

  final supabase = Supabase.instance.client;
  List<dynamic> pendingAssistants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingAssistants();
  }

  Future<void> fetchPendingAssistants() async {
    setState(() => isLoading = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get doctor_id for current user
      final doctor = await supabase
          .from('doctors')
          .select('doctor_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (doctor == null) return;

      final doctorId = doctor['doctor_id'];

      // Fetch pending assistants
      final data = await supabase
          .from('assistants')
          .select('assistant_id, user_id, phone, gender')
          .eq('assigned_doctor_id', doctorId)
          .eq('status', 'pending');

      List<dynamic> assistantsWithProfiles = [];
      for (var assistant in data) {
        final profile = await supabase
            .from('profiles')
            .select('name, email')
            .eq('id', assistant['user_id'])
            .maybeSingle();

        if (profile != null) {
          assistantsWithProfiles.add({
            ...assistant,
            'name': profile['name'] ?? 'Unknown',
            'email': profile['email'] ?? '',
          });
        }
      }

      setState(() => pendingAssistants = assistantsWithProfiles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching assistants: $e")),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> approveAssistant(String assistantId) async {
    try {
      await supabase
          .from('assistants')
          .update({'status': 'approved'})
          .eq('assistant_id', assistantId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Assistant approved!")),
      );
      fetchPendingAssistants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error approving assistant: $e")),
      );
    }
  }

  Future<void> rejectAssistant(String assistantId) async {
    try {
      await supabase
          .from('assistants')
          .update({'status': 'rejected'})
          .eq('assistant_id', assistantId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Assistant rejected!")),
      );
      fetchPendingAssistants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting assistant: $e")),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing out: $e")),
        );
      }
    }
  }

  Widget buildAssistantCard(Map assistant, int index) {
    final colors = [
      [Colors.deepPurple, Colors.purpleAccent],
      [Colors.teal, Colors.greenAccent],
      [Colors.indigo, Colors.blueAccent],
      [Colors.orange, Colors.deepOrangeAccent],
    ];

    final name = assistant['name'] ?? 'Unknown';
    final email = assistant['email'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors[index % colors.length],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "Phone: ${assistant['phone'] ?? 'N/A'} • ${assistant['gender'] ?? 'N/A'}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    onPressed: () => approveAssistant(assistant['assistant_id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => rejectAssistant(assistant['assistant_id']),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // teal → sky blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Assistant Requests",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 6,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingAssistants.isEmpty
          ? const Center(
        child: Text(
          "No pending assistant requests 🤝",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: pendingAssistants.length,
        itemBuilder: (context, index) =>
            buildAssistantCard(pendingAssistants[index], index),
      ),
    );
  }
}
