		incdir	"includes"
		include	"macros.i"

		xdef	_start
_start:
		include	"PhotonsMiniWrapper1.04!.S"


********************************************************************************
* Constants:
********************************************************************************

; Display window:
DIW_W = 256
DIW_H = 256
BPLS = 2
SCROLL = 0				; enable playfield scroll
INTERLEAVED = 0
DPF = 0					; enable dual playfield

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
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
		exg	a0,a1
		exg	a2,a0
		movem.l	a0-a2,DblBuffers-Vars(a5)

; Set bpl pointers in copper:
		lea	CopBplPt+2,a0
		moveq	#BPLS-1,d7
.bpl:		move.l	a1,d0
		swap	d0
		move.w	d0,(a0)		; hi
		move.w	a1,4(a0)	; lo
		lea	8(a0),a0
		lea	SCREEN_BPL(a1),a1
		dbf	d7,.bpl

		rts


********************************************************************************
Vars:
********************************************************************************

Frame:		dc.l	0

DblBuffers:
DrawScreen:	dc.l	Screen1
ViewScreen:	dc.l	Screen2
ClearScreen:	dc.l	Screen3

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

Cop:
		dc.w	fmode,0
		dc.w	diwstrt,DIW_YSTRT<<8!DIW_XSTRT
		dc.w	diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
		dc.w	ddfstrt,(DIW_XSTRT-17)>>1&$fc
		dc.w	ddfstop,(DIW_XSTRT-17+(DIW_W>>4-1)<<4)>>1&$fc-SCROLL*8
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,BPLS<<12!DPF<<10!$200
		dc.w	bplcon1,0
CopBplPt:	rept	BPLS*2
		dc.w	bpl0pt+REPTN*2,0
		endr
CopPal:
		dc.w	color00,$000
		dc.w	color01,$fff
		dc.w	color02,$f00
		dc.w	color03,$fff
		dc.l	-2
CopE:


*******************************************************************************
		bss_c
*******************************************************************************

Screen1:	ds.b	SCREEN_SIZE
Screen2:	ds.b	SCREEN_SIZE
Screen3:	ds.b	SCREEN_SIZE
