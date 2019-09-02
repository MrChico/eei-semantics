# Settings
# --------

BUILD_DIR:=.build
DEFN_DIR:=$(BUILD_DIR)/defn
BUILD_LOCAL:=$(BUILD_DIR)/local
LIBRARY_PATH:=$(BUILD_LOCAL)/lib
PKG_CONFIG_PATH:=$(LIBRARY_PATH)/pkgconfig
export LIBRARY_PATH
export PKG_CONFIG_PATH

K_SUBMODULE:=$(BUILD_DIR)/k
PLUGIN_SUBMODULE:=plugin

# need relative path for `pandoc` on MacOS
PANDOC_TANGLE_SUBMODULE:=$(BUILD_DIR)/pandoc-tangle
TANGLER:=$(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH:=$(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export TANGLER
export LUA_PATH

.PHONY: all clean deps k-deps tangle-deps ocaml-deps build build-java defn

all: build

clean:
	rm -rf $(BUILD_DIR)
	git submodule update --init

# Dependencies
# ------------

deps: k-deps tangle-deps
k-deps: $(K_SUBMODULE)/make.timestamp
tangle-deps: $(PANDOC_TANGLE_SUBMODULE)/make.timestamp

$(K_SUBMODULE)/make.timestamp:
	@echo "== submodule: $@"
	git submodule update --init -- $(K_SUBMODULE)
	cd $(K_SUBMODULE) \
		&& mvn package -q -DskipTests -U
	touch $(K_SUBMODULE)/make.timestamp

$(PANDOC_TANGLE_SUBMODULE)/make.timestamp:
	@echo "== submodule: $@"
	git submodule update --init -- $(PANDOC_TANGLE_SUBMODULE)
	touch $(PANDOC_TANGLE_SUBMODULE)/make.timestamp

K_BIN=$(K_SUBMODULE)/k-distribution/target/release/k/bin

# Definitions
# -----------

java_dir:=$(DEFN_DIR)/java
ocaml_dir:=$(DEFN_DIR)/ocaml
haskell_dir:=$(DEFN_DIR)/haskell

# Tangle definition from *.md files

$(java_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(k_tangler)" $< > $@

$(ocaml_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(k_tangler)" $< > $@

$(haskell_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(k_tangler)" $< > $@


k_tangler:=".k"

k_files:=eei-driver.k eei.k
java_defn:=$(patsubst %,$(java_dir)/%,$(k_files))
ocaml_defn:=$(patsubst %,$(ocaml_dir)/%,$(k_files))
haskell_defn:=$(patsubst %,$(haskell_dir)/%,$(k_files))
syntax_module:=eei-driver.k
main_module:=EEI-DRIVER

defn: defn-ocaml defn-java defn-haskell
defn-ocaml: $(ocaml_defn)
defn-java: $(java_defn)
defn-haskell: $(haskell_defn)

# Building
# --------

build: build-java
build-java: $(BUILD_DIR)/java/driver-kompiled/timestamp
build-ocaml: $(BUILD_DIR)/ocaml/driver-kompiled/timestamp

# Java Backend

$(BUILD_DIR)/java/driver-kompiled/timestamp: $(java_defn)
	@echo "== kompile: $@"
	$(K_BIN)/kompile --debug --main-module $(main_module) --backend java \
					--syntax-module $(main_module) $< --directory $(BUILD_DIR)/java -I $(BUILD_DIR)/java

# Ocaml Backend

$(BUILD_DIR)/ocaml/driver-kompiled/timestamp: $(ocaml_defn)
	@echo "== kompile: $@"
	eval $$(opam config env)                              \
	    $(K_BIN)/kompile -O3 --non-strict --backend ocaml \
	    --directory $(ocaml_dir) -I $(ocaml_dir)          \
	    --main-module   $(main_module)                    \
      --syntax-module $(syntax_module) $<
