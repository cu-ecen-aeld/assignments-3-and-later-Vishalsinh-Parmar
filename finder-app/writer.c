#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

#define LOG_TAG "writer"

int main(int argc, char* argv[]) {
  if (argc != 3) {
    syslog(LOG_ERR, "ERROR: Expected two arguments: directory and string\n");
    return 1;
  }

  char* directory = argv[1];
  char* str = argv[2];

  // Open the file for writing
  FILE* file = fopen(directory, "w");
  if (file == NULL) {
    syslog(LOG_ERR, "Error: Could not create file %s\n", directory);
    return 1;
  }

  // Write the string to the file
  int bytes_written = fwrite(str, sizeof(char), strlen(str), file);
  if (bytes_written != strlen(str)) {
    syslog(LOG_ERR, "Error: Error writing to file\n");
    fclose(file);
    return 1;
  }

  syslog(LOG_DEBUG, "Writing %s to %s\n", str, directory);

  printf("The file %s was successfully created with content: %s\n", directory, str);

  fclose(file);
  closelog();
  return 0;
}

