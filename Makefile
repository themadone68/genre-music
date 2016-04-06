SCSS=scss
SCSSFLAGS=--style compressed -I. -Ibootstrap-sass/assets/stylesheets
CSS=css/style.css

.SUFFIXES: .css .scss

all: $(CSS)

%.css: %.scss
	$(SCSS) $(SCSSFLAGS) $< $@

css/style.css: css/style.scss Makefile
