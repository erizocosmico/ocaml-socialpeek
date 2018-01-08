build:
	jbuilder build @install

pin:
	opam pin add . -y

repin: build
	opam upgrade socialpeek

test:
	jbuilder external-lib-deps --missing @runtest && jbuilder runtest

docs:
	jbuilder build @doc && \
	rm -rf docs && \
	mv _build/default/_doc docs

.PHONY: test build pin repin docs
