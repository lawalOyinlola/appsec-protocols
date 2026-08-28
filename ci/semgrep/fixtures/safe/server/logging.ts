// Control 36 — redaction happens at the logger, not the call site.
logger.info({ userId: user.id, route: req.path }, "login succeeded");
logger.error({ correlationId, code: err.code }, "request failed");
