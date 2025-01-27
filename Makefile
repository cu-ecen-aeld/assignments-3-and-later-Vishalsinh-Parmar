# Define source and build directories
SRC_DIR := ./finder-app
BUILD_DIR := ./build

# Define default build target
all: $(BUILD_DIR)/writer

# Define compiler and linker flags
CC := gcc 
LDFLAGS := 

# Source files
SRC := $(wildcard $(SRC_DIR)/*.c) 

# Object files
OBJ := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SRC))

# Create build directory if it doesn't exist
$(shell mkdir -p $(BUILD_DIR))

# Build the executable
$(BUILD_DIR)/writer: $(OBJ)
	$(CC) $(OBJ) -o $@ $(LDFLAGS)

# Create object files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) -c $< -o $@

# Clean target
clean:
	rm -rf $(BUILD_DIR)

