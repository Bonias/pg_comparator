# $Id: Makefile 1128 2012-08-08 07:53:42Z fabien $

#
# PostgreSQL stuff
#

name		= pg_comparator

SCRIPTS		= $(name)
MODULES		= pgc_checksum pgc_casts
DATA_built	= $(MODULES:%=%.sql)
DATA		= xor_aggregate.sql
DOCS		= README.$(name) \
		  README.xor_aggregate \
		  README.checksum

EXTRA_CLEAN	= $(name).1 $(name).html pod2htm?.tmp

# get postgresql extension infrastructure
PG_CONFIG	= pg_config
PGXS	:= $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# derive documentation
$(name).1: $(name); pod2man --name $(name) $< > $@
$(name).html: $(name); pod2html --title $(name) $< > $@

pgsql_install: install
pgsql_uninstall: uninstall

#
# MySQL stuff
#
MY.c	= $(wildcard mysql_*.c)
MY.so	= $(MY.c:%.c=%.so)
MY.sql	= $(MY.c:%.c=%.sql)

MY_CONFIG	= mysql_config
MYDIR	= $(shell $(MY_CONFIG) --plugindir)/
MYCC	= $(CC) $(shell $(MY_CONFIG) --cflags)

mysql_%.so: mysql_%.c
	$(MYCC) -shared -o $@ $<
	chmod a+r-x $@

mysql_install: $(MY.so) $(MY.sql)
	chmod a+r $(MY.sql)
	cp -a $^ $(MYDIR)

mysql_uninstall:
	$(RM) $(addprefix $(MYDIR),$(MY.so) $(MY.sql))

#
# common cleanup
#
clean: local-clean
local-clean:
	$(RM) *.so

#
# development stuff is ignored by the distribution
#
-include dev.mk
