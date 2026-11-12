/* Fuzzes parseURL(): splits an http:// URL into host, port, path and IPv6 scope. Both callers'
 * conventions are exercised: miniwget() passes a scope_id, simpleUPnPcommand() passes NULL. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include "miniwget_private.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	char hostname[MAXHOSTNAMELEN + 1];
	unsigned short port = 0;
	const char *path = NULL;
	unsigned int scope_id = 0;
	char *url = malloc(size + 1);
	if (!url) return 0;
	memcpy(url, data, size);
	url[size] = '\0';
	if (parseURL(url, hostname, &port, &path, &scope_id)) {
		volatile size_t n = strlen(hostname) + strlen(path);
		(void)n;
	}
	if (parseURL(url, hostname, &port, &path, NULL)) {
		volatile size_t n = strlen(hostname) + strlen(path);
		(void)n;
	}
	free(url);
	return 0;
}
