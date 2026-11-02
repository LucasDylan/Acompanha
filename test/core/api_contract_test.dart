import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_apollo/core/models/booking_model.dart';
import 'package:projeto_apollo/core/models/host_profile_model.dart';
import 'package:projeto_apollo/core/models/slot_model.dart';
import 'package:projeto_apollo/core/models/user_model.dart';
import 'package:projeto_apollo/features/booking/data/booking_repository.dart';
import 'package:projeto_apollo/features/chat/models/conversation_model.dart';
import 'package:projeto_apollo/features/matches/models/gym_member_model.dart';
import 'package:projeto_apollo/features/matches/models/match_request_model.dart';
import 'package:projeto_apollo/features/safety/data/safety_repository.dart';

/// Parses responses recorded from the real Django API
/// (backend/tools/export_api_fixtures.py) with the app's models, so a
/// serializer change that the app can't read fails here instead of on a phone.
dynamic fixture(String name) => jsonDecode(
      File('test/fixtures/api/$name.json').readAsStringSync(),
    );

List<Map<String, dynamic>> results(dynamic page) =>
    (page['results'] as List).cast<Map<String, dynamic>>();

void main() {
  test('me', () {
    final user = UserModel.fromJson(fixture('me'));
    expect(user.email, 'ana@contract.test');
    expect(user.gymName, 'Academia Contrato');
    expect(user.workoutTypes, ['Musculação']);
    expect(user.availableDays, ['Seg', 'Qua']);
    expect(user.isHost, isFalse);
  });

  test('host listings, detail, reviews and slots', () {
    final page = fixture('hosts_page');
    expect(page['next'], isA<String?>());
    for (final json in results(page)) {
      HostProfileModel.fromJson(json);
    }
    final host = HostProfileModel.fromJson(fixture('host_detail'));
    expect(host.categories, ['mentorship', 'coffee']);
    expect(host.pricePerHour, 80);

    final reviews = results(fixture('host_reviews')).map(HostReview.fromJson).toList();
    expect(reviews.single.rating, 5);
    expect(reviews.single.author, 'Ana');

    final slots = (fixture('host_slots') as List)
        .cast<Map<String, dynamic>>()
        .map(SlotModel.fromJson)
        .toList();
    expect(slots, hasLength(1));
    expect(slots.single.isAvailable, isTrue);
    expect(slots.single.durationMinutes, 90);
  });

  test('bookings, as client and as host', () {
    final created = BookingModel.fromJson(fixture('booking_created'));
    expect(created.status, BookingStatus.confirmed); // dev mode: no payment
    expect(created.amount, 120); // R$ 80/h × 1h30
    expect(created.canCancel, isTrue);
    expect(created.hostUserId, isNotNull);

    final mine = results(fixture('my_bookings')).map(BookingModel.fromJson).toList();
    final completed = mine.firstWhere((b) => b.status == BookingStatus.completed);
    expect(completed.review?.rating, 5);
    expect(completed.canReview, isFalse);

    final received =
        results(fixture('received_bookings')).map(BookingModel.fromJson).toList();
    expect(received.every((b) => b.client?.name == 'Ana'), isTrue);
  });

  test('payment config', () {
    final config = PaymentConfig.fromJson(fixture('payment_config'));
    expect(config.unpaidBookingsAllowed, isTrue);
  });

  test('gym members, matches and training sessions', () {
    final members = results(fixture('gym_members')).map(GymMemberModel.fromJson).toList();
    final ana = members.firstWhere((m) => m.name == 'Ana');
    expect(ana.matchStatus, MatchStatus.matched);
    expect(ana.fitnessLevel, 'intermediate');

    final matches = results(fixture('my_matches')).map(MatchRequestModel.fromJson).toList();
    expect(matches.single.status, MatchRequestStatus.accepted);

    final sessions =
        results(fixture('sessions')).map(TrainingSessionModel.fromJson).toList();
    expect(sessions.single.workoutType, 'Cardio');
    expect(sessions.single.status, SessionStatus.pending);
  });

  test('chat', () {
    final opened = ConversationModel.fromJson(fixture('conversation_opened'));
    expect(opened.otherUser.name, 'Bia');

    final sent = ChatMessage.fromJson(fixture('message_sent'));
    expect(sent.text, 'Oi, Bia!');

    final inbox = (fixture('conversations') as List)
        .cast<Map<String, dynamic>>()
        .map(ConversationModel.fromJson)
        .toList();
    expect(inbox.single.unreadCount, 1);
    expect(inbox.single.lastMessage?.text, 'Oi, Bia!');

    final messages = (fixture('messages') as List)
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    expect(messages.single.senderId, sent.senderId); // Bia reads Ana's message

    expect(fixture('unread_count')['unread'], isA<int>());
  });

  test('blocks and reports', () {
    final blocked = (fixture('blocks') as List)
        .cast<Map<String, dynamic>>()
        .map(BlockedUser.fromJson)
        .toList();
    expect(blocked.single.name, 'Cid');
    expect(int.tryParse(blocked.single.userId), isNotNull);
    expect(fixture('report_created')['blocked'], isTrue);
  });
}
