#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <signal.h>
#include <syslog.h>
#include <arpa/inet.h>

#define PORT 9000
#define BACKLOG 5 // Maximum number of pending connections
#define BUFFER_SIZE 1024
#define FILE_PATH "/var/tmp/aesdsocketdata"

int server_fd = -1;
int client_fd = -1;

void signal_handler(int signum) {
    if (signum == SIGINT) {
        // Handle SIGINT
        printf("SIGINT received\n");
    } else if (signum == SIGTERM) {
        // Handle SIGTERM
        printf("SIGTERM received\n");
    }

    syslog(LOG_INFO, "Caught signal, exiting");
    syslog(LOG_INFO, "Closed connection from 9000");
    printf("Closed connection from %d\n", PORT);
    if (client_fd != -1) close(client_fd);
    if (server_fd != -1) close(server_fd);

    remove("/var/tmp/aesdsocketdata");
    closelog();
    exit(0);
}

int main(int argc, char *argv[]) {
	int file_fd;
	struct sockaddr_in server_addr, client_addr;
	socklen_t client_addr_len = sizeof(client_addr);
	char buffer[BUFFER_SIZE];
	ssize_t bytes_received, bytes_read;

	int daemon_mode = 0;
	if (argc == 2 && strcmp(argv[1], "-d") == 0) {
		daemon_mode = 1;
	}

	// Connect Singnal with Interrupt handler
	signal(SIGINT, signal_handler);
	signal(SIGTERM, signal_handler);

	openlog("aesdsocket", LOG_PID, LOG_USER);

	// Create a socket
	server_fd = socket(AF_INET, SOCK_STREAM, 0);
	if (server_fd == -1) {
		perror("Socket creation failed");
		return -1;
	}

	// Configure server address structure
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = INADDR_ANY;
	server_addr.sin_port = htons(PORT);

	int opt = 1;
	if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) == -1) {
		perror("setsockopt failed");
		close(server_fd);
		return -1;
	}
	
	// Bind the socket to port 9000
	if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
		perror("Bind failied");
		close(server_fd);
		return -1;
	}

	// Daemon fork to create child process
	if(daemon_mode) {
		pid_t pid = fork();
		if (pid < 0) {
			perror("Fork failed");
			exit(EXIT_FAILURE);
		} else if (pid > 0) {
			// Parent exists
			exit(0);
		}

		// Child continues
		if (setsid() == -1) {
			perror("setsid failed");
			exit(EXIT_FAILURE);
		}

		// Redired stdio to /dev/null
		int dev_null = open("/dev/null", O_RDWR);
		if (dev_null != -1) {
			dup2(dev_null, STDIN_FILENO);
			dup2(dev_null, STDOUT_FILENO);
			dup2(dev_null, STDERR_FILENO);
			if (dev_null > 2) close(dev_null);
		}
	}

	// start listening for connections
	if (listen(server_fd, BACKLOG) == -1) {
		perror("Listen failed");
		close(server_fd);
		return -1;
	}

	printf("Server listening on port %d...\n", PORT);

	while(1) {

		// Accept a client connection
		client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_addr_len);
		if (client_fd == -1) {
		perror("Accept failed");
			close(server_fd);
			return -1;
		}

		char client_ip[INET_ADDRSTRLEN];
		inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
		syslog(LOG_INFO, "Accepted connection from %s", client_ip);
 

		printf("Client connected!\n");

		// Open the file for appending
		file_fd = open(FILE_PATH, O_WRONLY | O_CREAT | O_APPEND, 0644);
		if (file_fd == -1) {
			perror("File open failed");
			close(client_fd);
			close(server_fd);
			return -1;
		}

		// Receive data from client
		while ((bytes_received = recv(client_fd, buffer, BUFFER_SIZE - 1, 0)) > 0) {
			buffer[bytes_received] = '\0'; // Null-terminated received data
			// Write to file 
			if (write(file_fd, buffer, bytes_received) == -1) {
				perror("file write failed");
				break;
			}

			// Stop reading if newline is found
			if (strchr(buffer, '\n') != NULL) {
				break;
			}
		}

		if (bytes_received == -1) {
			perror("Receive failed");
		}

		printf("Close file fd\n");
		close(file_fd); // close file after writing
	
		// Open the file for reading
		file_fd = open(FILE_PATH, O_RDONLY);
		if (file_fd == -1) {
			perror("File open failed for reading");
			close(client_fd);
			close(server_fd);
			return -1;
		}

		// Send file content back to the client
		while((bytes_read = read(file_fd, buffer, BUFFER_SIZE)) > 0) {
			if (send(client_fd, buffer, bytes_read, 0) == -1) {
				perror("Send failed");
				break;
			}
		}
		printf("Close file_fd and client_fd\n");
		close(file_fd); // Close file after reading
		close(client_fd); // Close client after getting line
		printf("Closed connection with client\n");
	}
	

	// Close server skockets
	close(server_fd);
	closelog();
	return 0;
}

