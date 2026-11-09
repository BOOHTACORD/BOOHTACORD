# Issue 689 public route composition

**Goal:** Register the guest WebSocket on the running API with a process-owned maintenance observer and matching OpenAPI contract.

**Route:** application composition and `GET /api/v1/public/realtime` only. Legacy SSE remains temporarily for client compatibility.

- [x] Test that the composed route dispatches without session authentication, and RED before registration.
- [x] Start and stop the observer around API lifetime, register the handler and document the new endpoint. Extract existing startup responsibilities to keep the composition entrypoint under the file limit while preserving their order.
- [x] Run composition tests, contract parity, backend checks and a real-stack test; record anything not run.
