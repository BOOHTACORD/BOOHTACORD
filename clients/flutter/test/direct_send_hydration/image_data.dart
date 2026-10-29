import 'dart:convert';

import 'package:http/http.dart' as http;

http.Response? mediaResponse(
  http.Request request,
  List<int>? original,
  List<int>? preview,
) {
  if (request.url.path.endsWith('/read-cursor')) return http.Response('', 204);
  if (!request.url.path.contains('/attachments/image')) return null;
  return http.Response.bytes(
    (request.url.path.endsWith('/preview') ? preview : original)!,
    200,
    headers: {'content-type': 'image/png'},
  );
}

final jpegOriginal = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsK'
  'CwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQU'
  'FBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAIAAwDAREA'
  'AhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQA'
  'AAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3'
  'ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWm'
  'p6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEA'
  'AwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSEx'
  'BhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElK'
  'U1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3'
  'uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDzT4Ka'
  'h/wnfxN0bQ/L+w/avO/f7vM27YZH+7xnO3HXvXR4h+Gf+o/DOK4g+ue29jye57Pkvz1IQ+Lnla3N'
  'f4Xe1tL3PsuJOPf+IiZVW4Y+q+w9vy+/z8/LySVT4eWF78lviVr31tZ/U/8Awob/AKjn/kp/9nX8'
  'X/67f9Q//k//ANqfh3/EHP8AqP8A/KX/AN0P/9k=',
);

final jpegPreview = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAwAAAAICAIAAABChommAAAAzUlEQVR4nEWPO04EMRAFbXeP5wfz'
  'WQII9gwkSFyZm3AJ4k1YCbQMnrHd3W60AbNPFZfq2dPzUVNs7UAFtf7hjC9vRwlRPZj/OVkbWyZC'
  'pQJKsdgupUvpPSjt4L03DEvSXuHsdQZfjUHFUlR3My0kdjPkooEhN985nNb5kUUtwg6+Ht63Ug9J'
  'L3Wccxee/If2Mo+Q0m7CQOSoIQzGTbn9pKDhMLjAbXULx64q6hYpcG3iB/Zf068VYqn8ralsndGR'
  '0XJB4dWYu3x9V4OhnT9GO33sw4sGRwAAAABJRU5ErkJggg==',
);

final gifOriginal = base64Decode(
  'R0lGODlhDAAIAIEAAPDSChTIMhQy5uYoHiH/C05FVFNDQVBFMi4wAwEAAAAh+QQADwAAACwAAAAA'
  'DAAIAAAIKQAHCBwYoKDBgQQNFkQoUOFChg4DCJhIEYDFixQrXrSYceJGjh0/AggIACH5BAEPAAEA'
  'LAAAAAAMAAgAgSiq3AAAAAAAAAAAAAgSAAEIHEiwoMGDCBMqXMiwYcGAADs=',
);

final gifPreview = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAwAAAAICAIAAABChommAAAAJ0lEQVR4nGN8piHHgAr0FoigiTCh'
  '8bEC6ili0eM6gSZ0h0tlYN0EAG/tBCrWOdk0AAAAAElFTkSuQmCC',
);
