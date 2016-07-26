TEST_FILES = t/*.t
SCSS=scss
SCSSFLAGS=--style compressed -I. -Ibootstrap-sass/assets/stylesheets
CSS=css/style.css
PERL=/usr/bin/perl
PERLLIBS=-Ilib

.SUFFIXES: .css .scss .t
.PHONY: tests

all: $(CSS)

tests: $(TEST_FILES)
	@for X in $(TEST_FILES); do \
	  $(PERL) -Tw $(PERLLIBS) $$X; \
	done

%.css: %.scss
	$(SCSS) $(SCSSFLAGS) $< $@

css/style.css: css/style.scss Makefile
