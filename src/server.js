const http = require('http');

http.createServer((req, res) => {
  res.end('Hello from Node.js');
}).listen(8080);

