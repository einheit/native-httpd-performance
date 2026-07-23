import asyncio

async def handle_client(reader, writer):
    try:
        # Read the incoming HTTP request headers until the blank line separator
        while True:
            line = await reader.readline()
            if not line or line == b'\r\n':
                break
        
        # Formulate a compliant HTTP/1.1 response matching your other servers
        response = (
            b"HTTP/1.1 200 OK\r\n"
            b"Content-Type: text/plain\r\n"
            b"Content-Length: 12\r\n"
            b"Connection: keep-alive\r\n\r\n"
            b"Hello World\n"
        )
        
        writer.write(response)
        await writer.drain()
    except Exception:
        pass
    finally:
        # Remove "Connection closed" argument from the parenthesis
        writer.close()
        await writer.wait_closed()

async def main():
    # Bind directly to localhost on port 8080
    server = await asyncio.start_server(handle_client, '127.0.0.1', 8080)
    print("Python 3 Asynchronous Server is running on port 8080...")
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

