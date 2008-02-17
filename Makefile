# $Id: Makefile 421 2008-02-17 09:48:09Z fabien $

name		= pg_comparator

SCRIPTS_built	= $(name)
MODULES		= checksum casts
DATA_built	= checksum.sql casts.sql
DATA		= xor_aggregate.sql
DOCS		= README.$(name) \
			README.xor_aggregate \
			README.checksum

EXTRA_CLEAN	= $(name).1 $(name).html pod2htm?.tmp

PGXS	= $(shell pg_config --pgxs)
include $(PGXS)

# derived documentations
$(name): $(name).pl; cp $< $@
$(name).1: $(name); pod2man $< > $@
$(name).html: $(name); pod2html $< > $@

# distribution
dir		= $(name)
VERSION		= 1.4.2
dist_files 	= *.in *.c $(DOCS) $(DATA) \
	$(name) $(name.pl) INSTALL LICENSE Makefile

tar: $(name)-$(VERSION).tgz

script: $(name)

$(name)-$(VERSION).tgz: script
	cd .. ; \
	tar czf $(name)-$(VERSION).tgz $(addprefix $(dir)/, $(dist_files))

clean: local-clean
local-clean:; $(RM) *~
