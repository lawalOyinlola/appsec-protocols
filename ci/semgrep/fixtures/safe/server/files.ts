// Control 31 — opaque id looked up in the database; no user input reaches the path.
app.get("/dl/:id", async (req, res) => {
  const record = await files.findByOwner(req.session.userId, req.params.id);
  if (!record) return res.sendStatus(404);
  return res.sendFile(record.storedPath);
});
