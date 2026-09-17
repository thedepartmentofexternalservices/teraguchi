#!/usr/bin/env python3
"""Exercise production NvHTTP with synthetic credentials on loopback TLS servers."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import http.server
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import tempfile
import threading
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', required=True, type=Path)
    parser.add_argument('--openssl', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    modes = ('transport-refused', 'transport-timeout', 'cancel-before-handshake',
             'success', 'wrong-pin', 'unknown-host', 'expired-setup', 'development',
             'wrong-port', 'redirect-auth', 'swap-before-password', 'swap-before-token',
             'rotation-overlap', 'rotation-removed', 'bad-profile', 'tls12',
             'expiry-during-auth', 'cancel-during-auth', 'oversized', 'malformed',
             'expired-certificate', 'redirect-token', 'reconnect-swap',
             'negative-unpinned')
    with tempfile.TemporaryDirectory(prefix='synthetic-tls-', dir=args.output) as temporary:
        directory = Path(temporary)
        pins = {}
        before = (datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y%m%d%H%M%SZ')
        after = (datetime.now(timezone.utc) + timedelta(days=1)).strftime('%Y%m%d%H%M%SZ')
        for number in (1, 2, 3, 4):
            subprocess.run([str(args.openssl), 'req', '-x509', '-newkey',
                            'rsa:2048' if number == 3 else 'rsa:3072', '-nodes', '-config', '/dev/null',
                            '-not_before', '20200101000000Z' if number == 4 else before,
                            '-not_after', '20200102000000Z' if number == 4 else after,
                            '-subj', '/CN=plank', '-addext', 'subjectAltName=DNS:plank',
                            '-keyout', str(directory / f'key{number}.pem'),
                            '-out', str(directory / f'cert{number}.pem')],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            pem = (directory / f'cert{number}.pem').read_text()
            pins[number] = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
        for mode in modes:
            marker = directory / 'boundary'
            marker.unlink(missing_ok=True)
            password, token = secrets.token_urlsafe(24), secrets.token_urlsafe(24)
            if mode in ('transport-refused', 'transport-timeout', 'cancel-before-handshake'):
                # Hold the port without a listener, or accept TCP without TLS.
                # No HTTP request or credential may reach this unavailable worker.
                with socket.socket() as unavailable:
                    unavailable.bind(('127.0.0.1', 0))
                    stop = threading.Event()
                    received = bytearray()
                    worker = None
                    if mode != 'transport-refused':
                        unavailable.listen(1)
                        unavailable.settimeout(10)
                        def hold_handshake():
                            with unavailable.accept()[0] as peer:
                                peer.settimeout(0.1)
                                marker.write_text('ready')
                                while not stop.is_set():
                                    try:
                                        data = peer.recv(4096)
                                        if not data: break
                                        received.extend(data)
                                    except socket.timeout:
                                        continue
                                    except (ConnectionResetError, OSError):
                                        break
                        worker = threading.Thread(target=hold_handshake)
                        worker.start()
                    try:
                        result = subprocess.run([str(args.client)], text=True, capture_output=True, timeout=10,
                            input=json.dumps({'mode': mode, 'port': unavailable.getsockname()[1],
                                              'pins': [pins[1]], 'password': password, 'token': token,
                                              'boundary_file': str(marker)}))
                    finally:
                        stop.set()
                        if worker: worker.join()
                    output = result.stdout + result.stderr
                    (args.output / f'probe-{mode}.txt').write_text(output)
                    if result.returncode or any(value in output for value in (password, token, 'synthetic-artist')):
                        raise RuntimeError(f'{mode}: incorrect failure classification or diagnostic leak')
                    if any(value in received for value in (b'GET ', b'POST ', password.encode(), token.encode())):
                        raise RuntimeError(f'{mode}: HTTP data sent before TLS verification')
                    print(f'{mode}=pass credential_requests=0')
                continue
            requests, canary_requests, faults = [], [], []
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = context.maximum_version = (
                ssl.TLSVersion.TLSv1_2 if mode == 'tls12' else ssl.TLSVersion.TLSv1_3)
            number = 3 if mode == 'bad-profile' else 4 if mode == 'expired-certificate' else 1
            context.load_cert_chain(directory / f'cert{number}.pem', directory / f'key{number}.pem')

            class Handler(http.server.BaseHTTPRequestHandler):
                protocol_version = 'HTTP/1.1'

                def log_message(self, *_):
                    pass

                def respond(self, status, data, **headers):
                    try:
                        self.send_response(status)
                        self.send_header('Content-Length', str(len(data)))
                        self.send_header('Connection', 'close')
                        for name, value in headers.items():
                            self.send_header(name, value)
                        self.end_headers()
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                        pass
                    self.close_connection = True

                def do_GET(self):
                    if self.server.canary:
                        canary_requests.append('get'); self.respond(403, b'{}'); return
                    requests.append('applist')
                    if self.path != '/applist' or self.headers.get('Authorization') != 'Bearer ' + token:
                        faults.append('unexpected authenticated request')
                    if mode == 'redirect-token':
                        self.respond(307, b'{}', Location=f'https://127.0.0.1:{canary.server_port}/applist'); return
                    if mode == 'reconnect-swap':
                        context.load_cert_chain(directory / 'cert2.pem', directory / 'key2.pem')
                    self.respond(200, b'<root status_code="200"></root>')

                def do_POST(self):
                    if self.server.canary:
                        canary_requests.append('post'); self.respond(403, b'{}'); return
                    size = int(self.headers.get('Content-Length', '0'))
                    if not 0 < size < 4096:
                        faults.append('invalid request size'); self.respond(400, b'{}'); return
                    body = json.loads(self.rfile.read(size))
                    if self.headers.get('Authorization'):
                        faults.append('bearer token in PAM request')
                    if self.path == '/plank/auth/start':
                        requests.append('start')
                        if body != {'username': 'synthetic-artist'}:
                            faults.append('unexpected username body')
                        if mode == 'redirect-auth':
                            self.respond(307, b'{}', Location=f'https://127.0.0.1:{canary.server_port}/plank/auth/respond')
                            return
                        if mode in ('swap-before-password', 'rotation-overlap'):
                            context.load_cert_chain(directory / 'cert2.pem', directory / 'key2.pem')
                        if mode in ('expiry-during-auth', 'cancel-during-auth'):
                            marker.write_text('ready')
                            time.sleep(0.35)
                        if mode in ('oversized', 'malformed'):
                            self.respond(200, b'x' * (40000 if mode == 'oversized' else 1)); return
                        self.respond(200, b'{"state":"challenge","conversation_id":"synthetic","messages":[{"style":1}]}')
                    elif self.path == '/plank/auth/respond':
                        requests.append('respond')
                        if body != {'conversation_id': 'synthetic', 'responses': [password]}:
                            faults.append('unexpected password body')
                        if mode == 'swap-before-token':
                            context.load_cert_chain(directory / 'cert2.pem', directory / 'key2.pem')
                        self.respond(200, json.dumps({'state': 'authenticated', 'session_token': token}).encode())
                    else:
                        faults.append('unexpected endpoint'); self.respond(404, b'{}')

            def server(canary=False):
                instance = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
                instance.daemon_threads = True
                instance.canary = canary
                instance.socket = context.wrap_socket(instance.socket, server_side=True)
                thread = threading.Thread(target=instance.serve_forever, kwargs={'poll_interval': 0.02})
                thread.start()
                return instance, thread

            canary, canary_thread = server(True)
            target, target_thread = server()
            allowed = [pins[1], pins[2]] if mode == 'rotation-overlap' else [pins[number]]
            if mode in ('wrong-pin', 'rotation-removed', 'negative-unpinned'):
                allowed = [pins[2]]
            try:
                result = subprocess.run([str(args.client)], text=True, capture_output=True, timeout=15,
                                        input=json.dumps({'mode': mode, 'port': target.server_port,
                                                          'pins': allowed, 'password': password, 'token': token,
                                                          'boundary_file': str(marker)}))
                output = result.stdout + result.stderr
                if any(value in output for value in (password, token, 'synthetic-artist')):
                    raise RuntimeError(f'{mode}: sensitive content reached diagnostics')
                (args.output / f'probe-{mode}.txt').write_text(output)
                if result.returncode or faults or canary_requests:
                    raise RuntimeError(f'{mode}: client/oracle/redirect failure')
                if mode in ('success', 'rotation-overlap', 'negative-unpinned', 'redirect-token', 'reconnect-swap'):
                    expected = ['start', 'respond', 'applist']
                elif mode == 'swap-before-token':
                    expected = ['start', 'respond']
                elif mode in ('redirect-auth', 'swap-before-password', 'expiry-during-auth',
                              'cancel-during-auth', 'oversized', 'malformed'):
                    expected = ['start']
                else:
                    expected = []
                if requests != expected:
                    raise RuntimeError(f'{mode}: unexpected credential-bearing request sequence')
                print(f'{mode}=pass requests={len(requests)} redirect_requests=0')
            finally:
                target.shutdown(); canary.shutdown()
                target_thread.join(); canary_thread.join()
                target.server_close(); canary.server_close()
    print(f'host_trust_loopback=pass cases={len(modes)} negative_unpinned_control=observed')


if __name__ == '__main__':
    main()
