#ifndef __MACOS_BYTESWAP_H
#define __MACOS_BYTESWAP_H

/*
 * seiya.me macOS ビルドパッチ: バイトスワップマクロ互換。
 * カーネル modpost 等が bswap_16/32/64 を参照するが、macOS ネイティブでは
 * <libkern/OSBigEndian.h> 等に別名があるため、__builtin_bswap* で補完する。
 */

#ifndef bswap_16
#define bswap_16 __builtin_bswap16
#endif
#ifndef bswap_32
#define bswap_32 __builtin_bswap32
#endif
#ifndef bswap_64
#define bswap_64 __builtin_bswap64
#endif

#endif /* __MACOS_BYTESWAP_H */
