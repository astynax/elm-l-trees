docs/index.html: src/Main.elm elm.json
	elm make --optimize --output=$@ $<

.PHONY: test
test:
	pnpm exec -- elm-test src/Main.elm
