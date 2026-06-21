.PHONY: build test validate smoke clean

build:
	swift build

test:
	swift test

validate:
	./scripts/validate.sh

smoke:
	./scripts/smoke-release.sh

clean:
	swift package clean
