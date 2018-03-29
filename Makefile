# Makefile for building and running the project.
# The purpose of this Makefile is to avoid developers having to remember
# project-specific commands for building, running, etc.  Recipes longer
# than one or two lines should live in script files of their own in the
# bin/ directory.

# TODO - have sample env config and copy over

all: check

setup:
	mix deps.get

.env: setup

check: lint test

lint:
	mix format

run:
	mix phx.server

test: .env $(CONFIG)
	mix test
