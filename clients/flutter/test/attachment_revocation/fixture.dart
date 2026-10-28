import 'dart:convert';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_list.dart';

const attachment = MessageAttachment(
  id: 'image',
  originalName: 'test.png',
  sizeBytes: 10,
);
final original = DirectChatMessage(
  id: 'message',
  directMessageId: 'dm',
  authorId: 'member',
  body: '',
  createdAt: DateTime.utc(2026),
  deleted: false,
  revision: 1,
  attachments: const [attachment],
);
http.Response image() => http.Response.bytes(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  ),
  200,
  headers: {'content-type': 'image/png'},
);

Widget attachmentApp(AppState state) => MaterialApp(
  theme: guildTheme(),
  home: Scaffold(
    body: MessageAttachmentList(
      state: state,
      parentPath: '/direct-messages/dm',
      attachments: const [attachment],
    ),
  ),
);
