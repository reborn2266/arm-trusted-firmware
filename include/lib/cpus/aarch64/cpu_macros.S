/*
 * Copyright (c) 2014-2016, ARM Limited and Contributors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of ARM nor the names of its contributors may be used
 * to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef __CPU_MACROS_S__
#define __CPU_MACROS_S__

#include <arch.h>

#define CPU_IMPL_PN_MASK	(MIDR_IMPL_MASK << MIDR_IMPL_SHIFT) | \
				(MIDR_PN_MASK << MIDR_PN_SHIFT)

/* The number of CPU operations allowed */
#define CPU_MAX_PWR_DWN_OPS		2

/* Special constant to specify that CPU has no reset function */
#define CPU_NO_RESET_FUNC		0

/* Word size for 64-bit CPUs */
#define CPU_WORD_SIZE			8

	/*
	 * Define the offsets to the fields in cpu_ops structure.
	 */
	.struct 0
CPU_MIDR: /* cpu_ops midr */
	.space  8
/* Reset fn is needed in BL at reset vector */
#if IMAGE_BL1 || IMAGE_BL31
CPU_RESET_FUNC: /* cpu_ops reset_func */
	.space  8
#endif
#if IMAGE_BL31 /* The power down core and cluster is needed only in BL31 */
CPU_PWR_DWN_OPS: /* cpu_ops power down functions */
	.space  (8 * CPU_MAX_PWR_DWN_OPS)
#endif
#if (IMAGE_BL31 && CRASH_REPORTING)
CPU_REG_DUMP: /* cpu specific register dump for crash reporting */
	.space  8
#endif
CPU_OPS_SIZE = .

	/*
	 * Write given expressions as quad words
	 *
	 * _count:
	 *	Write at least _count quad words. If the given number of
	 *	expressions is less than _count, repeat the last expression to
	 *	fill _count quad words in total
	 * _rest:
	 *	Optional list of expressions. _this is for parameter extraction
	 *	only, and has no significance to the caller
	 *
	 * Invoked as:
	 *	fill_constants 2, foo, bar, blah, ...
	 */
	.macro fill_constants _count:req, _this, _rest:vararg
	  .ifgt \_count
	    /* Write the current expression */
	    .ifb \_this
	      .error "Nothing to fill"
	    .endif
	    .quad \_this

	    /* Invoke recursively for remaining expressions */
	    .ifnb \_rest
	      fill_constants \_count-1, \_rest
	    .else
	      fill_constants \_count-1, \_this
	    .endif
	  .endif
	.endm

	/*
	 * Declare CPU operations
	 *
	 * _name:
	 *	Name of the CPU for which operations are being specified
	 * _midr:
	 *	Numeric value expected to read from CPU's MIDR
	 * _resetfunc:
	 *	Reset function for the CPU. If there's no CPU reset function,
	 *	specify CPU_NO_RESET_FUNC
	 * _power_down_ops:
	 *	Comma-separated list of functions to perform power-down
	 *	operatios on the CPU. At least one, and up to
	 *	CPU_MAX_PWR_DWN_OPS number of functions may be specified.
	 *	Starting at power level 0, these functions shall handle power
	 *	down at subsequent power levels. If there aren't exactly
	 *	CPU_MAX_PWR_DWN_OPS functions, the last specified one will be
	 *	used to handle power down at subsequent levels
	 */
	.macro declare_cpu_ops _name:req, _midr:req, _resetfunc:req, \
		_power_down_ops:vararg
	.section cpu_ops, "a"
	.align 3
	.type cpu_ops_\_name, %object
	.quad \_midr
#if IMAGE_BL1 || IMAGE_BL31
	.quad \_resetfunc
#endif
#if IMAGE_BL31
1:
	/* Insert list of functions */
	fill_constants CPU_MAX_PWR_DWN_OPS, \_power_down_ops
2:
	/*
	 * Error if no or more than CPU_MAX_PWR_DWN_OPS were specified in the
	 * list
	 */
	.ifeq 2b - 1b
	  .error "At least one power down function must be specified"
	.else
	  .iflt 2b - 1b - (CPU_MAX_PWR_DWN_OPS * CPU_WORD_SIZE)
	    .error "More than CPU_MAX_PWR_DWN_OPS functions specified"
	  .endif
	.endif
#endif
#if (IMAGE_BL31 && CRASH_REPORTING)
	.quad \_name\()_cpu_reg_dump
#endif
	.endm

#endif /* __CPU_MACROS_S__ */
