import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _questionController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add({
      'isUser': false,
      'text': 'مرحباً! أنا مساعد ZAD الذكي. يمكنك سؤالي عن:\n• مبيعات اليوم\n• الأرباح\n• المنتجات الأكثر مبيعاً\n• المنتجات التي تحتاج إعادة طلب\n• توقعات المخزون',
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': question});
      _questionController.clear();
    });
    _scrollToBottom();

    final aiProvider = context.read<AiProvider>();
    final response = await aiProvider.askQuestion(question);

    setState(() {
      _messages.add({'isUser': false, 'text': response});
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('المساعد الذكي'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Questions
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickQuestionChip(
                    label: 'مبيعات اليوم؟',
                    onTap: () => _askQuickQuestion('كم مبيعات اليوم؟'),
                  ),
                  _QuickQuestionChip(
                    label: 'أكثر منتج مبيعاً؟',
                    onTap: () => _askQuickQuestion('ما أكثر منتج مبيعاً؟'),
                  ),
                  _QuickQuestionChip(
                    label: 'الأرباح؟',
                    onTap: () => _askQuickQuestion('كم الأرباح؟'),
                  ),
                  _QuickQuestionChip(
                    label: 'إعادة الطلب؟',
                    onTap: () => _askQuickQuestion('ما المنتجات التي يجب إعادة طلبها؟'),
                  ),
                  _QuickQuestionChip(
                    label: 'نفاد المخزون؟',
                    onTap: () => _askQuickQuestion('ما المنتجات التي سينفد مخزونها؟'),
                  ),
                ],
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(
                  text: msg['text'],
                  isUser: msg['isUser'],
                );
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'اكتب سؤالك هنا...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendQuestion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<AiProvider>(
                    builder: (context, ai, child) {
                      return FloatingActionButton.small(
                        onPressed: ai.isLoading ? null : _sendQuestion,
                        backgroundColor: const Color(0xFF1E88E5),
                        child: ai.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _askQuickQuestion(String question) {
    _questionController.text = question;
    _sendQuestion();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _MessageBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E88E5) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 4 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _QuickQuestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickQuestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
        side: const BorderSide(color: Color(0xFFFF9800)),
      ),
    );
  }
}
