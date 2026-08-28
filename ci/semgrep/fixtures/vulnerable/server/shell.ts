// Control 33 — shell command construction.
child_process.exec(`convert ${input} ${output}`);
execSync("ls -la " + dir);
spawn("convert", [input], { shell: true });
