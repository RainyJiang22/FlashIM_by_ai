import 'package:dio/dio.dart';
import 'package:flash_im_chat/flash_im_chat.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';

import 'search_models.dart';

abstract interface class SearchRepository {
  Future<List<FriendUser>> searchFriends(String query);

  Future<List<Conversation>> searchJoinedGroups(String query);

  Future<List<MessageSearchGroup>> searchMessages(String query);

  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  });
}

class DioSearchRepository implements SearchRepository {
  DioSearchRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<FriendUser>> searchFriends(String query) async {
    final response = await _dio.get<dynamic>(
      '/api/friends/search',
      queryParameters: {'q': query},
    );
    return _parseList(response.data, FriendUser.fromJson, 'Friend search');
  }

  @override
  Future<List<Conversation>> searchJoinedGroups(String query) async {
    final response = await _dio.get<dynamic>(
      '/api/conversations/search-joined-groups',
      queryParameters: {'q': query},
    );
    return _parseList(
      response.data,
      Conversation.fromJson,
      'Joined group search',
    );
  }

  @override
  Future<List<MessageSearchGroup>> searchMessages(String query) async {
    final response = await _dio.get<dynamic>(
      '/api/messages/search',
      queryParameters: {'q': query},
    );
    return _parseList(
      response.data,
      MessageSearchGroup.fromJson,
      'Message search',
    );
  }

  @override
  Future<List<Message>> searchConversationMessages({
    required String conversationId,
    required String query,
  }) async {
    final response = await _dio.get<dynamic>(
      '/conversations/$conversationId/messages/search',
      queryParameters: {'q': query, 'limit': 100},
    );
    return _parseList(response.data, Message.fromJson, 'Conversation search');
  }
}

List<T> _parseList<T>(
  dynamic payload,
  T Function(Map<String, dynamic>) parser,
  String label,
) {
  if (payload is! List) {
    throw FormatException('$label payload is not a list.');
  }
  return payload
      .map((dynamic item) {
        if (item is! Map) {
          throw FormatException('$label item is not a JSON object.');
        }
        return parser(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}
