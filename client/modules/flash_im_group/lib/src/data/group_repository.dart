import 'package:dio/dio.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';

import 'group_detail.dart';

abstract interface class GroupRepository {
  Future<GroupDetail> getDetail(String groupId);

  Future<GroupDetail> updateName(String groupId, String name);

  Future<GroupDetail> updateSettings(
    String groupId, {
    required bool joinApprovalRequired,
  });

  Future<GroupDetail> addMembers(String groupId, List<int> memberIds);

  Future<GroupDetail> removeMember(String groupId, int memberId);

  Future<void> inviteMembers(String groupId, List<int> inviteeIds);

  Future<Conversation> acceptInvitation(String invitationId);

  Future<void> dissolveGroup(String groupId);
}

class GroupRequestException implements Exception {
  const GroupRequestException([this.serverMessage]);

  final String? serverMessage;
}

class DioGroupRepository implements GroupRepository {
  DioGroupRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<GroupDetail> getDetail(String groupId) async {
    final response = await _request(
      () => _dio.get<dynamic>('/groups/$groupId'),
    );
    return _parseDetail(response.data);
  }

  @override
  Future<GroupDetail> updateName(String groupId, String name) async {
    final response = await _request(
      () => _dio.patch<dynamic>('/groups/$groupId/name', data: {'name': name}),
    );
    return _parseDetail(response.data);
  }

  @override
  Future<GroupDetail> updateSettings(
    String groupId, {
    required bool joinApprovalRequired,
  }) async {
    final response = await _request(
      () => _dio.patch<dynamic>(
        '/groups/$groupId/settings',
        data: {'join_approval_required': joinApprovalRequired},
      ),
    );
    return _parseDetail(response.data);
  }

  @override
  Future<GroupDetail> addMembers(String groupId, List<int> memberIds) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/groups/$groupId/members',
        data: {'member_ids': memberIds},
      ),
    );
    return _parseDetail(response.data);
  }

  @override
  Future<GroupDetail> removeMember(String groupId, int memberId) async {
    final response = await _request(
      () => _dio.delete<dynamic>('/groups/$groupId/members/$memberId'),
    );
    return _parseDetail(response.data);
  }

  @override
  Future<void> inviteMembers(String groupId, List<int> inviteeIds) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/groups/$groupId/invitations',
        data: {'member_ids': inviteeIds},
      ),
    );
    final invitations = _requiredMap(response.data)['invitations'];
    if (invitations is! List ||
        invitations.any((item) => item is! Map || item['delivered'] != true)) {
      throw const GroupRequestException('group invitation delivery failed');
    }
  }

  @override
  Future<Conversation> acceptInvitation(String invitationId) async {
    final response = await _request(
      () => _dio.post<dynamic>('/group-invitations/$invitationId/accept'),
    );
    return Conversation.fromJson(_requiredMap(response.data));
  }

  @override
  Future<void> dissolveGroup(String groupId) async {
    await _request(() => _dio.delete<dynamic>('/groups/$groupId'));
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? (data['message'] as String).trim()
          : null;
      throw GroupRequestException(message?.isNotEmpty == true ? message : null);
    }
  }
}

GroupDetail _parseDetail(dynamic value) =>
    GroupDetail.fromJson(_requiredMap(value));

Map<String, dynamic> _requiredMap(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Group response is not a JSON object.');
  }
  return Map<String, dynamic>.from(value);
}
