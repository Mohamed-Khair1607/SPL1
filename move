#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

#define BUFFER_SIZE 4096

int mv_main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <source> <destination>\n", argv[0]);
        return 1;
    }

    const char *src = argv[1];
    const char *dest = argv[2];

    // First try atomic rename
    if (rename(src, dest) == 0) {
        return 0;
    }

    // Handle cross-filesystem move
    if (errno != EXDEV) {
        perror("mv");
        return 1;
    }

    // Open source file
    int src_fd = open(src, O_RDONLY);
    if (src_fd == -1) {
        perror("mv: open source");
        return 1;
    }

    // Get source metadata
    struct stat stat_buf;
    if (fstat(src_fd, &stat_buf) == -1) {
        perror("mv: fstat");
        close(src_fd);
        return 1;
    }

    // Open/create destination file
    int dest_fd = open(dest, O_WRONLY | O_CREAT | O_TRUNC, stat_buf.st_mode);
    if (dest_fd == -1) {
        perror("mv: open destination");
        close(src_fd);
        return 1;
    }

    // Copy data
    char buffer[BUFFER_SIZE];
    ssize_t bytes_read;
    while ((bytes_read = read(src_fd, buffer, sizeof(buffer))) > 0) {
        ssize_t bytes_written = write(dest_fd, buffer, bytes_read);
        
        if (bytes_written == -1) {
            perror("mv: write");
            close(src_fd);
            close(dest_fd);
            return 1;
        }

        if (bytes_written != bytes_read) {
            fprintf(stderr, "mv: partial write error\n");
            close(src_fd);
            close(dest_fd);
            return 1;
        }
    }

    // Check for read errors
    if (bytes_read == -1) {
        perror("mv: read");
        close(src_fd);
        close(dest_fd);
        return 1;
    }

    // Cleanup
    if (close(dest_fd) == -1) {
        perror("mv: close destination");
        close(src_fd);
        return 1;
    }

    if (close(src_fd) == -1) {
        perror("mv: close source");
        return 1;
    }

    // Remove original
    if (unlink(src) == -1) {
        perror("mv: unlink source");
        return 1;
    }

    return 0;
}
