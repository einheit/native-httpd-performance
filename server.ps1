# Define the listening URL and port
$url = "http://127.0.0.1:8080/"


# Create and start the HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($url)
$listener.Start()

Write-Host "Listening for requests on $url ... (Press Ctrl+C to stop)" -ForegroundColor Green

try {
    while ($listener.IsListening) {
        # Wait block until a request comes in
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        Write-Host "Received request for: $($request.Url)" -ForegroundColor Cyan

        # Prepare the response body
        $responseString = "<html><body><h1>Hello from PowerShell HTTP Server!</h1><p>Timestamp: $(Get-Date)</p></body></html>"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)

        # Set headers and content length
        $response.ContentLength64 = $buffer.Length
        $response.ContentType = "text/html"

        # Write data back to the browser and close the connection
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
    }
}
catch {
    Write-Host "Server stopped." -ForegroundColor Red
}
finally {
    $listener.Stop()
    $listener.Close()
}

