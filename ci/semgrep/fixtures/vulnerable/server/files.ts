// Control 31 — path traversal.
app.get("/dl", (req, res) => {
  const p = path.join(UPLOADS, req.query.name);
  res.sendFile(req.params.file);
  return fs.readFileSync(req.query.name);
});
