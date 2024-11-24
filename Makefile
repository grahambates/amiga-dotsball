name=main
program=out/a

# Emulator options
BUILD=hunk
DEBUG=0
MODEL=A500
FASTMEM=0
CHIPMEM=512
SLOWMEM=512

BIN_DIR = ~/amiga/bin

# Binaries
CC = $(BIN_DIR)/bartman/opt/bin/m68k-amiga-elf-gcc
ELF2HUNK = $(BIN_DIR)/bartman/elf2hunk
EXE2ADF = $(BIN_DIR)/exe2adf
VASM = $(BIN_DIR)/bartman/vasmm68k_mot
VLINK = $(BIN_DIR)/vlink
KINGCON = $(BIN_DIR)/kingcon
AMIGECONV = $(BIN_DIR)/amigeconv
SHRINKLER = $(BIN_DIR)/bartman/Shrinkler
AMIGATOOLS = ~/.nvm/versions/node/v16.17.0/bin/amigatools
FSUAE = /Applications/FS-UAE.app/Contents/MacOS/fs-uae
VAMIGA = /Applications/vAmiga.app/Contents/MacOS/vAmiga

# Flags:
VASMFLAGS = -m68000 -opt-fconst -nowarn=62 -x -DDEBUG=$(DEBUG)
VLINKFLAGS = -bamigahunk -Bstatic
CCFLAGS = -g -MP -MMD -m68000 -Ofast -nostdlib -Wextra -fomit-frame-pointer -fno-tree-loop-distribution -flto -fwhole-program
LDFLAGS = -Wl,--emit-relocs,-Ttext=0
FSUAEFLAGS = --floppy_drive_0_sounds=off --automatic_input_grab=0  --chip_memory=$(CHIPMEM) --fast_memory=$(FASTMEM) --slow_memory=$(SLOWMEM) --amiga_model=$(MODEL)
SHRINKLER_FLAGS = -9
EXE2ADF_FLAGS = -p 112,dff,569

out_dir = ./out
dist_dir = ./dist

sources := main.asm $(wildcard */*.asm)
deps := $(sources:.asm=.d) # generated dependency makefiles

build_exe = $(out_dir)/$(name).$(BUILD).exe # unique exe filename for current build type
prog_exe = $(program).exe # generic name used in startup-sequence
# hunk build
hunk_exe = $(out_dir)/$(name).hunk.exe
hunk_debug = $(out_dir)/$(name).hunk-debug.exe
hunk_objects := $(sources:.asm=.hunk)
# elf build
elf_exe = $(out_dir)/$(name).elf.exe
elf_linked = $(program).elf
elf_objects := $(sources:.asm=.elf)
# dist
dist_exe = $(dist_dir)/$(name)
dist_adf = $(dist_dir)/$(name).adf

data = table.bin

all: $(build_exe)

dist: $(dist_adf)

run: $(build_exe)
	cp $< $(program).exe
	$(FSUAE) $(FSUAEFLAGS) --hard_drive_0=$(out_dir)

run-dist: $(dist_exe)
	cp $< $(program).exe
	$(FSUAE) $(FSUAEFLAGS) --hard_drive_0=$(out_dir)

run-adf: $(dist_adf)
	$(FSUAE) $(FSUAEFLAGS) $<

run-vamiga: $(build_exe)
	$(VAMIGA) $<

run-vamiga-dist: $(dist_exe)
	$(VAMIGA) $<

run-vamiga-adf: $(dist_adf)
	$(VAMIGA) $<

clean:
	$(RM) $(elf_objects) $(hunk_objects) $(deps) $(dist_exe) $(dist_adf) $(out_dir)/*.*

$(dist_exe): $(build_exe)
	$(SHRINKLER) $(SHRINKLER_FLAGS) $< $@

$(dist_adf): $(dist_exe)
	$(EXE2ADF) -i $(dist_exe) -a $@ $(EXE2ADF_FLAGS)

# BUILD=hunk (vasm/vlink)
$(hunk_exe): $(hunk_objects) $(hunk_debug)
	$(VLINK) $(VLINKFLAGS) -S $(hunk_objects) -o $@
	cp $@ $(prog_exe)
$(hunk_debug): $(hunk_objects)
	$(VLINK) $(VLINKFLAGS) $(hunk_objects) -o $@
%.hunk : %.asm $(data)
	$(VASM) $(VASMFLAGS) -Fhunk -linedebug -o $@ $<

# BUILD=elf (GCC/Bartman)
$(elf_exe): $(elf_linked)
	$(ELF2HUNK) $< $@ -s
	cp $@ $(prog_exe)
$(elf_linked): $(elf_objects)
	$(CC) $(CCFLAGS) $(LDFLAGS) $(elf_objects) -o $@
%.elf : %.asm $(data)
	$(VASM) $(VASMFLAGS) -Felf -dwarf=3 -o $@ $<

-include $(deps)

%.d : %.asm
	$(VASM) $(VASMFLAGS) -quiet -dependall=make -o "$(patsubst %.d,%.\$$(BUILD),$@)" $(CURDIR)/$< > $@

.PHONY: all clean dist run run-dist run-adf run-vamiga run-vamiga-dist run-vamiga-adf

table.bin draw.asm: gendata.js
	node $< > draw.asm
