#define _GNU_SOURCE // Required for strcasestr()
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <signal.h>

#define PORT 8080
#define BUFFER_SIZE 2048

// Signal handler to automatically reap zombie child processes
void sigchld_handler(int s) {
    (void)s; // Suppress unused variable warning
    int saved_errno = errno;
    while (waitpid(-1, NULL, WNOHANG) > 0);
    errno = saved_errno;
}

int main() {
    int server_fd, client_fd;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char buffer[BUFFER_SIZE];
    int opt = 1;

    // Prevent early disconnect crashes
    signal(SIGPIPE, SIG_IGN);

    // Set up SIGCHLD handler to clean up closed connections automatically
    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        perror("sigaction failed");
        exit(EXIT_FAILURE);
    }

    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    if (listen(server_fd, 1024) < 0) {
        perror("Listen failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    char *http_response = "HTTP/1.1 200 OK\r\n"
                          "Content-Type: text/plain\r\n"
                          "Content-Length: 13\r\n"
                          "Connection: keep-alive\r\n"
                          "\r\n"
                          "Hello from C!";
    int response_len = strlen(http_response);

    while (1) {
        client_fd = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
        if (client_fd < 0) {
            continue;
        }

        // Fork a child process to handle this specific connection
        pid_t pid = fork();

        if (pid < 0) {
            perror("Fork failed");
            close(client_fd);
            continue;
        }

        if (pid == 0) {
            // --- CHILD PROCESS ---
            // The child does not need the listener socket
            close(server_fd);

            // 1. Enable TCP Keep-Alive
            int keepalive_opt = 1;
            setsockopt(client_fd, SOL_SOCKET, SO_KEEPALIVE, &keepalive_opt, sizeof(keepalive_opt));

            // 2. Set a 5-second receive timeout for idle clients
            struct timeval timeout;
            timeout.tv_sec = 5;
            timeout.tv_usec = 0;
            setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

            // 3. Keep-alive request loop
            while (1) {
                memset(buffer, 0, BUFFER_SIZE);
                int bytes_read = read(client_fd, buffer, BUFFER_SIZE - 1);
                
                // Connection closed or timeout reached
                if (bytes_read <= 0) {
                    break; 
                }

                write(client_fd, http_response, response_len);

                // If client explicitly requested termination, break immediately
                if (strcasestr(buffer, "Connection: close") != NULL) {
                    break;
                }
                
                // Fallback for standard HTTP/1.0 clients that don't support keep-alive
                if (strcasestr(buffer, "HTTP/1.1") == NULL && strcasestr(buffer, "Connection: keep-alive") == NULL) {
                    break;
                }
            }

            close(client_fd);
            exit(0); // Exit child process cleanly
        } else {
            // --- PARENT PROCESS ---
            // The parent doesn't need this specific client socket descriptor
            close(client_fd);
        }
    }

    close(server_fd);
    return 0;
}

