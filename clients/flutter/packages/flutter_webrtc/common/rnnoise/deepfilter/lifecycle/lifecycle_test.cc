#include "lifecycle.h"
#include <cassert>
#include <thread>

using namespace boohta::deepfilter;

int main() {
  Lifecycle lifecycle;
  assert(lifecycle.Snapshot().state == LifecycleState::stopped);
  const auto first = lifecycle.Start();
  assert(first != 0 && lifecycle.Snapshot().state == LifecycleState::starting);
  assert(!lifecycle.Activate(first | (std::uint64_t{1} << 61)));
  assert(lifecycle.Snapshot().state == LifecycleState::starting);
  assert(lifecycle.Activate(first));
  assert(lifecycle.Snapshot().state == LifecycleState::active);
  const auto muted = lifecycle.Mute();
  assert(muted > first && lifecycle.Snapshot().state == LifecycleState::muted);
  assert(!lifecycle.Fail(first));
  assert(!lifecycle.Activate(first));
  assert(lifecycle.Snapshot().state == LifecycleState::muted);
  const auto second = lifecycle.Start();
  assert(second > muted && !lifecycle.Fail(first));
  assert(lifecycle.Fail(second));
  assert(lifecycle.Snapshot().state == LifecycleState::failed);
  assert(!lifecycle.Activate(second));
  const auto stopped = lifecycle.Stop();
  assert(stopped > second && !lifecycle.Fail(second));
  assert(lifecycle.Snapshot().state == LifecycleState::stopped);

  for (int i = 0; i < 10000; ++i) {
    const auto old = lifecycle.Start();
    std::thread worker([&] { lifecycle.Fail(old); });
    const auto current = lifecycle.Start();
    worker.join();
    const auto snapshot = lifecycle.Snapshot();
    assert(snapshot.generation == current);
    assert(snapshot.state == LifecycleState::starting);
  }
}
