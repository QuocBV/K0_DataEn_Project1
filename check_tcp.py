"""Check TCP 1433 listening on host + whether SSI dbs have data."""
import socket

def try_connect(host, port):
    s = socket.socket()
    try:
        s.settimeout(4)
        s.connect((host, port))
        return True
    except Exception:
        return False
    finally:
        s.close()

print("localhost:1433", try_connect("localhost", 1433))
print("127.0.0.1:1433", try_connect("127.0.0.1", 1433))
print("hostname:1433", try_connect(socket.gethostname(), 1433))