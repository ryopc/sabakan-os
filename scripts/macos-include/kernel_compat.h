#ifndef __MACOS_KERNEL_COMPAT_H
#define __MACOS_KERNEL_COMPAT_H

/*
 * seiya.me macOS ビルドパッチ: カーネル基本型 / 属性マクロ互換ヘッダ。
 * ホストツール (sorttable 等) がカーネル uapi ヘッダを利用する際に
 * 必要な基本型 (s8, u8, s16, u16, ...) と GCC 拡張属性 (__attribute_const__ 等)
 * を事前定義する。
 *
 * 注意: __s8 / __u8 等のアンダースコア付き名は asm-generic/int-ll64.h が
 * 定義するため、ここでは定義しない（マクロ再定義エラーを避けるため）。
 * s8 / u8 等は uapi ヘッダでは定義されないため、ここで補完する。
 */

#ifndef s8
#define s8 signed char
#endif
#ifndef u8
#define u8 unsigned char
#endif
#ifndef s16
#define s16 short
#endif
#ifndef u16
#define u16 unsigned short
#endif
#ifndef s32
#define s32 int
#endif
#ifndef u32
#define u32 unsigned int
#endif
#ifndef s64
#define s64 long long
#endif
#ifndef u64
#define u64 unsigned long long
#endif

/* GCC 拡張属性 (Apple clang でも受け付ける形式) */
#ifndef __attribute_const__
#define __attribute_const__ __attribute__((__const__))
#endif
#ifndef __attribute_pure__
#define __attribute_pure__ __attribute__((__pure__))
#endif
#ifndef __attribute_deprecated__
#define __attribute_deprecated__ __attribute__((__deprecated__))
#endif
#ifndef __unused
#define __unused __attribute__((__unused__))
#endif

#endif /* __MACOS_KERNEL_COMPAT_H */
