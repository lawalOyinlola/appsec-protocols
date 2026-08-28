# Controls 33/34 — shell and deserialization from Python.
import os, pickle, yaml, subprocess, xml.etree.ElementTree

os.system("convert " + user_input)
subprocess.run(cmd, shell=True)
data = pickle.loads(request.body)
cfg = yaml.load(request.body)
tree = xml.etree.ElementTree.parse(uploaded)
print("password", password)

# Control 15 — SQL built by interpolation, both Python forms.
cur.execute(f"SELECT * FROM users WHERE email = {email}")
cur.execute("SELECT * FROM orders WHERE id = %s" % order_id)
