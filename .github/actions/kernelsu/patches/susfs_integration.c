// SPDX-License-Identifier: GPL-2.0-only
#include <linux/version.h>
#include <linux/ptrace.h>
#include <linux/cred.h>
#include <linux/fs.h>
#include <linux/namei.h>
#include <linux/printk.h>
#include <linux/uaccess.h>
#include <linux/sched.h>
#include <linux/types.h>
#include <linux/jump_label.h>
#include <linux/rcupdate.h>
#include <linux/dcache.h>
#include <linux/slab.h>
#include <linux/mm.h>
#include <linux/uidgid.h>

#include "klog.h"
#include "ksu.h"

#ifndef KSUD_PATH
#define KSUD_PATH "/data/adb/ksu"
#endif

/* ---------------------------------------------------------------
 * SUSFS static key definitions
 * --------------------------------------------------------------- */
DEFINE_STATIC_KEY_TRUE(ksu_is_input_hook_enabled);
EXPORT_SYMBOL(ksu_is_input_hook_enabled);

DEFINE_STATIC_KEY_TRUE(ksu_is_init_rc_hook_enabled);
EXPORT_SYMBOL(ksu_is_init_rc_hook_enabled);

/* ---------------------------------------------------------------
 * ksu_handle_execveat - init/zygote exec hook (50_add in fs/exec.c)
 * --------------------------------------------------------------- */
int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,
			void *envp, int *flags)
{
	return 0;
}
EXPORT_SYMBOL(ksu_handle_execveat);

/* ---------------------------------------------------------------
 * ksu_handle_execveat_sucompat - su→ksud redirect for execveat
 * --------------------------------------------------------------- */
int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,
				  void *argv_user, void *envp_user,
				  int *flags)
{
	struct filename *filename;

	if (unlikely(!filename_ptr))
		return 0;

	filename = *filename_ptr;
	if (IS_ERR(filename))
		return 0;

	if (likely(memcmp(filename->name, "/system/bin/su",
			  sizeof("/system/bin/su"))))
		return 0;

	pr_info("ksu_handle_execveat_sucompat: su found\n");
	memcpy((void *)filename->name, KSUD_PATH, sizeof(KSUD_PATH));
	return 0;
}
EXPORT_SYMBOL(ksu_handle_execveat_sucompat);

/* ---------------------------------------------------------------
 * Helper: userspace stack buffer
 * --------------------------------------------------------------- */
static void __user *stack_buf(const void *d, size_t len)
{
	char __user *p = (void __user *)current_user_stack_pointer() - len;
	return copy_to_user(p, d, len) ? NULL : p;
}

/* ---------------------------------------------------------------
 * ksu_handle_faccessat - su→sh redirect for faccessat
 * --------------------------------------------------------------- */
int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,
			 int *flags)
{
	char path[sizeof("/system/bin/su") + 1] = {0};
	static const char sh_path[] = "/system/bin/sh";

	strncpy_from_user(path, *filename_user, sizeof(path));

	if (unlikely(!memcmp(path, "/system/bin/su",
			    sizeof("/system/bin/su")))) {
		pr_info("ksu_handle_faccessat: su->sh!\n");
		*filename_user = stack_buf(sh_path, sizeof(sh_path));
	}
	return 0;
}
EXPORT_SYMBOL(ksu_handle_faccessat);

/* ---------------------------------------------------------------
 * ksu_handle_stat - su→sh redirect for stat (6.1+ kernel variant)
 * --------------------------------------------------------------- */
int ksu_handle_stat(int *dfd, struct filename **filename, int *flags)
{
	if (unlikely(IS_ERR(*filename) || (*filename)->name == NULL))
		return 0;

	if (likely(memcmp((*filename)->name, "/system/bin/su",
			  sizeof("/system/bin/su"))))
		return 0;

	pr_info("ksu_handle_stat: su->sh!\n");
	memcpy((void *)((*filename)->name), "/system/bin/sh",
	       sizeof("/system/bin/sh"));
	return 0;
}
EXPORT_SYMBOL(ksu_handle_stat);

/* ---------------------------------------------------------------
 * ksu_handle_sys_read - init.rc read hook (stub)
 * KSUN handles this via syscall hook in ksud_integration.c
 * --------------------------------------------------------------- */
void ksu_handle_sys_read(unsigned int fd)
{
}
EXPORT_SYMBOL(ksu_handle_sys_read);

/* ---------------------------------------------------------------
 * ksu_handle_vfs_fstat - init.rc fstat size fixup (stub)
 * --------------------------------------------------------------- */
void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr)
{
}
EXPORT_SYMBOL(ksu_handle_vfs_fstat);

/* ---------------------------------------------------------------
 * ksu_handle_sys_reboot - reboot syscall hook (stub)
 * KSUN handles reboot via kprobe in supercall.c
 * --------------------------------------------------------------- */
int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd,
			   void __user **arg)
{
	return 0;
}
EXPORT_SYMBOL(ksu_handle_sys_reboot);

/* ---------------------------------------------------------------
 * susfs_is_current_ksu_domain - check if current task is KSU domain
 * --------------------------------------------------------------- */
bool susfs_is_current_ksu_domain(void)
{
	extern bool is_ksu_domain(void);
	return is_ksu_domain();
}
EXPORT_SYMBOL(susfs_is_current_ksu_domain);
