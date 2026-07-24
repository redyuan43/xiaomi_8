#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int read_full(FILE *stream, uint8_t *buffer, size_t size)
{
	size_t offset = 0;

	while (offset < size) {
		size_t count = fread(buffer + offset, 1, size - offset, stream);

		if (count == 0) {
			if (ferror(stream))
				return -1;
			return offset ? -1 : 1;
		}

		offset += count;
	}

	return 0;
}

static int write_full(FILE *stream, const uint8_t *buffer, size_t size)
{
	size_t offset = 0;

	while (offset < size) {
		size_t count = fwrite(buffer + offset, 1, size - offset, stream);

		if (count == 0)
			return -1;

		offset += count;
	}

	return 0;
}

int main(int argc, char **argv)
{
	unsigned long width;
	unsigned long height;
	size_t packed_size;
	size_t unpacked_size;
	uint8_t *packed;
	uint8_t *unpacked;
	int ret = EXIT_FAILURE;

	if (argc != 3) {
		fprintf(stderr, "Usage: %s <width> <height>\n", argv[0]);
		return EXIT_FAILURE;
	}

	errno = 0;
	width = strtoul(argv[1], NULL, 10);
	height = strtoul(argv[2], NULL, 10);
	if (errno || !width || !height || width % 4) {
		fprintf(stderr, "width must be a non-zero multiple of four\n");
		return EXIT_FAILURE;
	}

	if (height > SIZE_MAX / width ||
	    width * height > SIZE_MAX / 2 ||
	    width * height > SIZE_MAX / 5 * 4) {
		fprintf(stderr, "frame dimensions are too large\n");
		return EXIT_FAILURE;
	}

	packed_size = width * height / 4 * 5;
	unpacked_size = width * height * 2;
	packed = malloc(packed_size);
	unpacked = malloc(unpacked_size);
	if (!packed || !unpacked) {
		perror("malloc");
		goto out;
	}

	for (;;) {
		size_t src;
		size_t dst;
		int read_result = read_full(stdin, packed, packed_size);

		if (read_result == 1) {
			ret = EXIT_SUCCESS;
			break;
		}
		if (read_result < 0) {
			fprintf(stderr, "incomplete RAW10 frame\n");
			break;
		}

		for (src = 0, dst = 0; src < packed_size; src += 5, dst += 8) {
			uint8_t low = packed[src + 4];
			uint16_t pixel0 = ((uint16_t)packed[src] << 2) | (low & 0x03);
			uint16_t pixel1 = ((uint16_t)packed[src + 1] << 2) |
					  ((low >> 2) & 0x03);
			uint16_t pixel2 = ((uint16_t)packed[src + 2] << 2) |
					  ((low >> 4) & 0x03);
			uint16_t pixel3 = ((uint16_t)packed[src + 3] << 2) |
					  ((low >> 6) & 0x03);

			pixel0 <<= 6;
			pixel1 <<= 6;
			pixel2 <<= 6;
			pixel3 <<= 6;
			unpacked[dst] = pixel0 & 0xff;
			unpacked[dst + 1] = pixel0 >> 8;
			unpacked[dst + 2] = pixel1 & 0xff;
			unpacked[dst + 3] = pixel1 >> 8;
			unpacked[dst + 4] = pixel2 & 0xff;
			unpacked[dst + 5] = pixel2 >> 8;
			unpacked[dst + 6] = pixel3 & 0xff;
			unpacked[dst + 7] = pixel3 >> 8;
		}

		if (write_full(stdout, unpacked, unpacked_size) < 0) {
			perror("write");
			break;
		}
	}

out:
	free(unpacked);
	free(packed);
	return ret;
}
