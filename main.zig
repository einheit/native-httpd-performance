const std = @import("std");
const posix = std.posix;
const system = std.posix.system; 

pub fn main() !void {
    // 1. Setup the 0.17.0-dev DebugAllocator
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    // 2. Define the IPv4 socket address structure for 127.0.0.1:8080
    // FIX: Changed 'u8' to '[2]u8' to properly allow array initialization
    const port_bytes: [2]u8 = .{ @intCast((8080 >> 8) & 0xFF), @intCast(8080 & 0xFF) };
    var address = system.sockaddr.in{
        .family = system.AF.INET,
        .port = @bitCast(port_bytes),
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };

    // 3. Create the TCP socket stream via standard system call
    const socket_fd = system.socket(
        system.AF.INET,
        system.SOCK.STREAM | system.SOCK.CLOEXEC,
        system.IPPROTO.TCP,
    );
    if (socket_fd >= @as(usize, @bitCast(@as(isize, -4095)))) return error.SocketCreationFailed;
    defer _ = system.close(@intCast(socket_fd));

    // Set SO_REUSEADDR safely with proper type casting
    const reuse: c_int = 1;
    _ = system.setsockopt(
        @intCast(socket_fd), 
        system.SOL.SOCKET, 
        @intCast(system.SO.REUSEADDR), 
        std.mem.asBytes(&reuse), 
        @intCast(@sizeOf(c_int))
    );

    // 4. Bind the socket and start listening
    const sock_addr_ptr: *const system.sockaddr = @ptrCast(&address);
    if (system.bind(@intCast(socket_fd), sock_addr_ptr, @sizeOf(system.sockaddr.in)) == @as(usize, @bitCast(@as(isize, -1)))) return error.BindFailed;
    if (system.listen(@intCast(socket_fd), 128) == @as(usize, @bitCast(@as(isize, -1)))) return error.ListenFailed;

    std.debug.print("Listening on http://127.0.0.1:8080\n", .{});

    // 5. Connection Acceptance Loop
    while (true) {
        var client_address: system.sockaddr = undefined;
        var client_address_len: system.socklen_t = @sizeOf(system.sockaddr);

        // Accept client connections via system interface
        const client_fd = system.accept(@intCast(socket_fd), &client_address, &client_address_len);
        if (client_fd >= @as(usize, @bitCast(@as(isize, -4095)))) continue;
        defer _ = system.close(@intCast(client_fd));

        // Read the incoming HTTP request payload
        var read_buffer: [1024]u8 = undefined;
        const bytes_received = system.read(@intCast(client_fd), &read_buffer, read_buffer.len);
        if (bytes_received > 0 and bytes_received < @as(usize, @bitCast(@as(isize, -4095)))) {
            // Find and log the first line of the HTTP request (e.g., "GET / HTTP/1.1")
            var line_iter = std.mem.splitScalar(u8, read_buffer[0..bytes_received], '\n');
            if (line_iter.next()) |first_line| {
                std.debug.print("Request Line: {s}\n", .{std.mem.trimEnd(u8, first_line, "\r")});
            }
        }

        // 6. Structure and write out the literal HTTP raw response
        const http_body = "Hello from a raw Zig 0.17.0-dev POSIX server!\n";
        const http_response = 
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/plain\r\n" ++
            "Content-Length: 46\r\n" ++ 
            "Connection: close\r\n\r\n" ++
            http_body;

         _ = system.write(@intCast(client_fd), http_response, http_response.len);
    }
}

