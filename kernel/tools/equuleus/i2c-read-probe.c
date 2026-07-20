#include <errno.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	struct i2c_rdwr_ioctl_data transfer;
	struct i2c_msg messages[2];
	unsigned char command[] = {0xfa, 0x20, 0x00, 0x00, 0x00};
	unsigned char value[2] = {0};
	char *end = NULL;
	long address;
	int fd;
	int result;

	if (argc != 3) {
		fprintf(stderr, "usage: %s /dev/i2c-N address\n", argv[0]);
		return 2;
	}

	address = strtol(argv[2], &end, 0);
	if (!end || *end || address < 0x03 || address > 0x77) {
		fprintf(stderr, "invalid 7-bit I2C address: %s\n", argv[2]);
		return 2;
	}

	fd = open(argv[1], O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "open %s: %s\n", argv[1], strerror(errno));
		return 1;
	}

	/* ST FTM5 chip ID: read two bytes from hardware register 0x20000000. */
	messages[0].addr = (unsigned short)address;
	messages[0].flags = 0;
	messages[0].len = sizeof(command);
	messages[0].buf = command;
	messages[1].addr = (unsigned short)address;
	messages[1].flags = I2C_M_RD;
	messages[1].len = sizeof(value);
	messages[1].buf = value;
	transfer.msgs = messages;
	transfer.nmsgs = 2;

	result = ioctl(fd, I2C_RDWR, &transfer);
	if (result != 2) {
		fprintf(stderr, "read FTS ID at address 0x%02lx: %s\n", address,
			result < 0 ? strerror(errno) : "short transfer");
		close(fd);
		return 1;
	}

	printf("address 0x%02lx ACK, FTS ID=%02x %02x\n", address,
	       value[0], value[1]);
	close(fd);
	return 0;
}

