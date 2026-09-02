import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';
import 'package:flash_im_group/flash_im_group.dart';

class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({this.friends = const [], this.error});

  final List<FriendUser> friends;
  final Object? error;

  @override
  Future<List<FriendUser>> getFriends() async {
    if (error != null) throw error!;
    return friends;
  }

  @override
  Future<FriendAcceptResult> acceptRequest(String requestId) =>
      throw UnimplementedError();

  @override
  Future<FriendUser> getUser(int accountId) => throw UnimplementedError();

  @override
  Future<List<FriendRequest>> getReceivedRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<List<FriendRequest>> getSentRequests({
    String status = 'pending',
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<void> rejectRequest(String requestId) => throw UnimplementedError();

  @override
  Future<void> removeFriend(int accountId) => throw UnimplementedError();

  @override
  Future<List<FriendUser>> searchUsers(String query, {int limit = 30}) =>
      throw UnimplementedError();

  @override
  Future<void> sendRequest({required int toUserId, required String message}) =>
      throw UnimplementedError();
}

class FakeConversationRepository implements ConversationRepository {
  FakeConversationRepository({
    this.pages = const {},
    this.created,
    this.createError,
    this.listError,
  });

  final Map<int, List<Conversation>> pages;
  final Conversation? created;
  final Object? createError;
  final Object? listError;
  final List<int?> requestedTypes = [];
  final List<int> requestedOffsets = [];
  String? createdName;
  List<int>? createdMemberIds;

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    createdName = name;
    createdMemberIds = memberIds;
    if (createError != null) throw createError!;
    return created!;
  }

  @override
  Future<Conversation> getById(String id) => throw UnimplementedError();

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async {
    requestedTypes.add(type);
    requestedOffsets.add(offset);
    if (listError != null) throw listError!;
    return pages[offset] ?? const [];
  }

  @override
  Future<void> markRead(String id) async {}
}

const friends = <FriendUser>[
  FriendUser(
    accountId: 2,
    nickname: '阿青',
    avatar: 'identicon:2',
    signature: '',
    flashId: 'aqing',
    relationStatus: 'friend',
  ),
  FriendUser(
    accountId: 3,
    nickname: '白露',
    avatar: 'identicon:3',
    signature: '',
    flashId: 'bailu',
    relationStatus: 'friend',
  ),
  FriendUser(
    accountId: 4,
    nickname: '橙子',
    avatar: 'identicon:4',
    signature: '',
    flashId: 'orange',
    relationStatus: 'friend',
  ),
  FriendUser(
    accountId: 5,
    nickname: '丁香',
    avatar: 'identicon:5',
    signature: '',
    flashId: 'dingxiang',
    relationStatus: 'friend',
  ),
];

Conversation groupConversation(String id, String name) => Conversation(
  id: id,
  type: 1,
  name: name,
  avatar: 'grid:identicon:1,identicon:2',
  memberAvatars: const ['identicon:1', 'identicon:2'],
  unreadCount: 0,
  createdAt: DateTime(2026, 8, 16),
);

GroupDetail groupDetail({
  bool isOwner = true,
  bool joinApprovalRequired = false,
  String name = '测试群聊',
  String announcement = '',
  String? currentUserNickname,
}) => GroupDetail(
  conversationId: 'group-1',
  name: name,
  avatar: 'grid:identicon:1,identicon:2',
  ownerId: 1,
  joinApprovalRequired: joinApprovalRequired,
  announcement: announcement,
  currentUserRole: isOwner ? 'owner' : 'member',
  currentUserNickname: currentUserNickname ?? (isOwner ? '群主' : '阿青'),
  memberCount: 2,
  members: [
    GroupMember(
      accountId: 1,
      nickname: '群主',
      avatar: 'identicon:1',
      isOwner: true,
      joinedAt: DateTime(2026, 8, 17),
    ),
    GroupMember(
      accountId: 2,
      nickname: '阿青',
      avatar: 'identicon:2',
      isOwner: false,
      joinedAt: DateTime(2026, 8, 17),
    ),
  ],
);

class FakeGroupRepository implements GroupRepository {
  FakeGroupRepository({
    GroupDetail? detail,
    this.error,
    this.searchResults = const [],
    this.joinResult = const JoinGroupResult(autoApproved: false),
    GroupJoinRequestList? joinRequests,
  }) : detail = detail ?? groupDetail(),
       joinRequests =
           joinRequests ?? GroupJoinRequestList(pendingCount: 0, requests: []);

  GroupDetail detail;
  final Object? error;
  final List<GroupSearchItem> searchResults;
  final JoinGroupResult joinResult;
  final GroupJoinRequestList joinRequests;
  final List<List<int>> addedMemberIds = [];
  final List<List<int>> invitedMemberIds = [];
  final List<int> removedMemberIds = [];
  final List<String> searchKeywords = [];
  final List<({String groupId, String? message})> joinCalls = [];
  final List<({String groupId, String requestId, bool approved})>
  handleJoinRequestCalls = [];
  var dissolveCount = 0;
  var leaveCount = 0;
  final List<int> transferredOwnerIds = [];
  final List<List<int>> updatedAdminIds = [];
  final List<String> updatedNicknames = [];

  void _throwIfNeeded() {
    if (error != null) throw error!;
  }

  @override
  Future<Conversation> acceptInvitation(String invitationId) async =>
      groupConversation('group-1', detail.name);

  @override
  Future<GroupDetail> addMembers(String groupId, List<int> memberIds) async {
    _throwIfNeeded();
    addedMemberIds.add(memberIds);
    return detail;
  }

  @override
  Future<void> dissolveGroup(String groupId) async {
    _throwIfNeeded();
    dissolveCount += 1;
  }

  @override
  Future<GroupDetail> getDetail(String groupId) async {
    _throwIfNeeded();
    return detail;
  }

  @override
  Future<GroupJoinRequestList> getJoinRequests() async {
    _throwIfNeeded();
    return joinRequests;
  }

  @override
  Future<GroupJoinRequest> handleJoinRequest(
    String groupId,
    String requestId, {
    required bool approved,
  }) async {
    _throwIfNeeded();
    handleJoinRequestCalls.add((
      groupId: groupId,
      requestId: requestId,
      approved: approved,
    ));
    final request = joinRequests.requests.firstWhere(
      (item) => item.id == requestId,
    );
    return GroupJoinRequest(
      id: request.id,
      conversationId: request.conversationId,
      groupName: request.groupName,
      groupAvatar: request.groupAvatar,
      applicantId: request.applicantId,
      applicantName: request.applicantName,
      applicantAvatar: request.applicantAvatar,
      message: request.message,
      status: approved
          ? GroupJoinRequestStatus.approved
          : GroupJoinRequestStatus.rejected,
      createdAt: request.createdAt,
      handledAt: DateTime(2026, 8, 31),
    );
  }

  @override
  Future<void> inviteMembers(String groupId, List<int> inviteeIds) async {
    _throwIfNeeded();
    invitedMemberIds.add(inviteeIds);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    _throwIfNeeded();
    leaveCount += 1;
  }

  @override
  Future<JoinGroupResult> joinGroup(String groupId, {String? message}) async {
    _throwIfNeeded();
    joinCalls.add((groupId: groupId, message: message));
    return joinResult;
  }

  @override
  Future<GroupDetail> removeMember(String groupId, int memberId) async {
    _throwIfNeeded();
    removedMemberIds.add(memberId);
    return detail;
  }

  @override
  Future<List<GroupSearchItem>> searchGroups(String keyword) async {
    _throwIfNeeded();
    searchKeywords.add(keyword);
    return searchResults;
  }

  @override
  Future<GroupDetail> transferOwner(String groupId, int ownerId) async {
    _throwIfNeeded();
    transferredOwnerIds.add(ownerId);
    detail = detail.copyWith(
      ownerId: ownerId,
      currentUserRole: ownerId == detail.ownerId ? 'owner' : 'member',
    );
    return detail;
  }

  @override
  Future<GroupDetail> updateAnnouncement(
    String groupId,
    String announcement,
  ) async {
    _throwIfNeeded();
    detail = detail.copyWith(announcement: announcement);
    return detail;
  }

  @override
  Future<GroupDetail> updateAdmins(String groupId, List<int> memberIds) async {
    _throwIfNeeded();
    updatedAdminIds.add(memberIds);
    detail = detail.copyWith(
      members: detail.members
          .map(
            (member) => GroupMember(
              accountId: member.accountId,
              nickname: member.nickname,
              avatar: member.avatar,
              isOwner: member.isOwner,
              isAdmin: memberIds.contains(member.accountId),
              joinedAt: member.joinedAt,
            ),
          )
          .toList(growable: false),
    );
    return detail;
  }

  @override
  Future<GroupDetail> updateName(String groupId, String name) async {
    _throwIfNeeded();
    detail = groupDetail(
      isOwner: detail.isOwner,
      joinApprovalRequired: detail.joinApprovalRequired,
      name: name,
      announcement: detail.announcement,
      currentUserNickname: detail.currentUserNickname,
    );
    return detail;
  }

  @override
  Future<GroupDetail> updateNickname(String groupId, String nickname) async {
    _throwIfNeeded();
    updatedNicknames.add(nickname);
    detail = detail.copyWith(currentUserNickname: nickname);
    return detail;
  }

  @override
  Future<GroupDetail> updateSettings(
    String groupId, {
    required bool joinApprovalRequired,
  }) async {
    _throwIfNeeded();
    detail = groupDetail(
      isOwner: detail.isOwner,
      joinApprovalRequired: joinApprovalRequired,
      name: detail.name,
      announcement: detail.announcement,
      currentUserNickname: detail.currentUserNickname,
    );
    return detail;
  }
}
