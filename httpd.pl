#!/usr/bin/perl

package MyServer;
use base qw(HTTP::Server::Simple::CGI);

# Define what happens when a request comes in
sub handle_request {
    my ($self, $cgi) = @value;
    
    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header('text/html');
    print "<html><body><h1>Hello from Perl</h1></body></html>";
}

# Start the server on port 8080
my $server = MyServer->new(8080);
print "Server started on http://localhost:8080\n";
$server->run();

