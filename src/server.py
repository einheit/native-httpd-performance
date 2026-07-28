import asyncio
import multiprocessing
import os
import socket

async def handle_client(reader, writer):
    try:
        while True:
            # 1. Read request headers in chunks using a timeout to prevent stalls
            request_data = b""
            while b"\r\n\r\n" not in request_data:
                chunk = await asyncio.wait_for(reader.read(4096), timeout=2.0)
                if not chunk:
                    return  # Client disconnected abruptly
                request_data += chunk

            # 2. Check if ApacheBench requested Keep-Alive
            is_keep_alive = b"Connection: keep-alive" in request_data or b"Connection: Keep-Alive" in request_data

            # 3. Formulate the correct HTTP/1.1 response structure
            if is_keep_alive:
                conn_header = b"Connection: keep-alive\r\n"
            else:
                conn_header = b"Connection: close\r\n"

            response = (
                b"HTTP/1.1 200 OK\r\n"
                b"Content-Type: text/plain\r\n"
                b"Content-Length: 12\r\n" +
                conn_header +
                b"\r\n"
                b"Hello World\n"
            )

            # 4. Write out the payload
            writer.write(response)
            await writer.drain()

            # 5. Break the connection loop if Keep-Alive wasn't specified
            if not is_keep_alive:
                break

    except (asyncio.TimeoutError, ConnectionResetError, BrokenPipeError):
        pass  # Cleanly swallow network drops and connection reaping
    except Exception:
        pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass

async def run_worker_loop(shared_sock):
    """
    Each worker process runs its own independent asyncio event loop
    and listens to the exact same shared system socket.
    """
    # Create an asyncio-compatible server object around the pre-bound socket
    server = await asyncio.start_server(
        handle_client, 
        sock=shared_sock
    )
    
    async with server:
        await server.serve_forever()

def start_worker_process(shared_sock):
    """Entry point for each child process."""
    try:
        asyncio.run(run_worker_loop(shared_sock))
    except KeyboardInterrupt:
        pass

def main():
    host = '127.0.0.1'
    port = 8080
    
    # 1. Create a raw system socket at the parent level
    parent_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    
    # 2. Enable kernel-level socket recycling (fixes 'Address already in use' errors)
    parent_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # 3. Bind and listen before spawning workers so the socket can be inherited
    parent_sock.bind((host, port))
    parent_sock.listen(2048)  # Set a high backlog queue for ApacheBench bursts
    parent_sock.setblocking(False)

    # 4. Detect available CPU hardware threads
    num_workers = multiprocessing.cpu_count()
    print(f"Master process (PID: {os.getpid()}) bound to {host}:{port}")
    print(f"Spawning {num_workers} parallel workers to share the socket workload...")

    processes = []
    
    # 5. Spawn child processes passing the bound socket reference down
    for _ in range(num_workers):
        p = multiprocessing.Process(target=start_worker_process, args=(parent_sock,))
        p.daemon = True  # Ensures children die instantly if the parent is killed
        p.start()
        processes.append(p)

    # 6. Keep parent alive to supervise workers and handle termination cleanups
    try:
        for p in processes:
            p.join()
    except KeyboardInterrupt:
        print("\nShutting down master and workers...")

if __name__ == "__main__":
    main()

