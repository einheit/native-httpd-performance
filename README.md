# native-httpd-performance
Performance comparison of basic httpd implementations provided by various languages

# running the tests

The test.sh script runs each launch script, which compiles, if neccesary, and runs the server.

When all the tests are run, the test script displays the sorted performance of the implementations.

This benchmark is initially focused on latency, which, in addition to the underlying OS, is determined by the characteristics of the language:

* Compiled vs Interpreted - this is the biggest factor
* Concurrency Model (event-driven vs thread-per-request)
* Memory Management and Garbage Collection (GC) - This can cause sudden random latency spikes
* Runtime Context Switching - How this is implemented determines efficiency and scalability
* Global Interpreter Lock (GIL) - Languages using a global lock are less effective w/ multiple CPUs

And of the httpd server code:

* Event Loop vs. Thread Pool - Event loops can scale better than thread pools
* Lock Contention - Poorly designed algorithms can suffer from this, leaving cores idle
* Keep-Alive Handling - Can it use keepalive to bypass the 3-way TCP handshake for subsequent requests?


<img src="assets/screenshot.png" alt="App Screenshot" width="500">


# adding new implementations

New implementations in different languages are welcomed. They just need to adhere to these guidelines:

For each implementation in a given language, there will be two files - a server launch script and the server itself. The test script looks for all server launch scripts of the form "run-httpd.lang", which starts the server in that language.

For instance, the perl launch script is called "run-httpd.pl" and it launches the server, which is called "server.pl"

For compiled languages, the launch script will compile the program and run the resulting executable.

For the example of the go language, the launch script is called "run-httpd.go" and it compiles and launches its server, which is called "server_go"

If your chosen language includes an http implementation by default, you can simply use that, or if you prefer, you can implement an http server from lower level building blocks. Of course, many languages do not include an http library, and a lower level approach is the order of the day.
