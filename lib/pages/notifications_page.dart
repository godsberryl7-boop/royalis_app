import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool initialisant = true;
  RealtimeChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    chargerNotificationsRealtime();
  }

  @override
  void dispose() {
    // Très important : se désabonner du canal pour éviter les fuites de mémoire
    if (_notifChannel != null) {
      Supabase.instance.client.removeChannel(_notifChannel!);
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> chargerNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('utilisateur', user.email!)
        .order('created_at', ascending: false);

    // Marquer les notifications comme lues de manière asynchrone
    Supabase.instance.client
        .from('notifications')
        .update({'lu': true})
        .eq('utilisateur', user.email!)
        .then((_) => debugPrint("Notifications marquées comme lues"))
        .catchError((e) => debugPrint("Erreur marquage lu : $e"));

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> chargerNotificationsRealtime() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        initialisant = false;
      });
      return;
    }

    notifications = await chargerNotifications();
    if (mounted) {
      setState(() {
        initialisant = false;
      });
    }

    // Écoute des changements en temps réel
    _notifChannel = Supabase.instance.client
        .channel('notifications-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) async {
            debugPrint("NOTIFICATION REÇUE EN DIRECT");
            final nouvellesNotifs = await chargerNotifications();
            if (mounted) {
              setState(() {
                notifications = nouvellesNotifs;
              });
            }
          },
        );

    _notifChannel?.subscribe();
  }

  // Formatage simple et élégant de la date
  String formaterDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final difference = DateTime.now().difference(date);

      if (difference.inMinutes < 60) {
        return "Il y a ${difference.inMinutes} min";
      } else if (difference.inHours < 24) {
        return "Il y a ${difference.inHours} h";
      } else {
        return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}";
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: initialisant
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Aucune notification",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Vous serez averti ici de vos activités d'enchères",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFD4AF37),
                  onRefresh: () async {
                    final rafraichi = await chargerNotifications();
                    setState(() {
                      notifications = rafraichi;
                    });
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      final bool estLu = notif['lu'] ?? true; 

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          // ✨ Correction moderne de withOpacity avec withValues
                          backgroundColor: estLu 
                              ? const Color(0xFF1F2937).withValues(alpha: 0.05)
                              : const Color(0xFFD4AF37).withValues(alpha: 0.12),
                          child: Icon(
                            estLu ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                            color: estLu ? const Color(0xFF1F2937) : const Color(0xFFD4AF37),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          notif['message'] ?? "",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: estLu ? FontWeight.normal : FontWeight.bold,
                            color: const Color(0xFF1F2937),
                            height: 1.3,
                          ),
                        ),
                        subtitle: notif['created_at'] != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  formaterDate(notif['created_at']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              )
                            : null,
                        trailing: !estLu
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}