/* Fuzzes getHTTPResponse(): the HTTP response reader (status line, headers, Content-Length, chunked
 * bodies). The input is the byte stream a server sends, delivered through a socketpair. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include "miniwget_private.h"

#define MAX_STREAM 65536	/* fits the socketpair buffer, so the write never blocks */

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	int sv[2];
	int len = 0, status = 0;
	void *content;
	if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) return 0;
	if (size > MAX_STREAM) size = MAX_STREAM;
	if (size > 0 && send(sv[1], data, size, 0) < 0) {
		close(sv[0]); close(sv[1]);
		return 0;
	}
	shutdown(sv[1], SHUT_WR);
	content = getHTTPResponse(sv[0], &len, &status);
	free(content);
	close(sv[0]);
	close(sv[1]);
	return 0;
}
