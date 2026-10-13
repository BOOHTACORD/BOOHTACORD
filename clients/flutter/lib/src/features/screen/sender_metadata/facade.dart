import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin ScreenProfileDescriptorFacade on ApiFacadeBase {
  late final _screenDescriptor = ScreenProfileDescriptorApi(transport);

  Future<void> updateScreenProfileDescriptor(
    String leaseId,
    Map<String, Object?> descriptor, {
    Duration timeout = const Duration(seconds: 5),
    Future<void>? abortTrigger,
  }) => transport.run(
    () => _screenDescriptor.update(
      leaseId,
      descriptor,
      timeout: timeout,
      abortTrigger: abortTrigger,
    ),
  );
}
