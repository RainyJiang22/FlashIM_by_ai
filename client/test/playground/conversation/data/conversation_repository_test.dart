import 'package:flutter_test/flutter_test.dart';

import 'package:flash_im/playground/demos/conversation/data/conversation_api.dart';
import 'package:flash_im/playground/demos/conversation/data/conversation_repository.dart';
import 'package:flash_im/playground/demos/conversation/data/models/conversation_dto.dart';

void main() {
  test('repository maps dto list and appends seeded picsum avatars', () async {
    final repository = RemoteConversationRepository(
      request: _FakeConversationRequest(const [
        ConversationDto(
          title: '产品讨论群',
          lastMessage: '今晚先把登录流程对齐一下。',
          time: '09:12',
        ),
        ConversationDto(
          title: 'Rust 后端小组',
          lastMessage: 'Axum 的路由已经跑通了。',
          time: '09:25',
        ),
      ]),
    );

    final conversations = await repository.fetchConversations();

    expect(conversations, hasLength(2));
    expect(
      conversations.first.avatarUrl,
      'https://picsum.photos/seed/%E4%BA%A7%E5%93%81%E8%AE%A8%E8%AE%BA%E7%BE%A4-0/120/120',
    );
    expect(
      conversations.last.avatarUrl,
      'https://picsum.photos/seed/Rust%20%E5%90%8E%E7%AB%AF%E5%B0%8F%E7%BB%84-1/120/120',
    );
  });
}

class _FakeConversationRequest implements ConversationRequest {
  const _FakeConversationRequest(this._items);

  final List<ConversationDto> _items;

  @override
  Future<List<ConversationDto>> fetchConversations() async => _items;
}
