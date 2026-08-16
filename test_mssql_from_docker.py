"""Test MSSQL connectivity from inside airbyte-server container via host.docker.internal."""
import subprocess, os

env = dict(os.environ)
env["PATH"] = r"C:\Users\Lucifer\AppData\Local\Programs\DockerDesktop\resources\bin;" + env.get("PATH", "")

# Try connecting from airbyte-server container
cmd = ["docker", "exec", "airbyte-server", "sh", "-c",
       "python3 -c \"import socket; s=socket.socket(); s.settimeout(3); s.connect(('host.docker.internal',1433)); print('MSSQL reachable via host.docker.internal:1433')\" || "
       "nc -zv host.docker.internal 1433 || echo FAIL"]
r = subprocess.run(cmd, capture_output=True, text=True, env=env)
print("RC", r.returncode)
print("OUT", r.stdout[-600:])
print("ERR", r.stderr[-400:])