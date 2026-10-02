import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/json.dart';
import '../models/staff_message.dart';

class StaffMessagePage {
  const StaffMessagePage(this.messages, {required this.hasMore});
  final List<StaffMessage> messages;
  final bool hasMore;
}

class MessagingRepository {
  MessagingRepository(this._api);

  final ApiClient _api;

  Future<List<StaffConversation>> listConversations() async {
    final data = asMap(await _api.get(ApiEndpoints.messagingConversations));
    return asList(data['results'], StaffConversation.fromJson);
  }

  Future<StaffConversation> ensureOperatorConversation() async {
    final data = asMap(await _api.post(ApiEndpoints.messagingConversationsEnsure, data: {}));
    return StaffConversation.fromJson(data);
  }

  Future<StaffMessagePage> listMessages(
    String conversationId, {
    int page = 1,
    int pageSize = 100,
    String? targetType,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = asMap(await _api.get(
      ApiEndpoints.messagingConversationMessages(conversationId),
      query: {
        'page': page,
        'page_size': pageSize,
        if (targetType != null && targetType.isNotEmpty && targetType != 'ALL') 'target_type': targetType,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      },
    ));
    return StaffMessagePage(
      asList(data['results'], StaffMessage.fromJson),
      hasMore: data['next'] != null,
    );
  }

  Future<List<StaffMessage>> listAllMessages(
    String conversationId, {
    String? targetType,
    String? dateFrom,
    String? dateTo,
  }) async {
    final all = <StaffMessage>[];
    var page = 1;
    while (true) {
      final chunk = await listMessages(
        conversationId,
        page: page,
        targetType: targetType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      all.addAll(chunk.messages);
      if (!chunk.hasMore) break;
      page += 1;
    }
    all.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return all;
  }

  Future<StaffMessage> sendMessage(String conversationId, String body) async {
    final data = asMap(await _api.post(
      ApiEndpoints.messagingConversationMessages(conversationId),
      data: {'body': body},
    ));
    return StaffMessage.fromJson(data);
  }

  Future<int> unreadCount() async =>
      asInt(asMap(await _api.get(ApiEndpoints.messagingUnreadCount))['unread_count']) ?? 0;

  Future<int> clearInbox(String conversationId) async {
    final data = asMap(await _api.post(ApiEndpoints.messagingConversationClearInbox(conversationId)));
    return asInt(data['cleared']) ?? 0;
  }
}
