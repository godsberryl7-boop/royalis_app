import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final int conversationId;
  final String nomCorrespondant;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.nomCorrespondant,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ===========================
  // CONTRÔLEURS & STREAMING
  // ===========================
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  StreamSubscription? _messagesSubscription;

  // ===========================
  // ÉTAT LOCAL
  // ===========================
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessages();
  }

  @override
  void dispose() {
    // 🔒 NETTOYAGE STRICTE DE LA MÉMOIRE
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  /// Charge les messages en temps réel
  void _loadMessages() {
    try {
      _messagesSubscription = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true)
          .listen(
            (List<Map<String, dynamic>> data) {
              if (mounted) {
                setState(() {
                  _messages = data;
                  _isLoading = false;
                  _error = null;
                });

                // Défilement automatique vers le bas après le rendu
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              }
            },
            onError: (error) {
              debugPrint('Erreur stream messages: $error');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _error = error.toString();
                });
              }
            },
          );
    } catch (e) {
      debugPrint('Erreur initialisation stream: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Défile automatiquement vers le bas
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Envoie un message
  Future<void> _sendMessage() async {
    final user = Supabase.instance.client.auth.currentUser;
    final texte = _messageController.text.trim();

    // ✅ VALIDATIONS STRICTES
    if (user == null) {
      _showError('Vous devez être connecté pour envoyer un message');
      return;
    }

    if (texte.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      // 📤 Insertion du message dans Supabase
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'expediteur': user.email,
        'message': texte,
      });

      if (mounted) {
        _messageController.clear();
        FocusScope.of(context).unfocus();
      }

      // Défilement vers le bas après envoi
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      if (mounted) {
        _showError('Erreur d\'envoi: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// Affiche un message d'erreur
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(),
      body: _buildBody(user?.email),
    );
  }

  /// Construit l'app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nomCorrespondant,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "En ligne",
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Construit le corps du chat
  Widget _buildBody(String? userEmail) {
    // ⏳ CHARGEMENT
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      );
    }

    // ❌ ERREUR
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadMessages();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: const Color(0xFFD4AF37),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 📋 LISTE DES MESSAGES
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun message pour le moment',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Démarrez la conversation !',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final estMoi = msg['expediteur'] == userEmail;

                    // Formatage de l'heure
                    String heureFormatee = "";
                    if (msg['created_at'] != null) {
                      final date =
                          DateTime.parse(msg['created_at'].toString())
                              .toLocal();
                      heureFormatee =
                          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    return Align(
                      alignment: estMoi
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: estMoi
                              ? const Color(0xFFD4AF37)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: estMoi
                                ? const Radius.circular(16)
                                : Radius.zero,
                            bottomRight: estMoi
                                ? Radius.zero
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['message'] ?? "",
                              style: TextStyle(
                                color: estMoi
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                                fontSize: 15,
                              ),
                            ),
                            if (heureFormatee.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    heureFormatee,
                                    style: TextStyle(
                                      color: estMoi
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // 📤 ZONE DE SAISIE
        Container(
          padding: const EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 24,
            top: 10,
          ),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _isSending ? null : _sendMessage(),
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    hintText: "Écrire un message...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD4AF37),
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
