		incdir	"includes"
		include	"macros.i"

		xdef	_start
_start:
		include	"PhotonsMiniWrapper1.04!.S"


********************************************************************************
* Constants:
********************************************************************************

BUFFER_COUNT = 20

; Display window:
DIW_W = 256
DIW_H = 256
BPLS = 2
SCROLL = 0				; enable playfield scroll
INTERLEAVED = 0
DPF = 1					; enable dual playfield

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER!DMAF_SPRITE
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB

;-------------------------------------------------------------------------------
; Derived

COLORS = 1<<BPLS

SCREEN_BW = SCREEN_W/16*2		; byte-width of 1 bitplane line
		ifne	INTERLEAVED
SCREEN_MOD = SCREEN_BW*(BPLS-1)		; modulo (interleaved)
SCREEN_BPL = SCREEN_BW			; bitplane offset (interleaved)
		else
SCREEN_MOD = 0				; modulo (non-interleaved)
SCREEN_BPL = SCREEN_BW*SCREEN_H		; bitplane offset (non-interleaved)
		endc
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS	; byte size of screen buffer

DIW_BW = DIW_W/16*2
DIW_MOD = SCREEN_BW-DIW_BW+SCREEN_MOD-SCROLL*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H


********************************************************************************
Demo:
********************************************************************************
		bsr	WaitEOF
		move.l	#Cop,cop1lc(a6)
		move.w	#DMASET,dmacon(a6)
		lea	Vars(pc),a5

		bsr	SetSprites

;-------------------------------------------------------------------------------
.mainLoop:
		addq.l	#1,Frame
		bsr	Clear
		jsr	Draw

		bsr	SwapBuffers
		; move.w	#$f00,color00(a6)

		move.w	#DIW_YSTOP,d0
		bsr	WaitRaster

		btst	#CIAB_GAMEPORT0,ciaa ; Left mouse button not pressed?
		bne	.mainLoop
		rts


********************************************************************************
* Routines
********************************************************************************


********************************************************************************
; a0 - Screen buffer
;-------------------------------------------------------------------------------
Clear:
		WAIT_BLIT
		clr.w	bltdmod(a6)
		move.l	#$01000000,bltcon0(a6)
		move.l	ClearScreen(pc),bltdpt(a6)
		move.w	#SCREEN_H*BPLS*64+SCREEN_BW/2,bltsize(a6)
		rts


********************************************************************************
SwapBuffers:
		movem.l	DblBuffers(pc),a0-a2
		move.w	#SCREEN_SIZE,d0
		lea	Screens,a3
		lea	ScreensE,a4

		; Draw
		adda.w	d0,a0
		cmp.l	a4,a0
		blt	.ok1
		move.l	a3,a0
.ok1:
		; View
		adda.w	d0,a1
		cmp.l	a4,a1
		blt	.ok2
		move.l	a3,a1
.ok2:
		; Clear
		adda.w	d0,a2
		cmp.l	a4,a2
		blt	.ok3
		move.l	a3,a2
.ok3:
		movem.l	a0-a2,DblBuffers-Vars(a5)

		move.l	a1,d0

		move.l	d0,d1
		sub.l	#SCREEN_SIZE*9,d1
		cmp.l	#Screens,d1
		bge	.ok4
		add.l	#SCREEN_SIZE*BUFFER_COUNT,d1
.ok4:

		move.l	d0,d2
		sub.l	#SCREEN_SIZE*17,d2
		cmp.l	#Screens,d2
		bge	.ok5
		add.l	#SCREEN_SIZE*BUFFER_COUNT,d2
.ok5:

; Set bpl pointers in copper:
		lea	CopBplPt+2,a0

PokeBplPair	macro
		move.w	\1,4(a0)	; lo
		swap	\1
		move.w	\1,(a0)		; hi
		swap	\1
		add.l	#SCREEN_BPL,\1
		lea	8(a0),a0
		move.w	\1,4(a0)	; lo
		swap	\1
		move.w	\1,(a0)		; hi
		lea	8(a0),a0
		endm

		PokeBplPair d0
		PokeBplPair d1
		PokeBplPair d2

		rts


********************************************************************************
SetSprites:
		lea	CopSprPt+2,a2
		lea	Sprite,a0
		move.l	a0,a1

		moveq	#8-1,d7
.l:
		move.w	(a1)+,d3
		lea	(a0,d3),a3
		move.l	a3,d3
		move.w	d3,4(a2)
		swap	d3
		move.w	d3,(a2)
		lea	8(a2),a2
		dbf	d7,.l

		rts

********************************************************************************
Vars:
********************************************************************************

Frame:		dc.l	0

DblBuffers:
DrawScreen:	dc.l	Screens+SCREEN_SIZE*(BUFFER_COUNT-1)
ViewScreen:	dc.l	Screens+SCREEN_SIZE
ClearScreen:	dc.l	Screens

********************************************************************************
		section	draw,code
********************************************************************************

********************************************************************************
Draw:
		lea	Tbl,a0
		move.w	Frame+2,d0
		and.w	#255,d0
		lsl.w	#2,d0
		adda.w	d0,a0
		move.l	DrawScreen,a1
		move.w	#TABLE_SIZE/256,d2
		move.w	#128,d3

		include	"draw.asm"
		rts

********************************************************************************
		data
********************************************************************************

Tbl:		incbin	table.bin

TABLE_SIZE = *-Tbl


*******************************************************************************
		data_c
*******************************************************************************

COL_BG = $000
COL_FRONT = $fff
COL_BACK = $e19

Cop:
		dc.w	fmode,0
		dc.w	diwstrt,DIW_YSTRT<<8!DIW_XSTRT
		dc.w	diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
		dc.w	ddfstrt,(DIW_XSTRT-17)>>1&$fc
		dc.w	ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc-SCROLL*8
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,(6<<12)!(DPF<<10)!$200
		dc.w	bplcon1,0
		dc.w	bplcon2,1<<6
CopBplPt:	rept	6*2
		dc.w	bpl0pt+REPTN*2,0
		endr
CopSprPt:
		rept	8*2
		dc.w	sprpt+REPTN*2,0
		endr
CopPal:
		dc.w	color00,COL_BG	
		; dc.w	color01,COL_BACK 
		; dc.w	color02,COL_BACK
		; dc.w	color03,COL_BACK
		; dc.w	color04,COL_BACK
		; dc.w	color05,COL_BACK
		; dc.w	color06,COL_BACK
		; dc.w	color07,COL_BACK
		dc.w	color08,COL_FRONT
		dc.w	color09,COL_FRONT
		dc.w	color10,COL_FRONT
		dc.w	color11,COL_FRONT
		dc.w	color12,COL_FRONT
		dc.w	color13,COL_FRONT
		dc.w	color14,COL_FRONT
		dc.w	color15,COL_FRONT

BACKCOL		macro
		dc.w	color01,\1 
		dc.w	color02,\1
		dc.w	color03,\1
		dc.w	color04,\1
		dc.w	color05,\1
		dc.w	color06,\1
		dc.w	color07,\1
		endm
; https://gradient-blaster.grahambates.com/?points=e19@0,55a@125,e19@255&steps=256&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
Gradient:
		dc.w	$2b07,$fffe
		BACKCOL	$e19
		dc.w	$2c07,$fffe
		BACKCOL	$e29
		dc.w	$2d07,$fffe
		BACKCOL	$e19
		dc.w	$2e07,$fffe
		BACKCOL	$e29
		dc.w	$3007,$fffe
		BACKCOL	$e19
		dc.w	$3107,$fffe
		BACKCOL	$e29
		dc.w	$3907,$fffe
		BACKCOL	$d39
		dc.w	$3a07,$fffe
		BACKCOL	$d3a
		dc.w	$3b07,$fffe
		BACKCOL	$d39
		dc.w	$3c07,$fffe
		BACKCOL	$d3a
		dc.w	$3d07,$fffe
		BACKCOL	$d39
		dc.w	$4207,$fffe
		BACKCOL	$d3a
		dc.w	$4307,$fffe
		BACKCOL	$d39
		dc.w	$4607,$fffe
		BACKCOL	$d49
		dc.w	$4707,$fffe
		BACKCOL	$c39
		dc.w	$4807,$fffe
		BACKCOL	$c49
		dc.w	$4907,$fffe
		BACKCOL	$c3a
		dc.w	$4a07,$fffe
		BACKCOL	$c4a
		dc.w	$4b07,$fffe
		BACKCOL	$c39
		dc.w	$4c07,$fffe
		BACKCOL	$c4a
		dc.w	$4d07,$fffe
		BACKCOL	$c49
		dc.w	$4e07,$fffe
		BACKCOL	$c4a
		dc.w	$5107,$fffe
		BACKCOL	$b49
		dc.w	$5207,$fffe
		BACKCOL	$c49
		dc.w	$5407,$fffe
		BACKCOL	$b49
		dc.w	$5607,$fffe
		BACKCOL	$b4a
		dc.w	$5a07,$fffe
		BACKCOL	$b5a
		dc.w	$5b07,$fffe
		BACKCOL	$b4a
		dc.w	$5d07,$fffe
		BACKCOL	$b49
		dc.w	$5e07,$fffe
		BACKCOL	$b4a
		dc.w	$6007,$fffe
		BACKCOL	$b49
		dc.w	$6107,$fffe
		BACKCOL	$a4a
		dc.w	$6207,$fffe
		BACKCOL	$b59
		dc.w	$6307,$fffe
		BACKCOL	$a5a
		dc.w	$6407,$fffe
		BACKCOL	$a4a
		dc.w	$6807,$fffe
		BACKCOL	$a5a
		dc.w	$6907,$fffe
		BACKCOL	$a4a
		dc.w	$6a07,$fffe
		BACKCOL	$a5a
		dc.w	$6d07,$fffe
		BACKCOL	$a4a
		dc.w	$6e07,$fffe
		BACKCOL	$a49
		dc.w	$6f07,$fffe
		BACKCOL	$95a
		dc.w	$7107,$fffe
		BACKCOL	$959
		dc.w	$7207,$fffe
		BACKCOL	$94a
		dc.w	$7307,$fffe
		BACKCOL	$95a
		dc.w	$7907,$fffe
		BACKCOL	$85a
		dc.w	$7a07,$fffe
		BACKCOL	$95a
		dc.w	$7b07,$fffe
		BACKCOL	$94a
		dc.w	$7c07,$fffe
		BACKCOL	$95a
		dc.w	$7d07,$fffe
		BACKCOL	$85a
		dc.w	$8907,$fffe
		BACKCOL	$75a
		dc.w	$8a07,$fffe
		BACKCOL	$85a
		dc.w	$8b07,$fffe
		BACKCOL	$75a
		dc.w	$9707,$fffe
		BACKCOL	$65a
		dc.w	$9f07,$fffe
		BACKCOL	$55a
		dc.w	$a007,$fffe
		BACKCOL	$65a
		dc.w	$a107,$fffe
		BACKCOL	$55a
		dc.w	$a207,$fffe
		BACKCOL	$65a
		dc.w	$a307,$fffe
		BACKCOL	$55a
		dc.w	$af07,$fffe
		BACKCOL	$65a
		dc.w	$b007,$fffe
		BACKCOL	$55a
		dc.w	$b207,$fffe
		BACKCOL	$65b
		dc.w	$b307,$fffe
		BACKCOL	$65a
		dc.w	$bb07,$fffe
		BACKCOL	$64a
		dc.w	$bc07,$fffe
		BACKCOL	$75a
		dc.w	$c907,$fffe
		BACKCOL	$85a
		dc.w	$cb07,$fffe
		BACKCOL	$75a
		dc.w	$cc07,$fffe
		BACKCOL	$85a
		dc.w	$d807,$fffe
		BACKCOL	$94a
		dc.w	$d907,$fffe
		BACKCOL	$95a
		dc.w	$e007,$fffe
		BACKCOL	$959
		dc.w	$e107,$fffe
		BACKCOL	$94a
		dc.w	$e207,$fffe
		BACKCOL	$959
		dc.w	$e307,$fffe
		BACKCOL	$95a
		dc.w	$e507,$fffe
		BACKCOL	$a4a
		dc.w	$e607,$fffe
		BACKCOL	$a5a
		dc.w	$e707,$fffe
		BACKCOL	$a4a
		dc.w	$e807,$fffe
		BACKCOL	$a5a
		dc.w	$e907,$fffe
		BACKCOL	$a4a
		dc.w	$ea07,$fffe
		BACKCOL	$a5a
		dc.w	$ec07,$fffe
		BACKCOL	$a4a
		dc.w	$ef07,$fffe
		BACKCOL	$b5a
		dc.w	$f007,$fffe
		BACKCOL	$a4a
		dc.w	$f107,$fffe
		BACKCOL	$a59
		dc.w	$f207,$fffe
		BACKCOL	$b4a
		dc.w	$f407,$fffe
		BACKCOL	$b49
		dc.w	$f507,$fffe
		BACKCOL	$b4a
		dc.w	$f707,$fffe
		BACKCOL	$b49
		dc.w	$f807,$fffe
		BACKCOL	$b4a
		dc.w	$ff07,$fffe
		BACKCOL	$b49
		dc.w	$ffdf,$fffe	; PAL fix
		dc.w	$107,$fffe
		BACKCOL	$c49
		dc.w	$207,$fffe
		BACKCOL	$b4a
		dc.w	$307,$fffe
		BACKCOL	$c49
		dc.w	$407,$fffe
		BACKCOL	$c4a
		dc.w	$607,$fffe
		BACKCOL	$c49
		dc.w	$707,$fffe
		BACKCOL	$c4a
		dc.w	$807,$fffe
		BACKCOL	$c49
		dc.w	$907,$fffe
		BACKCOL	$c3a
		dc.w	$a07,$fffe
		BACKCOL	$c4a
		dc.w	$b07,$fffe
		BACKCOL	$c39
		dc.w	$c07,$fffe
		BACKCOL	$c4a
		dc.w	$d07,$fffe
		BACKCOL	$c39
		dc.w	$e07,$fffe
		BACKCOL	$c49
		dc.w	$f07,$fffe
		BACKCOL	$d39
		dc.w	$1607,$fffe
		BACKCOL	$d3a
		dc.w	$1707,$fffe
		BACKCOL	$d39
		dc.w	$1807,$fffe
		BACKCOL	$d3a
		dc.w	$1907,$fffe
		BACKCOL	$d39
		dc.w	$1a07,$fffe
		BACKCOL	$e3a
		dc.w	$1b07,$fffe
		BACKCOL	$d3a
		dc.w	$1c07,$fffe
		BACKCOL	$d39
		dc.w	$1d07,$fffe
		BACKCOL	$e29
		dc.w	$2307,$fffe
		BACKCOL	$e39
		dc.w	$2407,$fffe
		BACKCOL	$e2a
		dc.w	$2507,$fffe
		BACKCOL	$e19
		dc.w	$2607,$fffe
		BACKCOL	$e29
		dc.w	$2707,$fffe
		BACKCOL	$e19
		dc.w	$2807,$fffe
		BACKCOL	$e29
		dc.w	$2907,$fffe
		BACKCOL	$e19
		dc.w	$2a07,$fffe
		BACKCOL	$f19
		incbin	logo.COP
		dc.l	-2
CopE:

Sprite:		incbin	logo.ASP


*******************************************************************************
		bss_c
*******************************************************************************

Screens:	
		ds.b	SCREEN_SIZE*BUFFER_COUNT
ScreensE: 
