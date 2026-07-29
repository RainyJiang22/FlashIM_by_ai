import 'package:dio/dio.dart';

import 'friend_request.dart';
import 'friend_user.dart';

abstract interface class FriendRepository {
  Future<List<FriendUser>> getFriends();

  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  });

  Future<List<FriendUser>> searchUsers(String query, {int limit = 30});

  Future<FriendUser> getUser(int accountId);

  Future<void> sendRequest({required int toUserId, required String message});

  Future<FriendAcceptResult> acceptRequest(String requestId);

  Future<void> rejectRequest(String requestId);

  Future<void> removeFriend(int accountId);
}

class DioFriendRepository implements FriendRepository {
  DioFriendRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<FriendUser>> getFriends() async {
    final response = await _dio.get<dynamic>('/api/friends');
    return _parseList(response.data, FriendUser.fromJson, 'Friend list');
  }

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/friends/requests/received',
      queryParameters: <String, dynamic>{
        'status': status,
        'limit': limit,
        'offset': offset,
      },
    );
    return _parseList(
      response.data,
      FriendRequest.fromJson,
      'Friend request list',
    );
  }

  @override
  Future<List<FriendUser>> searchUsers(String query, {int limit = 30}) async {
    final response = await _dio.get<dynamic>(
      '/api/users/search',
      queryParameters: <String, dynamic>{'q': query, 'limit': limit},
    );
    return _parseList(response.data, FriendUser.fromJson, 'User search');
  }

  @override
  Future<FriendUser> getUser(int accountId) async {
    final response = await _dio.get<dynamic>('/api/users/$accountId');
    return FriendUser.fromJson(_requiredMap(response.data, 'User profile'));
  }

  @override
  Future<void> sendRequest({
    required int toUserId,
    required String message,
  }) async {
    await _dio.post<dynamic>(
      '/api/friends/requests',
      data: <String, dynamic>{'to_user_id': toUserId, 'message': message},
    );
  }

  @override
  Future<FriendAcceptResult> acceptRequest(String requestId) async {
    final response = await _dio.post<dynamic>(
      '/api/friends/requests/$requestId/accept',
    );
    return FriendAcceptResult.fromJson(
      _requiredMap(response.data, 'Accept friend request'),
    );
  }

  @override
  Future<void> rejectRequest(String requestId) async {
    await _dio.post<dynamic>('/api/friends/requests/$requestId/reject');
  }

  @override
  Future<void> removeFriend(int accountId) async {
    await _dio.delete<dynamic>('/api/friends/$accountId');
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

Map<String, dynamic> _requiredMap(dynamic payload, String label) {
  if (payload is! Map) {
    throw FormatException('$label payload is not a JSON object.');
  }
  return Map<String, dynamic>.from(payload);
}
