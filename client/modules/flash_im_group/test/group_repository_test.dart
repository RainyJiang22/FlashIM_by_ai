import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses detail and sends management request contracts', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = DioGroupRepository(dio: dio);

    final detail = await repository.getDetail('group-1');
    await repository.updateName('group-1', '新群名');
    await repository.updateSettings('group-1', joinApprovalRequired: true);
    await repository.addMembers('group-1', const [3]);
    await repository.removeMember('group-1', 2);
    await repository.inviteMembers('group-1', const [4]);
    await repository.dissolveGroup('group-1');

    expect(detail.isOwner, isTrue);
    expect(detail.avatar, 'grid:identicon:1');
    expect(detail.members.single.accountId, 1);
    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'PATCH',
      'PATCH',
      'POST',
      'DELETE',
      'POST',
      'DELETE',
    ]);
    expect(adapter.requests[3].data, {
      'member_ids': [3],
    });
    expect(adapter.requests[5].data, {
      'member_ids': [4],
    });
  });

  test('rejects an invitation response with an undelivered item', () async {
    final dio = Dio()
      ..httpClientAdapter = _RecordingAdapter(invitationDelivered: false);
    final repository = DioGroupRepository(dio: dio);

    await expectLater(
      repository.inviteMembers('group-1', const [4]),
      throwsA(
        isA<GroupRequestException>().having(
          (error) => error.serverMessage,
          'serverMessage',
          'group invitation delivery failed',
        ),
      ),
    );
  });

  test('parses search, join and approval request contracts', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = DioGroupRepository(dio: dio);

    final groups = await repository.searchGroups('项目');
    final joined = await repository.joinGroup('group-1');
    final requests = await repository.getJoinRequests();
    final handled = await repository.handleJoinRequest(
      'group-1',
      'request-1',
      approved: true,
    );

    expect(groups.single.name, '项目群');
    expect(groups.single.joinApprovalRequired, isTrue);
    expect(joined.autoApproved, isTrue);
    expect(joined.conversation?.id, 'group-1');
    expect(requests.pendingCount, 1);
    expect(requests.requests.single.applicantId, 2);
    expect(handled.status, GroupJoinRequestStatus.approved);
    expect(adapter.requests.first.queryParameters, {'keyword': '项目'});
    expect(adapter.requests.last.data, {'approved': true});
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.invitationDelivered = true});

  final bool invitationDelivered;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final dynamic payload = options.path == '/groups/search'
        ? {
            'groups': [
              {
                'conversation_id': 'group-1',
                'group_number': 'group-1',
                'name': '项目群',
                'avatar': 'grid:identicon:1',
                'member_count': 2,
                'join_approval_required': true,
                'is_member': false,
                'has_pending_request': false,
              },
            ],
          }
        : options.path == '/groups/group-1/join'
        ? {
            'auto_approved': true,
            'request_id': null,
            'conversation': {
              'id': 'group-1',
              'type': 1,
              'name': '项目群',
              'avatar': 'grid:identicon:1',
              'owner_id': '1',
              'unread_count': 0,
              'created_at': '2026-08-31T00:00:00Z',
            },
          }
        : options.path == '/groups/join-requests'
        ? {
            'pending_count': 1,
            'requests': [_joinRequestPayload('pending')],
          }
        : options.path.contains('/join-requests/')
        ? _joinRequestPayload('approved')
        : options.path.contains('/invitations')
        ? {
            'invitations': [
              {
                'id': invitationDelivered ? 'invitation-1' : null,
                'status': invitationDelivered ? 'pending' : 'failed',
                'delivered': invitationDelivered,
              },
            ],
          }
        : options.method == 'DELETE' && options.path == '/groups/group-1'
        ? {'message': 'ok'}
        : {
            'conversation_id': 'group-1',
            'name': options.data is Map && options.data['name'] != null
                ? options.data['name']
                : '测试群聊',
            'avatar': 'grid:identicon:1',
            'owner_id': '1',
            'join_approval_required':
                options.data is Map &&
                    options.data['join_approval_required'] != null
                ? options.data['join_approval_required']
                : false,
            'current_user_role': 'owner',
            'member_count': 1,
            'members': [
              {
                'account_id': '1',
                'nickname': '群主',
                'avatar': 'identicon:1',
                'is_owner': true,
                'joined_at': '2026-08-17T00:00:00Z',
              },
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _joinRequestPayload(String status) => {
  'id': 'request-1',
  'conversation_id': 'group-1',
  'group_name': '项目群',
  'group_avatar': 'grid:identicon:1',
  'applicant_id': '2',
  'applicant_name': '阿青',
  'applicant_avatar': 'identicon:2',
  'message': '请通过',
  'status': status,
  'created_at': '2026-08-31T00:00:00Z',
  'handled_at': status == 'pending' ? null : '2026-08-31T00:01:00Z',
};
