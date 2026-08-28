// Control 13 — JWT handling failures.
const claims = jwt.verify(token, publicKey);
const peek = jwt.decode(token);
const forged = { alg: "none", typ: "JWT" };
