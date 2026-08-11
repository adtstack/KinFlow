import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class FakeHouseholdInviteShareGateway
    implements HouseholdInviteShareGateway {
  FakeHouseholdInviteShareGateway({
    this.callback,
    List<HouseholdInviteShareResult> results =
        const <HouseholdInviteShareResult>[HouseholdInviteShareResult.opened],
  }) : _results = List<HouseholdInviteShareResult>.of(results);

  final Future<HouseholdInviteShareResult> Function(
    HouseholdInviteLink link,
    String chooserTitle,
  )?
  callback;
  final List<HouseholdInviteShareResult> _results;
  final List<HouseholdInviteLink> links = <HouseholdInviteLink>[];
  final List<String> chooserTitles = <String>[];

  @override
  Future<HouseholdInviteShareResult> share(
    HouseholdInviteLink link, {
    required String chooserTitle,
  }) async {
    links.add(link);
    chooserTitles.add(chooserTitle);
    final callback = this.callback;
    if (callback != null) return callback(link, chooserTitle);
    if (_results.isEmpty) return HouseholdInviteShareResult.opened;
    return _results.removeAt(0);
  }
}

final class FakeHouseholdInviteClipboard implements HouseholdInviteClipboard {
  FakeHouseholdInviteClipboard({
    this.linkCallback,
    this.shortCodeCallback,
    List<HouseholdInviteCopyResult> linkResults =
        const <HouseholdInviteCopyResult>[HouseholdInviteCopyResult.copied],
    List<HouseholdInviteCopyResult> shortCodeResults =
        const <HouseholdInviteCopyResult>[HouseholdInviteCopyResult.copied],
  }) : _linkResults = List<HouseholdInviteCopyResult>.of(linkResults),
       _shortCodeResults = List<HouseholdInviteCopyResult>.of(shortCodeResults);

  final Future<HouseholdInviteCopyResult> Function(HouseholdInviteLink link)?
  linkCallback;
  final Future<HouseholdInviteCopyResult> Function(InviteShortCode shortCode)?
  shortCodeCallback;
  final List<HouseholdInviteCopyResult> _linkResults;
  final List<HouseholdInviteCopyResult> _shortCodeResults;
  final List<HouseholdInviteLink> linkWrites = <HouseholdInviteLink>[];
  final List<InviteShortCode> shortCodeWrites = <InviteShortCode>[];

  @override
  Future<HouseholdInviteCopyResult> copyLink(HouseholdInviteLink link) async {
    linkWrites.add(link);
    final callback = linkCallback;
    if (callback != null) return callback(link);
    if (_linkResults.isEmpty) return HouseholdInviteCopyResult.copied;
    return _linkResults.removeAt(0);
  }

  @override
  Future<HouseholdInviteCopyResult> copyShortCode(
    InviteShortCode shortCode,
  ) async {
    shortCodeWrites.add(shortCode);
    final callback = shortCodeCallback;
    if (callback != null) return callback(shortCode);
    if (_shortCodeResults.isEmpty) return HouseholdInviteCopyResult.copied;
    return _shortCodeResults.removeAt(0);
  }
}
