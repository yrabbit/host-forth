MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --warn-undefined-variables


SHELL       := zsh
.ONESHELL:
# error on unset vars, exit on error in pipe commands
.SHELLFLAGS := -o nounset -e -c
.DELETE_ON_ERROR:

ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif
.RECIPEPREFIX = >

# dirs
OUTPUT              := .out
LIBDIR              := .out

CC := cc

# Flags
CFLAGS          := --std=gnu23 -O2 -Wall
CINC_APP        := -I./include -I/usr/local/include
CFLAGS_APP      := ${CFLAGS} ${CINC_APP}

LDFLAGS         := -L/usr/local/lib -lficl -lm

#####################################
# The project parts
APP_DIR            := .
APP_ELF            := host-forth
APP_SRC            := ${APP_DIR}/src
APP_INCLUDE        := ${APP_DIR}/include
APP_OUTPUT         := ${APP_DIR}/${OUTPUT}
APP_ELF_FILE       := ${APP_OUTPUT}/${APP_ELF}
APP_SENTINEL       := ${APP_OUTPUT}/.sentinel
APP_LINKMAP_FILE   := ${APP_OUTPUT}/linkmap.txt
APP_CFLAGS         := ${CFLAGS}
APP_LDFLAGS        := ${LDFLAGS}

#####################################
# Batch comiple. The parameters are:
# - the output path
# - list of C files
# - compiler options
#
# zsh/gnu-make magic to make the obj file name: {name%pattern}
# removes the pattern from the name, use $$ in order to pass the $ to zsh
# -o $(@D)/$${$$(basename $${src})%.c}.o
# ${CC} $(3) -fverbose-asm -S $${src} -o $(1)/$${$$(basename $${src})%.c}.o.S ;
define compile_c_files
    mkdir -p $(1)
    for src in $(2); do
        ${CC} $(3) -c $${src} -o $(1)/$${$$(basename $${src})%.c}.o ;
    done
endef

#####################################
#  Compile with options for external libs
#  The parameters:
#  - the output path
#  - list of C files
#  - inc flags
define compile_ext_lib
    $(call compile_c_files, $(1), $(2), ${CFLAGS_LIB} $(3))
endef

#####################################
#  Compile with options for the app files
#  including local libs
#  The parameters:
#  - the output path
#  - list of C files
#  - inc flags
define compile_app
    $(call compile_c_files, $(1), $(2), ${CFLAGS_APP} $(3))
endef

#####################################
all: app
.PHONY: all

clean:
>   find `pwd` -name ${OUTPUT} -exec rm -rf \{\} +

#####################################
# := static assigment
# = dynamic assigment
APP_C_FILES    := $(shell find ${APP_SRC} -name '*.c')
APP_H_DEPS     := $(shell find ${APP_INCLUDE} -name '*.h')
APP_O_FILES    = $(shell find ${APP_OUTPUT} -name '*.o')

${APP_SENTINEL}: ${APP_C_FILES} ${APP_H_DEPS}
>   $(call compile_app, $(@D), ${APP_C_FILES}, ${APP_CFLAGS})
>   touch $@

${APP_ELF_FILE}: ${APP_SENTINEL}
>   mkdir -p ${APP_OUTPUT}
>   ${CC} ${APP_CFLAGS} \
    ${APP_O_FILES} \
    ${APP_LDFLAGS} \
    -o $@

app:   ${APP_ELF_FILE}
.PHONY: app

# vim: expandtab: ts=4 sw=4 ft=yrmake:
