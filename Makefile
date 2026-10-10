# FlyFPV — needs lua5.2 (override: make LUA=/path/to/lua52 LUAC=/path/to/luac52)
LUA ?= lua5.2
LUAC ?= luac5.2
PY ?= python3
SCENARIOS = $(filter-out _%,$(basename $(notdir $(wildcard inputs/*.lua))))
SIMU_DLLS ?= "C:/Program Files/EdgeTX/Companion 2.12/bin"
RADIO ?= gx12

.PHONY: all build test frames sim clean lint

all: build test

build:
	$(LUA) tools/build.lua
	$(LUAC) -p dist/SCRIPTS/TOOLS/flyfpv.lua dist/SCRIPTS/TOOLS/FLYFPV/*.lua

test: build
	$(LUA) tests/run_all.lua

frames: build
	@for s in $(SCENARIOS); do $(LUA) tools/run_frames.lua --script inputs/$$s.lua --out out/$$s --nopbm || exit 1; done

# the built files must never write a global
lint: build
	-luacheck src tools tests
	@! $(LUAC) -l -p dist/SCRIPTS/TOOLS/flyfpv.lua dist/SCRIPTS/TOOLS/FLYFPV/*.lua | grep 'SETTABUP.*_ENV' || (echo "global write in dist"; exit 1)

# real firmware (Companion simulator DLLs, Windows x64), see tools/simhost/README.md
sim: build
	$(PY) tools/simhost/simu_host.py --dll-dir $(SIMU_DLLS) --radio $(RADIO) --sd dist --tool FlyFPV --inputs tools/simhost/inputs/fly.txt --tail 2000 --out out/simu/fly

clean:
	rm -rf out
