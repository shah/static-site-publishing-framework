#
# Static Site Publishing Framework (SSPF) Makefile

SHELL := /bin/bash
MAKEFLAGS := silent

SSPF_PROJECT_HOME ?= $(shell echo `pwd`)
SSPF_PROJECT_NAME ?= $(shell basename `pwd`)

SSPF_REPO_HOME         = shah/static-site-publishing-framework
SSPF_REPO_RAW_URL_HOME = https://raw.githubusercontent.com/$(SSPF_REPO_HOME)/master

SSPF_PROJECT_SSG_CONTENT_REL  ?= ssg-primary
SSPF_PROJECT_BIN_PATH         ?= $(SSPF_PROJECT_HOME)/bin
SSPF_PROJECT_LIB_PATH         ?= $(SSPF_PROJECT_HOME)/lib
SSPF_PROJECT_CONF_PATH        ?= $(SSPF_PROJECT_HOME)/etc
SSPF_PROJECT_SSG_CONTENT_PATH ?= $(SSPF_PROJECT_HOME)/$(SSPF_PROJECT_SSG_CONTENT_REL)
SSPF_PROJECT_TASKS_PATH       ?= $(SSPF_PROJECT_HOME)/tasks     

SSPF_PROJECT_PUBLISH_PATH ?= $(SSPF_PROJECT_HOME)/publication
SSPF_PROJECT_TMP_PATH     ?= $(SSPF_PROJECT_HOME)/tmp
SSPF_PROJECT_VENDOR_PATH  ?= $(SSPF_PROJECT_HOME)/vendor

SSPF_PROJECT_SERVER   ?= $(shell osqueryi --json "select * from interface_addresses where interface = 'eth0'" | jq --raw-output '.[0].address')
SSPF_PROJECT_HUGO     ?= $(SSPF_PROJECT_BIN_PATH)/hugo-0.54
SSPF_PROJECT_JSONNET  ?= $(SSPF_PROJECT_BIN_PATH)/jsonnet-v0.11.2
SSPF_PROJECT_PLANTUML ?= $(SSPF_PROJECT_BIN_PATH)/plantuml.1.2019.0.jar

SSPF_PROJECT_VENDOR_GOPATH        ?= $(SSPF_PROJECT_VENDOR_PATH)/go
SSPF_PROJECT_VENDOR_GO_SRC_PATH   := $(SSPF_PROJECT_VENDOR_PATH)/go/src
SSPF_PROJECT_VENDOR_GO_BIN_PATH   := $(SSPF_PROJECT_VENDOR_PATH)/go/bin
SSPF_PROJECT_GOLANG_HOME          ?= /usr/local/go
SSPF_PROJECT_GOLANG_DOWNLOAD_DEST ?= /opt/go
SSPF_PROJECT_GOLANG_BIN           ?= $(SSPF_PROJECT_GOLANG_HOME)/bin/go

SSPF_PROJECT_MAGE          ?= $(SSPF_PROJECT_VENDOR_GO_BIN_PATH)/mage
SSPF_PROJECT_MAGE_CACHE    ?= $(SSPF_PROJECT_TMP_PATH)/mage-cache

GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
REDFLASH  := $(shell tput -Txterm setaf 1)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# If install-golang target is run, this is the version of Google Go that will be installed
SSPF_PROJECT_GOLANG_INSTALL_VERSION ?= go1.11.5

# Find all PlantUML diagrams in the source and prepare list to generate the *.png versions
# Recursion tip: https://stackoverflow.com/questions/2483182/recursive-wildcards-in-gnu-make
SSPF_PROJECT_PUML_DIAGRAM_SOURCES = $(shell find $(SSPF_PROJECT_SSG_CONTENT_REL)/ -type f -name '*.diagram.puml')
SSPF_PROJECT_PUML_DIAGRAMS_PNG = $(patsubst $(SSPF_PROJECT_SSG_CONTENT_REL)/%.diagram.puml, $(SSPF_PROJECT_SSG_CONTENT_PATH)/static/img/generated/diagrams/%.diagram.png, $(SSPF_PROJECT_PUML_DIAGRAM_SOURCES))

default: devl

devl: generate-all
	cd $(SSPF_PROJECT_SSG_CONTENT_PATH) && \
		$(SSPF_PROJECT_HUGO) serve --bind $(SSPF_PROJECT_SERVER) --baseURL http://$(SSPF_PROJECT_SERVER) --disableFastRender

publish: generate-all
	rm -rf $(SSPF_PROJECT_PUBLISH_PATH)
	cd $(SSPF_PROJECT_SSG_CONTENT_PATH) && \
		$(SSPF_PROJECT_HUGO) --destination $(SSPF_PROJECT_PUBLISH_PATH) --minify

$(SSPF_PROJECT_SSG_CONTENT_PATH)/static/img/generated/diagrams/%.diagram.png: $(SSPF_PROJECT_SSG_CONTENT_REL)/%.diagram.puml
	echo "Generating diagram: $<"
	mkdir -p "$(@D)"
	java -jar $(SSPF_PROJECT_PLANTUML) -tpng -o "$(@D)" "$<"

## Delete all generated PlantUML diagrams
clean-generated-diagrams-puml.png:
	rm -rf $(SSPF_PROJECT_SSG_CONTENT_PATH)/static/img/generated

generate-all: $(SSPF_PROJECT_PUML_DIAGRAMS_PNG)

clean-generated-all: clean-generated-diagrams-puml.png

## Check to see if any dependencies are missing, suggest how to install them
doctor: check-dependencies setup-devl-env

check-dependencies: check-golang check-java check-jq check-osquery check-hugo check-mage check-jsonnet check-gitignore check-plantuml
	printf "$(GREEN)[*]$(RESET) "
	make -v | head -1
	echo "$(GREEN)[*]$(RESET) Shell: $$SHELL"

GITIGNORE_OK := $(shell grep '^tmp' .gitignore 2> /dev/null)
check-gitignore:
ifndef GITIGNORE_OK
	echo "$(REDFLASH)[ ]$(RESET) .gitignore doesn't contain 'tmp' directory, you should add it"
else
	echo "$(GREEN)[*]$(RESET) .gitignore appears to be OK"
endif

HUGO_INSTALLED := $(shell command -v $(SSPF_PROJECT_HUGO) 2> /dev/null)
check-hugo:
ifndef HUGO_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Hugo, set SSPF_PROJECT_HUGO environment variable."
endif
	printf "$(GREEN)[*]$(RESET) "
	$(SSPF_PROJECT_HUGO) version

MAGE_INSTALLED := $(shell command -v $(SSPF_PROJECT_MAGE) 2> /dev/null)
.ONESHELL:
check-mage:
ifndef MAGE_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Mage, building from source"
	export GOPATH=$(SSPF_PROJECT_VENDOR_GOPATH)
	$(SSPF_PROJECT_GOLANG_BIN) get -u -d github.com/magefile/mage
	cd $(SSPF_PROJECT_VENDOR_GOPATH)/src/github.com/magefile/mage
	PATH=$(SSPF_PROJECT_GOLANG_HOME):$$PATH $(SSPF_PROJECT_GOLANG_BIN) run bootstrap.go
endif
	printf "$(GREEN)[*]$(RESET) "
	$(SSPF_PROJECT_MAGE) -version | head -n 1

destroy-mage:
	export GOPATH=$(SSPF_PROJECT_VENDOR_GOPATH)
	rm -f $(SSPF_PROJECT_BIN_PATH)/mage
	rm -rf $(SSPF_PROJECT_VENDOR_GOPATH)/src/github.com/magefile/mage

JSONNET_INSTALLED := $(shell command -v $(SSPF_PROJECT_JSONNET) 2> /dev/null)
check-jsonnet:
ifndef JSONNET_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Jsonnet, set SSPF_PROJECT_JSONNET environment variable."
endif
	printf "$(GREEN)[*]$(RESET) "
	$(SSPF_PROJECT_JSONNET) --version

GOLANG_INSTALLED := $(shell command -v $(SSPF_PROJECT_GOLANG_BIN) 2> /dev/null)
check-golang:
ifndef GOLANG_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Google Go, needed for running Mage"
	echo "    Either check your PATH to make sure 'go' is available, or install it using:"
	echo "        make install-golang"
else
	printf "$(GREEN)[*]$(RESET) "
	$(SSPF_PROJECT_GOLANG_BIN) version
endif

JAVA_INSTALLED := $(shell command -v java 2> /dev/null)
check-java:
ifndef JAVA_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Oracle Java, needed for running PlantUML"
	echo "    Either check your JAVA_HOME/bin to make sure 'java' is available, or install it."
else
	printf "$(GREEN)[*]$(RESET) "
	java --version | head -n 1 
endif

GRAPHVIZ_DOT_INSTALLED := $(shell command -v dot 2> /dev/null)
check-graphviz-dot:
ifndef GRAPHVIZ_DOT_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find Graphviz Dot (for PlantUML), install it using:"
	echo "    sudo apt-get install graphviz"
else
	printf "$(GREEN)[*]$(RESET) "
	dot -V
endif

check-plantuml: check-graphviz-dot
	printf "$(GREEN)[*]$(RESET) "
	java -jar $(SSPF_PROJECT_PLANTUML) -version | head -n 1 

check-plantuml-is-latest:
	printf "$(GREEN)[*]$(RESET) "
	java -jar $(SSPF_PROJECT_PLANTUML) -checkversion 

JQ_INSTALLED := $(shell command -v jq 2> /dev/null)
check-jq:
ifndef JQ_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Did not find jq, install using:"
	echo "    sudo apt-get install jq"
else
	printf "$(GREEN)[*]$(RESET) "
	jq --version
endif

OSQUERY_INSTALLED := $(shell command -v osqueryi 2> /dev/null)
check-osquery: 
ifndef OSQUERY_INSTALLED
	echo "$(REDFLASH)[ ]$(RESET) Unable to find osquery, install it from https://osquery.io/downloads/official."
else
	printf "$(GREEN)[*]$(RESET) "
	osqueryd --version
	printf "$(GREEN)[*]$(RESET) "
	osqueryi --version
endif

.ONESHELL:
## Installs Google Go in /opt/go/goX.Y.Z and symlinks to /usr/local/go
install-golang:
	echo "Installing Google Go $(SSPF_PROJECT_GOLANG_INSTALL_VERSION) in $(SSPF_PROJECT_GOLANG_HOME), via $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)"
	cd /tmp
	wget https://dl.google.com/go/$(SSPF_PROJECT_GOLANG_INSTALL_VERSION).linux-amd64.tar.gz
	sudo mkdir -p $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)
	sudo tar xvf $(SSPF_PROJECT_GOLANG_INSTALL_VERSION).linux-amd64.tar.gz -C $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)
	echo "Downloaded Google Go $(SSPF_PROJECT_GOLANG_INSTALL_VERSION) in $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)"
	ls -al $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)
	echo "Convert unrevisioned $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)/go to $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)"
	sudo mv $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)/go $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)/$(SSPF_PROJECT_GOLANG_INSTALL_VERSION)
	ls -al $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)
	echo "Symlink revisioned $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)/$(SSPF_PROJECT_GOLANG_INSTALL_VERSION) to $(SSPF_PROJECT_GOLANG_HOME) as 'Global' instance"
	sudo rm -f $(SSPF_PROJECT_GOLANG_HOME)
	sudo ln -s $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)/$(SSPF_PROJECT_GOLANG_INSTALL_VERSION) /usr/local/go
	ls -al $(SSPF_PROJECT_GOLANG_HOME)

.ONESHELL:
## Removes Google Go packages from /opt/go and removes usr/local/go symlink
destroy-golang:
	echo "Removing $(SSPF_PROJECT_GOLANG_HOME) symlink"
	sudo rm -f $(SSPF_PROJECT_GOLANG_HOME)
	echo "Removing $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST) directory"
	sudo rm -rf $(SSPF_PROJECT_GOLANG_DOWNLOAD_DEST)

## Shows what environment variables developers should setup for the various tools needed by this Makefile
setup-devl-env:
	echo ""
	echo "$(WHITE)Make development more convenient, run these in your current shell:$(RESET)"
	echo "  export $(YELLOW)PATH$(RESET)=$(GREEN)\$$PATH:$(SSPF_PROJECT_GOLANG_HOME)/bin$(RESET)"
	echo "  export $(YELLOW)GOPATH$(RESET)=$(GREEN)$(SSPF_PROJECT_VENDOR_GOPATH)$(RESET)"
	echo "  export $(YELLOW)MAGEFILE_CACHE=$(GREEN)$(SSPF_PROJECT_MAGE_CACHE)$(RESET)"
	echo "  alias $(YELLOW)hugo$(RESET)=$(GREEN)$(SSPF_PROJECT_HUGO)$(RESET)"
	echo "  alias $(YELLOW)mage$(RESET)=$(GREEN)$(SSPF_PROJECT_MAGE)$(RESET)"
	echo "  alias $(YELLOW)jsonnet$(RESET)=$(GREEN)$(SSPF_PROJECT_JSONNET)$(RESET)"
	echo ""
	echo "Put your go source files into $(GREEN)$(SSPF_PROJECT_VENDOR_GO_SRC_PATH)$(RESET)"

## Shows how to setup an SSPF project on any machine with curl
setup-SSPF:
	echo "You can setup a new project using:"
	echo "  mkdir <project-name>"
	echo "  cd <project-name>"
	echo "  curl -s $(SSPF_REPO_RAW_URL_HOME)/bin/setup-SSPF.sh | bash"

## Upgrade to the latest version of the SSPF (from source)
upgrade-SSPF:
	curl -s $(SSPF_REPO_RAW_URL_HOME)/bin/setup-SSPF.sh | bash

TARGET_MAX_CHAR_NUM=15
# All targets should have a ## Help text above the target and they'll be automatically collected
# Show help, using auto generator from https://gist.github.com/prwhite/8168133
help:
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${WHITE}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
	echo $(SSPF_PROJECT_DIAGRAMS_GEN_PATH)

-include $(SSPF_PROJECT_BIN_PATH)/*.make.inc
-include $(SSPF_PROJECT_LIB_PATH)/*.make.inc
