#define _GNU_SOURCE

#include <errno.h>
#include <linux/reboot.h>
#include <stdio.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

int main(void)
{
	static const char reason[] = "bootloader";

	sync();
	if (syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		    LINUX_REBOOT_CMD_RESTART2, reason) < 0) {
		fprintf(stderr, "reboot to bootloader failed: %s\n",
			strerror(errno));
		return 1;
	}
	return 0;
}
