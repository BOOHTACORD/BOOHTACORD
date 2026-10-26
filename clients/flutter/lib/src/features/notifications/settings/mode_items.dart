import 'package:flutter/material.dart';

const notificationModeItems = [
  DropdownMenuItem(value: 'all', child: Text('Все сообщения')),
  DropdownMenuItem(value: 'mentions', child: Text('Только упоминания')),
  DropdownMenuItem(value: 'none', child: Text('Без уведомлений')),
];
