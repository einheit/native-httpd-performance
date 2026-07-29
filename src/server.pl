# server.pl - used by plack/Starman
my $app = sub {
    return [
        200,
        ['Content-Type' => 'text/html'],
        ["<html><body><h1>Hello from Perl</h1></body></html>"]
    ];
};
