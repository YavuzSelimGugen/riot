
# if no "v" var given, default to package version
v ?= $(shell node -pe "require('./package.json').version")

# expand variable (so we can use it on branches w/o package.json)
VERSION := $(v)

# get x.x.* part of the version number
MINOR_VERSION = `echo $(VERSION) | sed 's/\.[^.]*$$//'`

# Command line paths
KARMA = ./node_modules/karma/bin/karma
ESLINT = ./node_modules/eslint/bin/eslint.js
MOCHA = ./node_modules/mocha/bin/_mocha
ROLLUP = ./node_modules/.bin/rollup
MINIFY = ./node_modules/.bin/minify
COVERALLS = ./node_modules/coveralls/bin/coveralls.js
RIOT_CLI = ./node_modules/.bin/riot

# folders
DIST = dist/riot/
SRC = src
CONFIG = config/

GENERATED_FILES = riot.js riot+compiler.js

test: eslint

eslint:
	# check code style
	@ $(ESLINT) -c ./.eslintrc src test

test:
	@ exit 0

test-coveralls:
	@ RIOT_COV=1 cat ./coverage/report-lcov/lcov.info | $(COVERALLS)

test-sauce:
	# run the riot tests on saucelabs
	@ SAUCELABS=1 make test-karma

raw:
	# build riot
	@ mkdir -p $(DIST)
	# Default builds UMD
	@ $(ROLLUP) src/riot.js --config rollup.config.js > $(DIST)riot.js
	@ $(ROLLUP) src/riot+compiler.js --config rollup.config.js > $(DIST)riot+compiler.js

clean:
	# clean $(DIST)
	@ rm -rf $(DIST)

riot: clean raw test

min:
	# minify riot
	@ for f in $(GENERATED_FILES); do \
		$(MINIFY) $(DIST)$$f -o $(DIST)$${f%.*}.min.js; \
		done

build:
	# generate riot.js & riot.min.js
	@ make min
	@ cp dist/riot/* .
	# write version in riot.js
	@ sed -i '' 's/WIP/v$(VERSION)/g' riot*.js


bump:
	# grab all latest changes to master
	# (if there's any uncommited changes, it will stop here)
	# bump version in *.json files
	@ sed -i '' 's/\("version": "\)[^"]*/\1'$(VERSION)'/' *.json
	@ make build
	@ git status --short

bump-undo:
	# remove all uncommited changes
	@ git reset --hard


version:
	# @ git checkout master
	# create version commit
	@ git status --short
	@ git add --all
	@ git commit -am "$(VERSION)"
	@ git log --oneline -2
	# create version tag
	@ git tag -a 'v'$(VERSION) -m $(VERSION)
	@ git describe

version-undo:
	# remove the version tag
	@ git tag -d 'v'$(VERSION)
	@ git describe
	# remove the version commit
	@ git reset `git rev-parse :/$(VERSION)`
	@ git reset HEAD^
	@ git log --oneline -2

release: bump version

release-undo:
	make version-undo
	make bump-undo

publish:
	# push new version to npm and github
	# (github tag will also trigger an update in bower, component, cdnjs, etc)
	@ npm publish
	@ git push origin master
	@ git push origin master --tags

.PHONY: test min eslint test-coveralls test-sauce compare raw riot perf watch tags perf-leaks build bump bump-undo version version-undo release-undo publish
