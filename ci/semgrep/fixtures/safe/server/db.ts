// Control 15 — parameterized query; body validated to a primitive first.
const parsed = LoginSchema.parse(request.body);
const rows = await prisma.$queryRaw`SELECT id FROM users WHERE email = ${parsed.email}`;
const user = await users.findOne({ email: String(parsed.email) });
