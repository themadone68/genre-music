TEST_FILES = t/*.t
SCSS=scss
SCSSFLAGS=--style compressed -I. -Ibootstrap-sass/assets/stylesheets
CSS=css/style.css
PERL=/usr/bin/perl
PERLLIBS=-Ilib

.SUFFIXES: .css .scss

all: $(CSS)

tests: $(TEST_FILES)
	$(PERL) -Tw $(PERLLIBS) $(TEST_FILES)

%.css: %.scss
	$(SCSS) $(SCSSFLAGS) $< $@

css/style.css: css/style.scss Makefile
