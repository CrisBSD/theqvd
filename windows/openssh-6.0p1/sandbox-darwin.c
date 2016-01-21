/*
 * Copyright (c) 2011 Damien Miller <djm@mindrot.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include "includes.h"

#include <sys/types.h>

#include "ssh-sandbox.h"

#ifdef SANDBOX_DARWIN

#include <sandbox.h>

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "log.h"
#include "xmalloc.h"

/* Darwin/OS X sandbox */

struct ssh_sandbox {
	pid_t child_pid;
};

static int
sandbox_darwin_probe(void)
{
	return 1;
}

static void *
sandbox_darwin_init(void)
{
	struct ssh_sandbox *box;

	/*
	 * Strictly, we don't need to maintain any state here but we need
	 * to return non-NULL to satisfy the API.
	 */
	debug3("%s: preparing Darwin sandbox", __func__);
	box = xcalloc(1, sizeof(*box));
	box->child_pid = 0;

	return box;
}

static void
sandbox_darwin_child(void *vbox)
{
	struct ssh_sandbox *box = vbox;
	char *errmsg;
	struct rlimit rl_zero;

	debug3("%s: starting Darwin sandbox", __func__);
	if (sandbox_init(kSBXProfilePureComputation, SANDBOX_NAMED,
	    &errmsg) == -1)
		fatal("%s: sandbox_init: %s", __func__, errmsg);

	/*
	 * The kSBXProfilePureComputation still allows sockets, so
	 * we must disable these using rlimit.
	 */
	rl_zero.rlim_cur = rl_zero.rlim_max = 0;
	if (setrlimit(RLIMIT_FSIZE, &rl_zero) == -1)
		fatal("%s: setrlimit(RLIMIT_FSIZE, { 0, 0 }): %s",
			__func__, strerror(errno));
	if (setrlimit(RLIMIT_NOFILE, &rl_zero) == -1)
		fatal("%s: setrlimit(RLIMIT_NOFILE, { 0, 0 }): %s",
			__func__, strerror(errno));
	if (setrlimit(RLIMIT_NPROC, &rl_zero) == -1)
		fatal("%s: setrlimit(RLIMIT_NPROC, { 0, 0 }): %s",
			__func__, strerror(errno));
}

static void
sandbox_darwin_parent_finish(void *vbox)
{
	free(vbox);
	debug3("%s: finished", __func__);
}

static void
sandbox_darwin_parent_preauth(void *box, pid_t child_pid)
{
	struct ssh_sandbox *box = vbox;

	box->child_pid = child_pid;
}

Sandbox ssh_sandbox_darwin = {
	"darwin",
	sandbox_darwin_probe,
	sandbox_darwin_init,
	sandbox_darwin_child,
	sandbox_darwin_parent_finish,
	sandbox_darwin_parent_preauth
};

#else /* !SANDBOX_DARWIN */

Sandbox ssh_sandbox_darwin = {
	"darwin",
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
};

#endif /* SANDBOX_DARWIN */