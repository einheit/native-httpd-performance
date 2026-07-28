require 'socket'

server = TCPServer.new('127.0.0.1', 8080)
loop do
  Thread.start(server.accept) do |client|
    # Read the request headers (required to flush the buffer for ab)
    while (line = client.gets) && line != "\r\n"
    end
    
    # Send a compliant HTTP/1.1 response
    client.print "HTTP/1.1 200 OK\r\n" \
                 "Content-Type: text/plain\r\n" \
                 "Content-Length: 12\r\n" \
                 "Connection: keep-alive\r\n\r\n" \
                 "Hello World\n"
    client.close
  end
end

