import '../domain/conversation_entity.dart';
import 'conversation_api.dart';
import 'models/conversation_dto.dart';

abstract interface class ConversationRepository {
  Future<List<ConversationEntity>> fetchConversations();
}

class RemoteConversationRepository implements ConversationRepository {
  RemoteConversationRepository({required ConversationRequest request})
    : _request = request;

  final ConversationRequest _request;

  @override
  Future<List<ConversationEntity>> fetchConversations() async {
    final dtos = await _request.fetchConversations();

    return List<ConversationEntity>.generate(dtos.length, (index) {
      final dto = dtos[index];
      return _mapToEntity(dto, index);
    }, growable: false);
  }

  ConversationEntity _mapToEntity(ConversationDto dto, int index) {
    final avatarSeed = Uri.encodeComponent('${dto.title}-$index');

    return ConversationEntity(
      title: dto.title,
      lastMessage: dto.lastMessage,
      time: dto.time,
      avatarUrl: 'https://picsum.photos/seed/$avatarSeed/120/120',
    );
  }
}
