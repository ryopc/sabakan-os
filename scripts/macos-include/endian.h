#ifndef __MACOS_ENDIAN_H
#define __MACOS_ENDIAN_H

/*
 * seiya.me macOS ビルドパッチ: <endian.h> 互換ヘッダ。
 * macOS ネイティブには <endian.h> が無いため、__builtin_bswap* で
 * バイトスワップ関数マクロを提供する。x86_64 (リトルエンディアン)
 * ホストを想定。
 */

#include <stdint.h>

/* コンパイラ組込みバイトオーダー */
#if defined(__BYTE_ORDER__)
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define __BYTE_ORDER __LITTLE_ENDIAN
#elif __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#define __BYTE_ORDER __BIG_ENDIAN
#else
#define __BYTE_ORDER __PDP_ENDIAN
#endif
#else
#define __BYTE_ORDER __LITTLE_ENDIAN
#endif

#ifndef __LITTLE_ENDIAN
#define __LITTLE_ENDIAN 1234
#endif
#ifndef __BIG_ENDIAN
#define __BIG_ENDIAN 4321
#endif
#ifndef __PDP_ENDIAN
#define __PDP_ENDIAN 3412
#endif

#ifndef BYTE_ORDER
#define BYTE_ORDER __BYTE_ORDER
#endif
#ifndef LITTLE_ENDIAN
#define LITTLE_ENDIAN __LITTLE_ENDIAN
#endif
#ifndef BIG_ENDIAN
#define BIG_ENDIAN __BIG_ENDIAN
#endif
#ifndef PDP_ENDIAN
#define PDP_ENDIAN __PDP_ENDIAN
#endif

#ifndef bswap_16
#define bswap_16 __builtin_bswap16
#endif
#ifndef bswap_32
#define bswap_32 __builtin_bswap32
#endif
#ifndef bswap_64
#define bswap_64 __builtin_bswap64
#endif

/* リトルエンディアンホスト (x86_64) 向けホスト変換マクロ */
#if __BYTE_ORDER == __LITTLE_ENDIAN
#define htole16(x) ((uint16_t)(x))
#define htole32(x) ((uint32_t)(x))
#define htole64(x) ((uint64_t)(x))
#define le16toh(x) ((uint16_t)(x))
#define le32toh(x) ((uint32_t)(x))
#define le64toh(x) ((uint64_t)(x))
#define htobe16(x) bswap_16(x)
#define htobe32(x) bswap_32(x)
#define htobe64(x) bswap_64(x)
#define be16toh(x) bswap_16(x)
#define be32toh(x) bswap_32(x)
#define be64toh(x) bswap_64(x)
#else
#define htobe16(x) ((uint16_t)(x))
#define htobe32(x) ((uint32_t)(x))
#define htobe64(x) ((uint64_t)(x))
#define be16toh(x) ((uint16_t)(x))
#define be32toh(x) ((uint32_t)(x))
#define be64toh(x) ((uint64_t)(x))
#define htole16(x) bswap_16(x)
#define htole32(x) bswap_32(x)
#define htole64(x) bswap_64(x)
#define le16toh(x) bswap_16(x)
#define le32toh(x) bswap_32(x)
#define le64toh(x) bswap_64(x)
#endif

#endif /* __MACOS_ENDIAN_H */
