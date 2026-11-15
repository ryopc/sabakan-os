#ifndef __MACOS_ELF_H
#define __MACOS_ELF_H

/*
 * seiya.me macOS ビルドパッチ: Linux カーネル modpost / arch ツール用 ELF ヘッダ互換。
 * macOS の <libelf/gelf.h> にはカーネルが想定する reloc / sym 型マクロが
 * 不足しているため、ここで補完する。
 */

#include <libelf/gelf.h>

/* ELF シンボル種別 (SPARC 等) */
#ifndef STT_SPARC_REGISTER
#define STT_SPARC_REGISTER 13
#endif

/* x86 (i386) リロケーション種別 */
#ifndef R_386_NONE
#define R_386_NONE 0
#endif
#ifndef R_386_32
#define R_386_32 1
#endif
#ifndef R_386_PC32
#define R_386_PC32 2
#endif
#ifndef R_386_GOT32
#define R_386_GOT32 3
#endif
#ifndef R_386_PLT32
#define R_386_PLT32 4
#endif
#ifndef R_386_COPY
#define R_386_COPY 5
#endif
#ifndef R_386_GLOB_DAT
#define R_386_GLOB_DAT 6
#endif
#ifndef R_386_JMP_SLOT
#define R_386_JMP_SLOT 7
#endif
#ifndef R_386_RELATIVE
#define R_386_RELATIVE 8
#endif
#ifndef R_386_GOTOFF
#define R_386_GOTOFF 9
#endif
#ifndef R_386_GOTPC
#define R_386_GOTPC 10
#endif
#ifndef R_386_PC16
#define R_386_PC16 21
#endif
#ifndef R_386_PC8
#define R_386_PC8 23
#endif
#ifndef R_386_8
#define R_386_8 22
#endif
#ifndef R_386_16
#define R_386_16 20
#endif

/* x86_64 リロケーション種別 */
#ifndef R_X86_64_NONE
#define R_X86_64_NONE 0
#endif
#ifndef R_X86_64_64
#define R_X86_64_64 1
#endif
#ifndef R_X86_64_PC32
#define R_X86_64_PC32 2
#endif
#ifndef R_X86_64_32
#define R_X86_64_32 10
#endif
#ifndef R_X86_64_32S
#define R_X86_64_32S 11
#endif
#ifndef R_X86_64_PLT32
#define R_X86_64_PLT32 4
#endif
#ifndef R_X86_64_PC64
#define R_X86_64_PC64 24
#endif
#ifndef R_X86_64_GOT32
#define R_X86_64_GOT32 3
#endif
#ifndef R_X86_64_COPY
#define R_X86_64_COPY 5
#endif
#ifndef R_X86_64_GLOB_DAT
#define R_X86_64_GLOB_DAT 6
#endif
#ifndef R_X86_64_JMP_SLOT
#define R_X86_64_JMP_SLOT 7
#endif
#ifndef R_X86_64_JUMP_SLOT
#define R_X86_64_JUMP_SLOT 7
#endif
#ifndef R_X86_64_RELATIVE
#define R_X86_64_RELATIVE 8
#endif
#ifndef R_X86_64_GOTPCREL
#define R_X86_64_GOTPCREL 9
#endif
#ifndef R_X86_64_16
#define R_X86_64_16 14
#endif
#ifndef R_X86_64_PC16
#define R_X86_64_PC16 15
#endif
#ifndef R_X86_64_8
#define R_X86_64_8 16
#endif
#ifndef R_X86_64_PC8
#define R_X86_64_PC8 17
#endif

/* MIPS リロケーション種別 */
#ifndef R_MIPS_NONE
#define R_MIPS_NONE 0
#endif
#ifndef R_MIPS_16
#define R_MIPS_16 1
#endif
#ifndef R_MIPS_32
#define R_MIPS_32 2
#endif
#ifndef R_MIPS_REL32
#define R_MIPS_REL32 3
#endif
#ifndef R_MIPS_26
#define R_MIPS_26 4
#endif
#ifndef R_MIPS_HI16
#define R_MIPS_HI16 5
#endif
#ifndef R_MIPS_LO16
#define R_MIPS_LO16 6
#endif

/* ARM リロケーション種別 */
#ifndef R_ARM_NONE
#define R_ARM_NONE 0
#endif
#ifndef R_ARM_ABS32
#define R_ARM_ABS32 2
#endif
#ifndef R_ARM_REL32
#define R_ARM_REL32 3
#endif
#ifndef R_ARM_CALL
#define R_ARM_CALL 28
#endif
#ifndef R_ARM_JUMP24
#define R_ARM_JUMP24 29
#endif
#ifndef R_ARM_PC24
#define R_ARM_PC24 1
#endif
#ifndef R_ARM_MOVW_ABS_NC
#define R_ARM_MOVW_ABS_NC 43
#endif
#ifndef R_ARM_MOVT_ABS
#define R_ARM_MOVT_ABS 45
#endif
#ifndef R_ARM_THM_MOVW_ABS_NC
#define R_ARM_THM_MOVW_ABS_NC 47
#endif
#ifndef R_ARM_THM_MOVT_ABS
#define R_ARM_THM_MOVT_ABS 49
#endif
#ifndef R_ARM_THM_JUMP19
#define R_ARM_THM_JUMP19 30
#endif
#ifndef R_ARM_THM_PC22
#define R_ARM_THM_PC22 34
#endif
#ifndef R_ARM_THM_JUMP24
#define R_ARM_THM_JUMP24 32
#endif

/* AArch64 リロケーション種別 */
#ifndef R_AARCH64_NONE
#define R_AARCH64_NONE 0
#endif
#ifndef R_AARCH64_ABS64
#define R_AARCH64_ABS64 257
#endif
#ifndef R_AARCH64_ABS32
#define R_AARCH64_ABS32 258
#endif
#ifndef R_AARCH64_CALL26
#define R_AARCH64_CALL26 282
#endif
#ifndef R_AARCH64_JUMP26
#define R_AARCH64_JUMP26 283
#endif
#ifndef R_AARCH64_PREL64
#define R_AARCH64_PREL64 260
#endif
#ifndef R_AARCH64_PREL32
#define R_AARCH64_PREL32 261
#endif

#endif /* __MACOS_ELF_H */
