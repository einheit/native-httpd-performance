#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <poll.h>
#include <signal.h>

#define DEFAULT_PORT 8080
#define BUFFER_SIZE 2048
#define MAX_CONN 200 
#define TIMEOUT_MS 5000 

// Set a socket descriptor to non-blocking mode portably
int make_socket_non_blocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) return -1;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int main(int argc, char *argv[]) {
    int server_fd;
    struct sockaddr_in address;
    int opt = 1;
    int port = DEFAULT_PORT;

    // Handle command-line arguments for the port
    if (argc > 1) {
        char *endptr;
        long parsed_port = strtol(argv[1], &endptr, 10);
        
        // Validate that the argument is a pure number within the valid port range
        if (*endptr != '\0' || parsed_port < 1 || parsed_port > 65535) {
            fprintf(stderr, "Error: Invalid port number '%s'. Must be between 1 and 65535.\n", argv[1]);
            exit(EXIT_FAILURE);
        }
        port = (int)parsed_port;
    }

    // Ignore SIGPIPE portably across both OS families
    signal(SIGPIPE, SIG_IGN);

    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket failed");
        exit(EXIT_FAILURE);
    }

    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    if (make_socket_non_blocking(server_fd) < 0) {
        perror("Fcntl non-blocking failed");
        exit(EXIT_FAILURE);
    }

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

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

    // Initialize the pollfd array
    struct pollfd fds[MAX_CONN];
    int nfds = 1;

    memset(fds, 0, sizeof(fds));
    fds[0].fd = server_fd;
    fds[0].events = POLLIN; 

    char *http_response = "HTTP/1.1 200 OK\r\n"
                          "Content-Type: text/plain\r\n"
                          "Content-Length: 13\r\n"
                          "Connection: keep-alive\r\n\r\n"
                          "Hello from C!";
    int response_len = strlen(http_response);

    printf("Server running on port %d...\n", port);

    while (1) {
        int poll_count = poll(fds, nfds, TIMEOUT_MS);

        if (poll_count < 0) {
            if (errno == EINTR) continue;
            perror("Poll error");
            break;
        }

        // Check the master listening socket
        if (fds[0].revents & POLLIN) {
            while (1) { 
                struct sockaddr_in client_addr;
                socklen_t client_len = sizeof(client_addr);
                int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);

                if (client_fd < 0) {
                    if (errno == EAGAIN || errno == EWOULDBLOCK) {
                        break; 
                    }
                    perror("Accept error");
                    break;
                }

                if (make_socket_non_blocking(client_fd) < 0) {
                    close(client_fd);
                    continue;
                }

                if (nfds < MAX_CONN) {
                    fds[nfds].fd = client_fd;
                    fds[nfds].events = POLLIN;
                    fds[nfds].revents = 0;
                    nfds++;
                } else {
                    close(client_fd);
                }
            }
        }

        // Loop through active client sockets
        for (int i = 1; i < nfds; i++) {
            if (fds[i].revents & POLLIN) {
                char buffer[BUFFER_SIZE];
                memset(buffer, 0, BUFFER_SIZE);

                int bytes_read = read(fds[i].fd, buffer, BUFFER_SIZE - 1);

                if (bytes_read <= 0) {
                    close(fds[i].fd);
                    fds[i] = fds[nfds - 1]; 
                    nfds--;
                    i--;
                    continue;
                }

                write(fds[i].fd, http_response, response_len);

                int close_conn = 0;
                if (strcasestr(buffer, "Connection: close") != NULL) {
                    close_conn = 1;
                } else if (strcasestr(buffer, "HTTP/1.1") == NULL && 
                           strcasestr(buffer, "Connection: keep-alive") == NULL) {
                    close_conn = 1;
                }

                if (close_conn) {
                    close(fds[i].fd);
                    fds[i] = fds[nfds - 1];
                    nfds--;
                    i--;
                }
            } else if (fds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                close(fds[i].fd);
                fds[i] = fds[nfds - 1];
                nfds--;
                i--;
            }
        }
    }

    for (int i = 0; i < nfds; i++) {
        if (fds[i].fd >= 0) close(fds[i].fd);
    }
    return 0;
}

