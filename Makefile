.PHONY: all generate

all: generate test

generate:
	./generate.py

test:
	nix-shell -p python3Packages.flake8 --run 'flake8 ./*.py'
