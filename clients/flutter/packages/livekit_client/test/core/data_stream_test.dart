// Copyright 2024 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@Timeout(Duration(seconds: 5))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:livekit_client/livekit_client.dart';
import '../mock/e2e_container.dart';

void main() {
  E2EContainer? container;
  late Room room;

  setUpAll(() async {
    container = E2EContainer();
    room = container!.room;
    await container!.connectRoom();
  });

  tearDownAll(() async {
    await container?.dispose();
  });

  group('Stream Handler Registration', () {
    test('Register And Unregister Text And Byte Stream Handlers', () async {
      room.registerTextStreamHandler('chat', (TextStreamReader reader, String participantIdentity) {});

      room.registerByteStreamHandler('file', (ByteStreamReader reader, String participantIdentity) {});

      expect(room.textStreamHandlers.keys.first, 'chat');

      expect(room.byteStreamHandlers.keys.first, 'file');

      room.unregisterTextStreamHandler('chat');
      room.unregisterByteStreamHandler('file');

      expect(room.textStreamHandlers.keys.length, 0);
      expect(room.byteStreamHandlers.keys.length, 0);
    });
  });

  group('Text Streaming', () {
    test('Send Basic Text Message', () async {
      final received = Completer<String>();
      room.registerTextStreamHandler('chat', (TextStreamReader reader, String participantIdentity) async {
        try {
          received.complete(await reader.readAll());
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });
      final info = await room.localParticipant?.sendText(
        'some text !!!',
        options: SendTextOptions(
          topic: 'chat',
        ),
      );
      expect(info, isNotNull);
      expect(await received.future.timeout(const Duration(seconds: 5)), 'some text !!!');
    });

    test('Send Text Message With UTF-8 Byte Length For Special Characters', () async {
      const text = 'Café résumé – emoji 😀';

      // Completed by the handler so the test cannot pass without the
      // assertions on the received stream having run.
      final received = Completer<void>();
      room.registerTextStreamHandler('chat-utf8', (TextStreamReader reader, String participantIdentity) async {
        try {
          expect(await reader.readAll(), text);
          expect(reader.info!.size, utf8.encode(text).length);
          received.complete();
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });

      final info = await room.localParticipant?.sendText(
        text,
        options: SendTextOptions(
          topic: 'chat-utf8',
        ),
      );
      expect(info, isNotNull);
      await received.future.timeout(const Duration(seconds: 5));
    });

    test('Send Large Text Message With Progress Tracking', () async {
      final longText = 'a' * 100000;
      final received = Completer<String>();
      final progressValues = <double>[];

      room.registerTextStreamHandler('chat-long-text', (TextStreamReader reader, String participantIdentity) async {
        try {
          received.complete(await reader.readAll());
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });

      final info = await room.localParticipant?.sendText(
        longText,
        options: SendTextOptions(
          topic: 'chat-long-text',
          onProgress: (progress) {
            progressValues.add(progress);
            expect(progress, greaterThanOrEqualTo(0.0));
            expect(progress, lessThanOrEqualTo(1.0));
          },
        ),
      );
      expect(info, isNotNull);
      expect(await received.future.timeout(const Duration(seconds: 5)), longText);
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, 1.0);
    });

    test('Stream Text With Multiple Chunks', () async {
      final received = Completer<String>();
      room.registerTextStreamHandler('chat-stream', (TextStreamReader reader, String participantIdentity) async {
        try {
          received.complete(await reader.readAll());
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });

      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'chat-stream',
        ),
      );
      expect(stream, isNotNull);
      await stream?.write('a' * 10);
      await stream?.write('b' * 10);
      await stream?.write('c' * 10);
      await stream?.close();
      expect(await received.future.timeout(const Duration(seconds: 5)), '${'a' * 10}${'b' * 10}${'c' * 10}');
    });

    test('Send Text Message With Multiple File Attachments', () async {
      final longText = 'a' * 100000;
      final directory = await Directory.systemTemp.createTemp('livekit-attachments-test-');
      addTearDown(() => directory.delete(recursive: true));
      final files = <File>[];
      final expectedFiles = <String, List<int>>{};
      for (var index = 0; index < 4; index++) {
        final name = 'testfile$index.bin';
        final bytes = List<int>.generate(100000, (i) => (i + index) % 256);
        final file = File('${directory.path}/$name');
        await file.writeAsBytes(bytes);
        files.add(file);
        expectedFiles[name] = bytes;
      }
      final receivedText = Completer<String>();
      final allFiles = Completer<void>();
      final receivedFiles = <String, List<int>>{};
      final progressValues = <double>[];

      room.registerTextStreamHandler('chat-stream-with-files', (
        TextStreamReader reader,
        String participantIdentity,
      ) async {
        try {
          receivedText.complete(await reader.readAll());
        } catch (error, stackTrace) {
          receivedText.completeError(error, stackTrace);
        }
      });

      room.registerByteStreamHandler('chat-stream-with-files', (
        ByteStreamReader reader,
        String participantIdentity,
      ) async {
        try {
          final chunks = await reader.readAll();
          receivedFiles[reader.info!.name] = chunks.expand((element) => element).toList();
          if (receivedFiles.length == files.length) allFiles.complete();
        } catch (error, stackTrace) {
          if (!allFiles.isCompleted) allFiles.completeError(error, stackTrace);
        }
      });

      final info = await room.localParticipant?.sendText(
        longText,
        options: SendTextOptions(
          topic: 'chat-stream-with-files',
          attachments: files,
          onProgress: (progress) {
            progressValues.add(progress);
            expect(progress, greaterThanOrEqualTo(0.0));
            expect(progress, lessThanOrEqualTo(1.0));
          },
        ),
      );
      expect(info, isNotNull);
      expect(await receivedText.future.timeout(const Duration(seconds: 5)), longText);
      await allFiles.future.timeout(const Duration(seconds: 5));
      expect(receivedFiles, expectedFiles);
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, 1.0);
    });

    test('Text Stream With Operation Types', () async {
      final operationTypes = [
        TextStreamOperationType.create,
        TextStreamOperationType.update,
        TextStreamOperationType.delete,
        TextStreamOperationType.reaction,
      ];
      for (var operationType in operationTypes) {
        final received = Completer<(String, TextStreamOperationType?)>();
        room.registerTextStreamHandler('chat-operations', (TextStreamReader reader, String participantIdentity) async {
          try {
            final text = await reader.readAll();
            if (text.startsWith('Streamed ')) received.complete((text, reader.info?.operationType));
          } catch (error, stackTrace) {
            if (!received.isCompleted) received.completeError(error, stackTrace);
          }
        });

        final info = await room.localParticipant?.sendText(
          'Test ${operationType}',
          options: SendTextOptions(
            topic: 'chat-operations',
          ),
        );

        // Test with streamText and different operation types
        final stream = await room.localParticipant?.streamText(
          StreamTextOptions(
            topic: 'chat-operations',
            type: operationType,
            version: operationType == TextStreamOperationType.update ? 2 : null,
          ),
        );
        expect(stream, isNotNull);
        await stream?.write('Streamed ${operationType}');
        await stream?.close();

        expect(info, isNotNull);
        expect(await received.future.timeout(const Duration(seconds: 5)), ('Streamed ${operationType}', operationType));
        room.unregisterTextStreamHandler('chat-operations');
      }
    });

    test('Text Stream With Attributes And Metadata', () async {
      final testAttributes = {'userId': '12345', 'sessionId': 'abc123', 'priority': 'high'};
      final received = Completer<TextStreamReader>();

      room.registerTextStreamHandler('chat-metadata', (TextStreamReader reader, String participantIdentity) async {
        received.complete(reader);
      });

      final info = await room.localParticipant?.sendText(
        'Test message with metadata',
        options: SendTextOptions(
          topic: 'chat-metadata',
          attributes: testAttributes,
        ),
      );
      expect(info, isNotNull);
      final reader = await received.future.timeout(const Duration(seconds: 5));
      expect(await reader.readAll(), 'Test message with metadata');
      expect(reader.info!.attributes, containsPair('userId', '12345'));
      expect(reader.info!.attributes, containsPair('sessionId', 'abc123'));
      expect(reader.info!.attributes, containsPair('priority', 'high'));
    });

    test('Text Stream With Reply Functionality', () async {
      const originalStreamId = 'original-stream-123';
      const replyStreamId = 'reply-stream-456';
      final received = Completer<TextStreamReader>();

      room.registerTextStreamHandler('chat-replies', (TextStreamReader reader, String participantIdentity) async {
        received.complete(reader);
      });

      // Send a reply to an existing stream
      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'chat-replies',
          type: TextStreamOperationType.create,
          streamId: replyStreamId,
          replyToStreamId: originalStreamId,
          version: 1,
        ),
      );
      expect(stream, isNotNull);
      await stream?.write('This is a reply to the original message');
      await stream?.close();
      final reader = await received.future.timeout(const Duration(seconds: 5));
      expect(await reader.readAll(), 'This is a reply to the original message');
      expect(reader.info?.replyToStreamId, originalStreamId);
      expect(reader.info?.version, 1);
      expect(reader.info?.operationType, TextStreamOperationType.create);
    });

    test('Text Stream With AI Generated Flag', () async {
      final received = Completer<TextStreamReader>();
      room.registerTextStreamHandler('chat-ai-generated', (TextStreamReader reader, String participantIdentity) async {
        received.complete(reader);
      });

      // Test AI-generated message
      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'chat-ai-generated',
          generated: true,
          attributes: {'aiModel': 'gpt-4', 'confidence': '0.95'},
        ),
      );
      expect(stream, isNotNull);
      await stream?.write('This message was generated by AI');
      await stream?.close();
      final reader = await received.future.timeout(const Duration(seconds: 5));
      expect(await reader.readAll(), 'This message was generated by AI');
      expect(reader.info?.generated, isTrue);
      expect(reader.info?.attributes, containsPair('aiModel', 'gpt-4'));
      expect(reader.info?.attributes, containsPair('confidence', '0.95'));
    });

    test('Text Stream With File Attachments', () async {
      const attachedIds = ['file-123', 'file-456', 'file-789'];
      final msg = 'Message with file attachments';
      final received = Completer<TextStreamReader>();
      room.registerTextStreamHandler('chat-with-attachments', (
        TextStreamReader reader,
        String participantIdentity,
      ) async {
        received.complete(reader);
      });

      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'chat-with-attachments',
          attachedStreamIds: attachedIds,
          totalSize: msg.length, // 'Message with file attachments'.length
        ),
      );
      expect(stream, isNotNull);
      await stream?.write(msg);
      await stream?.close();
      final reader = await received.future.timeout(const Duration(seconds: 5));
      expect(await reader.readAll(), msg);
      expect(reader.info?.attachedStreamIds, attachedIds);
    });
  });

  group('Byte Streaming', () {
    test('Send And Receive Binary File', () async {
      final directory = await Directory.systemTemp.createTemp('livekit-stream-test-');
      addTearDown(() => directory.delete(recursive: true));
      final filePath = '${directory.path}/testfile.bin';
      final received = Completer<ByteStreamReader>();

      /// create random file
      final randomFile = File(filePath);
      final random = Random();
      final bytes = List<int>.generate(100000, (index) => random.nextInt(256));
      randomFile.writeAsBytesSync(bytes);

      room.registerByteStreamHandler('file', (ByteStreamReader reader, String participantIdentity) async {
        received.complete(reader);
      });

      final fileToSend = File(filePath);
      final info = await room.localParticipant?.sendFile(
        fileToSend,
        options: SendFileOptions(
          topic: 'file',
          onProgress: (progress) {
            print('progress: ${progress * 100} %');
            expect(progress, greaterThanOrEqualTo(0.0));
            expect(progress, lessThanOrEqualTo(1.0));
          },
        ),
      );
      expect(info, isNotNull);
      final reader = await received.future.timeout(const Duration(seconds: 5));
      final chunks = await reader.readAll();
      expect(chunks.expand((element) => element).toList(), bytes);
    });

    test('Stream Raw Bytes With UTF8 Content', () async {
      final received = Completer<List<int>>();
      room.registerByteStreamHandler('bytes-stream', (ByteStreamReader reader, String participantIdentity) async {
        try {
          final chunks = await reader.readAll();
          received.complete(chunks.expand((element) => element).toList());
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });

      final stream = await room.localParticipant?.streamBytes(
        StreamBytesOptions(
          topic: 'bytes-stream',
          totalSize: 30,
        ),
      );
      expect(stream, isNotNull);
      await stream?.write(utf8.encode('a' * 10));
      await stream?.write(utf8.encode('b' * 10));
      await stream?.write(utf8.encode('c' * 10));
      await stream?.close();
      expect(utf8.decode(await received.future.timeout(const Duration(seconds: 5))), '${'a' * 10}${'b' * 10}${'c' * 10}');
    });

    test('Byte Stream With Attributes And MIME Type', () async {
      final testAttributes = {'uploadedBy': 'user123', 'category': 'document'};
      const testMimeType = 'application/pdf';
      const testFileName = 'test-document.pdf';
      final received = Completer<ByteStreamReader>();

      room.registerByteStreamHandler('files-with-metadata', (
        ByteStreamReader reader,
        String participantIdentity,
      ) async {
        received.complete(reader);
      });

      final stream = await room.localParticipant?.streamBytes(
        StreamBytesOptions(
          topic: 'files-with-metadata',
          name: testFileName,
          mimeType: testMimeType,
          attributes: testAttributes,
          totalSize: 100,
        ),
      );
      expect(stream, isNotNull);

      // Simulate PDF content
      final pdfContent = List<int>.generate(100, (index) => index % 256);
      await stream?.write(Uint8List.fromList(pdfContent));
      await stream?.close();
      final reader = await received.future.timeout(const Duration(seconds: 5));
      final chunks = await reader.readAll();
      expect(reader.info?.name, testFileName);
      expect(reader.info?.mimeType, testMimeType);
      expect(reader.info?.attributes, testAttributes);
      expect(chunks.expand((element) => element).toList(), pdfContent);
    });
  });

  group('Performance And Stress Tests', () {
    test('Handle Multiple Concurrent Streams', () async {
      var receivedCount = 0;
      const expectedCount = 3;

      room.registerTextStreamHandler('concurrent-streams', (TextStreamReader reader, String participantIdentity) async {
        final text = await reader.readAll();
        receivedCount++;
        print('received concurrent message ${receivedCount}: ${text}');
      });

      // Start multiple concurrent streams
      final futures = <Future>[];
      for (int i = 0; i < expectedCount; i++) {
        futures.add(() async {
          final stream = await room.localParticipant?.streamText(
            StreamTextOptions(
              topic: 'concurrent-streams',
              streamId: 'stream-${i}',
              type: TextStreamOperationType.create,
            ),
          );
          await stream?.write('Concurrent message ${i}');
          await stream?.close();
        }());
      }

      await Future.wait(futures);

      // Allow time for all messages to be processed
      await Future.delayed(Duration(milliseconds: 100));
      expect(receivedCount, expectedCount);
    });

    test('Handle Large Stream Chunks Above Normal Size', () async {
      const chunkSize = 50000; // Larger than normal chunk size
      final largeData = 'x' * chunkSize;
      final received = Completer<String>();

      room.registerTextStreamHandler('large-chunks', (TextStreamReader reader, String participantIdentity) async {
        try {
          received.complete(await reader.readAll());
        } catch (error, stackTrace) {
          received.completeError(error, stackTrace);
        }
      });

      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'large-chunks',
          totalSize: chunkSize,
        ),
      );
      expect(stream, isNotNull);
      await stream?.write(largeData);
      await stream?.close();
      expect(await received.future.timeout(const Duration(seconds: 5)), largeData);
    });
  });

  group('Header And Metadata Validation', () {
    test('Validate Complete Header Information Transmission', () async {
      // Test comprehensive header data transmission
      final testCompleter = Completer<bool>();

      room.registerTextStreamHandler('header-validation', (TextStreamReader reader, String participantIdentity) async {
        final text = await reader.readAll();
        print('=== Header Validation Test ===');
        print('Received text: ${text}');
        print('Reader info ID: ${reader.info?.id}');
        print('Reader info topic: ${reader.info?.topic}');
        print('Reader info mimeType: ${reader.info?.mimeType}');
        print('Reader info timestamp: ${reader.info?.timestamp}');
        print('Reader info size: ${reader.info?.size}');
        print('Reader info attributes: ${reader.info?.attributes}');

        // Validate the content
        expect(text, 'Header validation test message');

        // Validate basic stream properties
        expect(reader.info?.topic, 'header-validation');
        expect(reader.info?.mimeType, 'text/plain');
        expect(reader.info?.id, isNotNull);
        expect(reader.info?.timestamp, isNotNull);

        // Test passes if we get here without exceptions
        testCompleter.complete(true);
      });
      final msg = 'Header validation test message';
      // Send a message with comprehensive options
      final stream = await room.localParticipant?.streamText(
        StreamTextOptions(
          topic: 'header-validation',
          type: TextStreamOperationType.create,
          version: 1,
          generated: false,
          attributes: {
            'test': 'header-validation',
            'complex': 'data-transmission',
            'number': '123',
          },
          attachedStreamIds: ['attachment-1', 'attachment-2'],
          replyToStreamId: 'parent-message-123',
          totalSize: msg.length, // Length of test message
        ),
      );

      await stream?.write(msg);
      await stream?.close();

      // Wait for the test to complete or timeout
      await testCompleter.future.timeout(Duration(seconds: 3));
    });
  });
}
