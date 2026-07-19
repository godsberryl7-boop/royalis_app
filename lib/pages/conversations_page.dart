import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late final Stream<List<Map<String, dynamic>>> _conversationsStream;
  final String? _currentUserEmail = Supabase.instance.client.auth.currentUser?.email;

  @override
  void initState() {
    super.initState();
    _initConversationsStream();
  }

  void _initConversationsStream() {
    if (_currentUserEmail == null) return;

    // Écoute les conversations de l'utilisateur connecté en temps réel
    _conversationsStream = Supabase.instance.client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
  }

  // Permet de récupérer en temps réel le tout dernier message d'une conversation spécifique
  Stream<List<Map<String, dynamic>>> _dernierMessageStream(int conversationId) {
    return Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1);
  }

  // Récupère les détails de l'article (Sécurisé en cas de suppression)
  Future<Map<String, dynamic>?> _obtenirDetailsArticle(int articleId) async {
    try {
      final data = await Supabase.instance.client
          .from('articles')
          .select('nom')
          .eq('id', articleId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserEmail == null) {
      return const Scaffold(
        body: Center(
          child: Text("Veuillez vous connecter pour voir vos messages."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _conversationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            );
          }

          // Filtrage côté client pour s'assurer qu'on affiche uniquement les convs de l'user
          final conversations = (snapshot.data ?? []).where((conv) {
            return conv['vendeur'] == _currentUserEmail || conv['acheteur'] == _currentUserEmail;
          }).toList();

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Aucune discussion pour le moment",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              
              final estAcheteur = conv['acheteur'] == _currentUserEmail;
              final correspondant = estAcheteur ? conv['vendeur'] : conv['acheteur'];
              final initiale = correspondant != null && correspondant.isNotEmpty
                  ? correspondant[0].toUpperCase()
                  : "?";

              return FutureBuilder<Map<String, dynamic>?>(
                future: _obtenirDetailsArticle(conv['article_id']),
                builder: (context, articleSnapshot) {
                  final articleNom = articleSnapshot.data?['nom'] ?? "Article inconnu";

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _dernierMessageStream(conv['id']),
                    builder: (context, messageSnapshot) {
                      final messages = messageSnapshot.data ?? [];
                      final dernierMsgText = messages.isNotEmpty 
                          ? messages.first['message'] as String 
                          : "Discussion ouverte pour l'article : $articleNom";

                      String heureFormatee = "";
                      if (messages.isNotEmpty && messages.first['created_at'] != null) {
                        final date = DateTime.parse(messages.first['created_at']).toLocal();
                        heureFormatee = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          child: Text(
                            initiale,
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                correspondant ?? "Utilisateur",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (heureFormatee.isNotEmpty)
                              Text(
                                heureFormatee,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Objet : $articleNom",
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dernierMsgText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: messages.isNotEmpty && messages.first['expediteur'] != _currentUserEmail
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                conversationId: conv['id'],
                                nomCorrespondant: correspondant ?? "Discussion",
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}