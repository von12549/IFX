# Coding Standards

## Purpose
General conventions for code style, error handling, and logging.

## Scope
- Error handling patterns
- Logging standards
- Security practices
- Async/await patterns

**Note:** For naming conventions, see `/.claude/playbooks/naming-conventions.md`.

---

## Error Handling

**Rule:** Use Result pattern for expected failures, exceptions for unexpected errors.

**Rule:** Commands/Queries return `Result<T>` not raw values.

**Rule:** Never swallow exceptions - log and rethrow or return Result.Failure.

**Rule:** Validation errors throw `ValidationException` (caught by pipeline behavior).

---

## Logging

**Rule:** Use structured logging with Serilog.

**Rule:** Log levels:
- **Information**: HTTP requests, successful operations
- **Warning**: Failed auth, validation errors, retryable failures
- **Error**: Exceptions, system errors
- **Fatal**: Application termination

**Rule:** Include contextual data in logs (userId, correlationId, operation).

**Rule:** Never log sensitive data (passwords, tokens, PII).

---

## Security

**Rule:** Validate all input at API boundary using FluentValidation.

**Rule:** Use parameterized queries - never concatenate SQL.

**Rule:** Store tokens encrypted in production (AccessToken, RefreshToken in LoginEvent).

**Rule:** Run containers as non-root user.

**Rule:** CORS: Restrict origins in production, AllowAll only in development.

---

## Async/Await

**Rule:** All I/O operations must be async.

**Rule:** Repository methods return `Task<T>` or `ValueTask<T>`.

**Rule:** Pass `CancellationToken` through the call chain.

**Rule:** Use `AsNoTracking()` for read-only queries.
