#!/usr/bin/crystal

require "http/server"

# Initialize the server and define request behavior
server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
#  context.response.print "Hello from Crystal! 🚀\nThe local time is #{Time.local}"
  context.response.print "Hello from Crystal!"
end

# Bind the server to a network port
address = server.bind_tcp "127.0.0.1", 8080
puts "Listening on http://#{address}"

# Start the server loop
server.listen

