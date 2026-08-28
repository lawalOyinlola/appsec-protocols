// Control 13 — algorithm pinned, issuer and audience checked.
const claims = jwt.verify(token, publicKey, {
  algorithms: ["RS256"],
  issuer: ISSUER,
  audience: AUDIENCE,
});
