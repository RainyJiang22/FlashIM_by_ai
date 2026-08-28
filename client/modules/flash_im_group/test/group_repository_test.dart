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
    final payload = options.path.contains('/invitations')
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
