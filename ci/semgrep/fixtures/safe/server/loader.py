# Controls 33/34 — argv list, no shell; JSON and SafeLoader only.
import json
import subprocess

import yaml

subprocess.run(["convert", input_path, output_path], check=True)
data = json.loads(request.body)
cfg = yaml.load(request.body, Loader=yaml.SafeLoader)
safe = yaml.safe_load(request.body)

# Control 15 — parameterized; the driver binds the value, not the string.
cur.execute("SELECT * FROM users WHERE email = %s", (email,))
cur.execute("SELECT * FROM orders WHERE id = ?", (order_id,))
