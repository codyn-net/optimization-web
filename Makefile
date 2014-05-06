OUTDIR=generated
SYNCDIR=$(HOME)/public_html/optimization

process.timestamp: $(wildcard *.html) $(wildcard templates/*.html) $(wildcard static/*) $(wildcard static/styles/*) $(wildcard static/javascript/*) Makefile process.rb
	@mkdir -p $(OUTDIR); \
	ruby process.rb *.html -s static/ -f -o $(OUTDIR) || exit 1; \
	if [ ! -z "$(SYNCDIR)" ]; then \
		echo "Copying $(OUTDIR) to $(SYNCDIR)..."; \
		rm -rf $(SYNCDIR) && cp -r $(OUTDIR) $(SYNCDIR) || exit 1; \
	fi; \
	touch process.timestamp;

all: process.timestamp
