import 'package:boohtacord_desktop/src/app_state.dart';

bool rosterHasDeafened(AppState app, String channelId, bool deafened) =>
    app.voiceRosters?.any(
      (room) =>
          room.channelId == channelId &&
          room.participants.any(
            (member) =>
                member.accountId == app.user?.accountId &&
                member.deafened == deafened,
          ),
    ) ==
    true;
