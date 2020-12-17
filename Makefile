CWD := $(shell pwd)
NAME := $(shell jq -r .name META6.json)
VERSION := $(shell jq -r .version META6.json)
ARCHIVENAME := $(subst ::,-,$(NAME))

check:
	git diff-index --check HEAD
	prove6

tag:
	git tag $(VERSION)
	git push origin --tags

dist:
	git archive --prefix=$(ARCHIVENAME)-$(VERSION)/ \
		-o ../$(ARCHIVENAME)-$(VERSION).tar.gz $(VERSION)

test-alpine:
	docker run --rm -t -u root \
	  -e RELEASE_TESTING=1 \
	  -e PGUSER=postgres \
	  -v $(CWD):/test \
          --entrypoint="/bin/sh" \
	  jjmerelo/raku-test \
	  -c "apk add --update --no-cache postgresql libuuid && install -d -o postgres -g postgres -m 777 /var/lib/postgresql/data /run/postgresql && su - postgres -c 'initdb -D /var/lib/postgresql/data' && su - postgres -c 'pg_ctl start -D /var/lib/postgresql/data -l /var/lib/postgresql/log.log' && zef install epoll && cd /test && zef install --/test --deps-only --test-depends . && zef -v test ."

test: test-alpine
