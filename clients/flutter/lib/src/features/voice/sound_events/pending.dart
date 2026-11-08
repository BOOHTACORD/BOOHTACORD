import 'types.dart';

class PendingSoundEvent {
  const PendingSoundEvent(this.event, this.due);
  final SoundEvent event;
  final int due;
}
