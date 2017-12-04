build:
	jbuilder build @install

pin:
	opam pin add . -y

repin: build
	opam upgrade socialpeek

test:
	jbuilder runtest

.PHONY: test build pin repin
