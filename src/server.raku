react {
    whenever IO::Socket::Async.listen('0.0.0.0', 8080) -> $conn {
        my $request = '';
        whenever $conn {
            $request ~= $_;
            if $request.contains("\r\n\r\n") {
                my $body = "<html><body><h1>Hello from Raku!</h1></body></html>";
                my $response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {$body.encode.bytes}\r\n\r\n$body";
                await $conn.print($response);
                $conn.close();
            }
        }
    }
}

