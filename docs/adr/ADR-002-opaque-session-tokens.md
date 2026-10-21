# ADR-002: непрозрачные server-side session tokens

Статус: принято.

Сервер выдаёт cryptographically random 32-byte opaque token, закодированный как base64url. Сохраняется только SHA-256 digest token; raw value отправляется один раз в secure, HTTP-only, same-site cookie и никогда не логируется и не хранится в browser storage.

Это поддерживает отзыв отдельных sessions при logout, password reset, ban и media revocation без раскрытия bearer tokens JavaScript. Cookie attributes, CSRF/Origin enforcement, session lifetime и database persistence — отдельные implementation leaves. Решение соответствует запрету browser storage из OWASP session guidance: <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>.

## Реализация срока жизни (2026-10-21)

Web/API-сессия не зависит от процесса API: её digest и даты активности хранятся в PostgreSQL. Сессия завершается после 30 дней бездействия или через 180 дней после выдачи — что наступит раньше. API проверяет оба срока при каждой аутентификации. Secure, HTTP-only, SameSite=Lax cookie получает `Max-Age`/`Expires` до абсолютного серверного срока; успешные запросы продлевают хранение cookie только до того же срока. При переходе на эту политику ранее выданные строки получают 180 дней от миграции для абсолютного срока, а уже неактивные более 30 дней сессии завершаются сразу.

API также обновляет persistent cookie при успешном чтении текущей сессии. Поэтому действующий браузерный session-cookie становится persistent при первом открытии web-клиента после rollout; rollout сам по себе не меняет идентификатор или состояние выданной сессии.
