// Control 15 — SQL and NoSQL injection surfaces.
await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = ${req.params.id}`);
await knex.raw("SELECT 1");
const user = await users.findOne(req.body);
const q = "SELECT * FROM accounts WHERE owner = " + req.query.owner;
