#
# $Id: test.mk 1567 2017-07-06 14:55:40Z coelho $
#
# run pg_comparator validation checks
#
# See file "auth.mk" for defining macros:
#   auth1 (pgsql), auth2 (mysql), auth3 (sqlite), auth4/fdb (firebird)
#
# Run: sh> make validate_...
#   where ...=sanity|fast|hour|full|...
#
# having that as a makefile is moderately justified.

SHELL	= /bin/bash

# set default auth*
-include auth.mk

# rough testing, including synchronization
AUTH	= localhost
DB	= test

# test case generation
ROWS	= 100
TOTAL	= 8
KEYS	= 0
COLS	= 2
WIDTH	= 1

# default algorithm parameters for run
FOLD	= 3
NULL	= text
AGG	= sum
CF	= ck
CS	= 8

# other options
#ENGINE	= INNODB ## MUCH TOO SLOW!
ENGINE	= MYISAM
# for external use
PGCOPTS	=
# for internal use by this makefile
pgcopts	=

# table names: must be foo1 & foo2 anyway, but may add quoting for tests
tab1	= foo1
tab2	= foo2

# generate column names
coln	:= $(shell n=$(COLS); while let n--; do echo $$n; done)
col1	:= $(shell echo $(addprefix a,$(coln))|tr ' ' ',')
col2	:= $(shell echo $(addprefix b,$(coln))|tr ' ' ',')

keyn	:= $(shell n=$(KEYS); while let n--; do echo $$n; done)
key1	:= $(shell echo id $(addprefix k,$(keyn))|tr ' ' ',')
key2	:= $(shell echo id $(addprefix l,$(keyn))|tr ' ' ',')

# use common default
AUTH1	= $(AUTH)
AUTH2	= $(AUTH)

# database could be different
DB1	= $(DB)
DB2	= $(DB)

# connections
CONN1	= $(AUTH1)/$(DB1)/$(tab1)?$(key1):$(col1)
CONN2	= $(AUTH2)/$(DB2)/$(tab2)?$(key2):$(col2)

# pre/post comparison settings
PG_PRE	= :
PG_POST	= :

# can be overriden for some tests
xor	= xor
sum	= sum
md5	= md5
ck	= ck
fnv	= fnv
hash	= hash
text	= text

#
# test case generation for pg_comparator
#
# Create, Modify, Keep
RUNOPS	= -C -M -K
# other create options
# -D: debug
# -s seed
crtopts =
CRTOPTS	=

LOG	= .log

#
# test generation, then comparison & synchronization & check
#
# make AUTH=calvin:hobbes@home DB=calvin COLS=0 ROWS=1000 run
.PHONY: run
run: pg_comparator
	@echo run 1=$(AUTH1) 2=$(AUTH2) $(KEYS)+$(COLS) $(ROWS)x$(WIDTH) \
	  $(TOTAL) $(FOLD) $(CF) $(AGG) $(CS) $(NULL) $(pgcopts) $(PGCOPTS) \
	  >> $(LOG)
	./test_pg_comparator.sh \
	  -1 $(AUTH1) -2 $(AUTH2) -b1 $(DB1) -b2 $(DB2) \
	  -k $(KEYS) -c $(COLS) -r $(ROWS) -w $(WIDTH) \
	  -t $(TOTAL) -e $(ENGINE) $(RUNOPS) $(crtopts) $(CRTOPTS)
	$(PG_PRE)
	time ./pg_comparator -f $(FOLD) --cf=$(CF) -a $(AGG) --cs=$(CS) \
	    --null=$(NULL) -e $(TOTAL) --no-report $(pgcopts) $(PGCOPTS) \
		'$(CONN1)' '$(CONN2)'
	time ./pg_comparator -S -D -f $(FOLD) --cf=$(CF) -a $(AGG) --cs=$(CS) \
	    --null=$(NULL) -e $(TOTAL) --no-report $(pgcopts) $(PGCOPTS) \
		'$(CONN1)' '$(CONN2)'
	time ./pg_comparator -f $(FOLD) --cf=$(CF) -a $(AGG) --cs=$(CS) \
	    --null=$(NULL) -e 0 --no-report $(pgcopts) $(PGCOPTS) \
		'$(CONN1)' '$(CONN2)'
	$(PG_POST)

.PHONY: clean-test
clean: clean-test
clean-test:
	$(RM) $(LOG)

########################################################################## FULL
#
# "FULL" COMBINATORIAL VALIDATION
#
# test additionnal key & other columns
# there is always a simple primary key
.PHONY: full_cases
full_cases:
	$(MAKE) KEYS=0 COLS=0 run
	$(MAKE) KEYS=0 COLS=1 run
	$(MAKE) KEYS=0 COLS=2 run
	$(MAKE) KEYS=1 COLS=0 run
	$(MAKE) KEYS=1 COLS=1 run
	$(MAKE) KEYS=1 COLS=2 run
	$(MAKE) KEYS=2 COLS=3 run

# folding log2: fold by 2, 4, 8, 128
.PHONY: full_foldings
full_foldings:
	$(MAKE) FOLD=1 full_cases
	$(MAKE) FOLD=2 full_cases
	$(MAKE) FOLD=7 full_cases

# full checksum sizes
.PHONY: full_cs
full_cs:
	$(MAKE) CS=4 full_foldings
	$(MAKE) CS=8 full_foldings

# full checksum functions
.PHONY: full_cf
full_cf:
	$(MAKE) CF=md5 full_cs
	$(MAKE) CF=ck full_cs
	$(MAKE) CF=fnv full_cs

# full null handling
.PHONY: full_null
full_null:
	$(MAKE) NULL=text full_cf
	$(MAKE) NULL=hash full_cf

# full checksum aggregate functions
.PHONY: full_agg
full_agg:
	$(MAKE) AGG=sum full_null
	[ $(xor) = 'xor' ] && $(MAKE) AGG=xor full_null || exit 0

# full table sizes
.PHONY: full_sizes
full_sizes:
	$(MAKE) ROWS=20 full_agg
	$(MAKE) ROWS=1026 full_agg

# start full tests
.PHONY: full_pg full_my full_mix
full_pg: full_sizes
full_my: full_sizes
full_mix: full_sizes

########################################################################## FAST
#
# FAST TESTS: 12 tests, just a subset of combinations
# run is 3 calls to pg_comparator: compare, sync, check sync
# xor tests are skipped when databases are mixed.
# also tests some options here and there...
#
.PHONY: fast
fast:
	$(MAKE) CF=$(md5) CS=8 AGG=$(sum) NULL=$(text) FOLD=1 KEYS=0 COLS=0 run
	$(MAKE) CF=$(ck)  CS=8 AGG=$(sum) NULL=$(text) FOLD=2 KEYS=0 COLS=1 pgcopts+=' -u' run
	$(MAKE) CF=$(md5) CS=8 AGG=$(xor) NULL=$(hash) FOLD=1 KEYS=0 COLS=1 run
	$(MAKE) CF=$(md5) CS=8 AGG=$(sum) NULL=$(text) FOLD=1 KEYS=1 COLS=2 pgcopts+=' --max-levels=3' run
	$(MAKE) CF=$(fnv) CS=4 AGG=$(sum) NULL=$(hash) FOLD=3 KEYS=0 COLS=2 pgcopts+=' --lock' run
	$(MAKE) CF=$(ck)  CS=8 AGG=$(sum) NULL=$(text) FOLD=2 KEYS=0 COLS=1 pgcopts+=' --cc=insert' run
	$(MAKE) CF=$(ck)  CS=4 AGG=$(sum) NULL=$(hash) FOLD=4 KEYS=1 COLS=0 pgcopts+=' --no-lock' run
	$(MAKE) CF=$(ck)  CS=8 AGG=$(sum) NULL=$(hash) FOLD=4 KEYS=1 COLS=3 pgcopts+=' --size=$(ROWS)' run
	$(MAKE) CF=$(md5) CS=8 AGG=$(xor) NULL=$(text) FOLD=5 KEYS=1 COLS=1 pgcopts+=' --cc=insert' run
	$(MAKE) CF=$(ck)  CS=4 AGG=$(xor) NULL=$(hash) FOLD=7 KEYS=2 COLS=3 pgcopts+=' --no-temporary --unlogged --cleanup' run
	$(MAKE) CF=$(ck)  CS=8 AGG=$(xor) NULL=$(text) FOLD=6 KEYS=1 COLS=2 pgcopts+=' --no-temporary --cleanup' run
	$(MAKE) CF=$(ck)  CS=8 AGG=$(xor) NULL=$(hash) FOLD=8 KEYS=2 COLS=3 run

# this is scripted rather than relying on dependencies
# so that error messages are clearer
.PHONY: fast_pg fast_my fast_mix fast_lite fast_firebird
fast_pg: fast
fast_my: fast
fast_mix: xor=sum
fast_mix: fast
fast_lite: fast
fast_firebird: md5=ck
fast_firebird: fast

######################################################################## SANITY
#
# very quick validation: 3*(2+4+4) = 30 runs
#
.PHONY: sanity
# default KEYS=0 COLS=1
sanity:
	$(MAKE) CF=ck AGG=sum NULL=text FOLD=2 run

.PHONY: sanity_pg sanity_my sanity_mix sanity_lite
sanity_pg: sanity
sanity_my: sanity
sanity_mix: sanity
sanity_lite: sanity

#################################################################### VALIDATION
#
# see also feature & release validations
#
# the validation tests all working asynchronous/thread combinations
#

# default
VALIDATE=sanity

.PHONY: check_validation_environment
check_validation_environment: pg_comparator
	perl -c ./pg_comparator
	[[ "$(VALIDATE)" ]] || exit 1
	[[ "$(auth1)" == pgsql://* ]] || exit 2 ; \
	[[ "$(auth2)" == mysql://* ]] || exit 3 ; \
	[[ "$(auth3)" == sqlite://* ]] || exit 4

# threads never worked with pgsql (try with -T --debug)
.PHONY: validate_pg
validate_pg: check_validation_environment
	@echo "# $@ $(VALIDATE) start"
	$(MAKE) AUTH1=$(auth1) AUTH2=$(auth1) pgcopts+=' -X -N' $(VALIDATE)_pg
	$(MAKE) AUTH1=$(auth1) AUTH2=$(auth1) pgcopts+=' -A -N' $(VALIDATE)_pg
	@echo "# $@ $(VALIDATE) done"

.PHONY: validate_my
validate_my: check_validation_environment
	@echo "# $@ $(VALIDATE) start"
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth2) pgcopts+=' -X -N' $(VALIDATE)_my
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth2) pgcopts+=' -A -N' $(VALIDATE)_my
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth2) pgcopts+=' -X -T' $(VALIDATE)_my
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth2) pgcopts+=' -A -T' $(VALIDATE)_my
	@echo "# $@ $(VALIDATE) done"

.PHONY: validate_mix
validate_mix: check_validation_environment
	@echo "# $@ $(VALIDATE) start"
	$(MAKE) AUTH1=$(auth1) AUTH2=$(auth2) pgcopts+=' -X -N' $(VALIDATE)_mix
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth1) pgcopts+=' -X -N' $(VALIDATE)_mix
	$(MAKE) AUTH1=$(auth1) AUTH2=$(auth2) pgcopts+=' -A -N' $(VALIDATE)_mix
	$(MAKE) AUTH1=$(auth2) AUTH2=$(auth1) pgcopts+=' -A -N' $(VALIDATE)_mix
	@echo "# $@ $(VALIDATE) done"

.PHONY: validate
validate: check_validation_environment
	@echo "# $@ $(VALIDATE) start"
	$(MAKE) validate_pg && \
	$(MAKE) validate_my && \
	$(MAKE) validate_mix ; \
	echo "# $@ $(VALIDATE) done in $$SECONDS seconds"
	@echo "# $@ $(VALIDATE) done"

########################################################### STANDARD VALIDATION

# 3*10 runs, about 30 seconds.
.PHONY: validate_sanity
validate_sanity:
	@echo "# $@ start"
	$(MAKE) VALIDATE=sanity validate
	@echo "# $@ done"

# fast validation is 300 runs, on Ankh:
# - TOTAL=9 ROWS=10 ~ 4 minutes
# - TOTAL=8 ROWS=100 ~ 5.5 minutes
# - TOTAL=80 ROWS=100 ~ 5 minutes
# - TOTAL=99 ROWS=100 ~ 5 minutes
# - TOTAL=8 ROWS=1000 ~ 6.5 minutes
# - TOTAL=999 ROWS=1000 ~ 7 minutes
# - TOTAL=8 ROWS=10000 ~ 10 minutes
# - TOTAL=100 ROWS=10000 ~ 10 minutes
# - TOTAL=500 ROWS=10000 ~ 11 minutes
#    pg: 3 * 12 * 2
#    my: 3 * 12 * 4 # hmmm, seems slow...
#   mix: 3 * 12 * 4
# total: 72 + 144 + 144 = 360
.PHONY: validate_fast
validate_fast:
	@echo "# $@ start"
	$(MAKE) VALIDATE=fast validate
	@echo "# $@ done"

# 8*300 = 2400 tests, about 60 minutes on Ankh
# default validate_fast is TOTAL=8 ROWS=100 so it is not included
.PHONY: validate_hour
validate_hour:
	@echo "# $@ start"
	$(MAKE) TOTAL=9    ROWS=10    validate_fast # 4
	$(MAKE) TOTAL=4    ROWS=100   pgcopts+=' --where "id>20"' validate_fast
	$(MAKE) TOTAL=8    ROWS=1000  validate_fast # 7
	$(MAKE) TOTAL=100  ROWS=1000  validate_fast # 7
	$(MAKE) TOTAL=999  ROWS=1000  validate_fast # 7
	$(MAKE) TOTAL=8    ROWS=10000 validate_fast # 10
	$(MAKE) TOTAL=100  ROWS=10000 validate_fast # 11
	$(MAKE) TOTAL=1000 ROWS=10000 validate_fast # 12
	@echo "# $@ done"

# full validate: 16128 tests, at least 5 hours?
#    pg: 3 * (7*3*2*2*2*2*2) * 2   = 3 * 672 * 2 = 4032
#    my: 3 * ~               * 4   = 8064
#   mix: 3 * ~      1        * 2*2 = 4032
# total: 16128
.PHONY: validate_full
validate_full:
	@echo "# $@ start"
	$(MAKE) VALIDATE=full validate
	@echo "# $@ done"

############################################################ FEATURE VALIDATION

# tests some options without setting rows
# 60+18+90+3 = 171
# 18+36+36+36+24+96+60 = 306
.PHONY: validate_feature
validate_feature:
	@echo "# $@ ROWS=$(ROWS) start"
	$(MAKE) validate_cc
	$(MAKE) validate_auto # pgsql only
	$(MAKE) validate_empty
	$(MAKE) validate_pgcopy # pgsql only
	[ $(ROWS) = 10 ] && $(MAKE) validate_quote || exit 0
	[ $(ROWS) = 10 ] && $(MAKE) validate_sqlite || exit 0 # sqlite only
	[ $(ROWS) = 10 ] && $(MAKE) validate_mylite || exit 0 # partial
	[ $(ROWS) = 10 ] && $(MAKE) validate_pglite || exit 0 # partial
	[ $(ROWS) = 10 ] && $(MAKE) validate_engine || exit 0 # mysql only
	[ $(ROWS) = 10 ] && $(MAKE) validate_width || exit 0
	[ $(ROWS) = 10 ] && $(MAKE) validate_nullkey || exit 0
	@echo "# $@ done"

# validate how to create the initial checksum table
# 3*10*2 = 60 runs
.PHONY: validate_cc
validate_cc:
	@echo "# $@ start"
	$(MAKE) pgcopts+=' --cc=create' validate
	$(MAKE) pgcopts+=' --cc=insert' validate
	@echo "# $@ done"

# validate pre-computed checksums
# the settings must be consistent between pg_comparator & rand_table
# the test is only with PostgreSQL for which triggers are easy for me.
# 3*2*3 = 18 runs
.PHONY: validate_auto
validate_auto: VALIDATE=sanity
validate_auto:
	@echo "# $@ start"
	$(MAKE) KEYS=0 COLS=0 \
	  pgcopts+=' --tcs=id --use-key' \
	  validate_pg
	$(MAKE) KEYS=0 COLS=1 \
	  crtopts+=' --tt --nn' \
	  pgcopts+=' --tcs=tup_cs --use-key' \
	  validate_pg
	$(MAKE) KEYS=1 COLS=2 \
	  crtopts+=' --tt --kt --nn' \
	  pgcopts+=' --tcs=tup_cs --kcs=key_cs' \
	  validate_pg
	@echo "# $@ done"

# what if some tables are empty?
# 3*10*3 = 90 runs
.PHONY: validate_empty
validate_empty:
	@echo "# $@ start"
	$(MAKE) crtopts+=' --e1 --e2' TOTAL=0       validate
	$(MAKE) crtopts+=' --e1'      TOTAL=$(ROWS) validate
	$(MAKE) crtopts+=' --e2'      TOTAL=$(ROWS) validate
	@echo "# $@ done"

# pgcopy option
.PHONY: validate_pgcopy
validate_pgcopy:
	@echo "# $@ start"
	$(MAKE) AUTH1=$(auth1) AUTH2=$(auth1) \
	  pgcopts+='--pg-copy --no-async' sanity_pg
	@echo "# $@ done"

# some options may not work as expected depending on the engine...
# very small because INNODB table creation is very slow
# despite the surrounding transaction
# 3*4*2 = 24 runs
.PHONY: validate_engine
validate_engine:
	@echo "# $@ start"
	$(MAKE) ENGINE='INNODB' KEYS=2 COLS=2 ROWS=10 validate_my
	$(MAKE) ENGINE='MYISAM' KEYS=2 COLS=2 ROWS=10 validate_my
	@echo "# $@ done"

# try large columns
#$(MAKE) KEYS=1 COLS=1 WIDTH=10000 ROWS=10 validate_pg # broken?
# 3*10*3 + 3*2*1 = 96 runs
.PHONY: validate_width
validate_width:
	@echo "# $@ start"
	$(MAKE)        WIDTH=100    ROWS=10 validate
	$(MAKE) COLS=3 WIDTH=1000   ROWS=10 validate
	$(MAKE) COLS=1 WIDTH=3500   ROWS=10 validate # max 65KB for MySQL TEXT
	$(MAKE) COLS=2 WIDTH=100000 ROWS=10 validate_pg
	@echo "# $@ done"

# validate with a nullable key
# 3*10*2 = 60 runs
.PHONY: validate_nullkey
validate_nullkey:
	@echo "# $@ start"
	$(MAKE) crtopts+=' --null-key' KEYS=0 COLS=1 ROWS=10 validate
	$(MAKE) crtopts+=' --null-key' KEYS=1 COLS=2 ROWS=10 validate
	@echo "# $@ done"

# validate with a quoted table names
# ??? should also test column names?
# 3*2*3 = 18 runs
.PHONY: validate_quote
validate_quote:
	@echo "# $@ start"
	$(MAKE) tab1=\"foo1\" tab2=public.\"foo2\"     ROWS=10 validate_pg
	$(MAKE) tab1=\"foo1\" tab2=\"public\".\"foo2\" ROWS=10 validate_pg
	$(MAKE) tab1=\`foo1\` tab2=\`foo2\`            ROWS=10 validate_my
	@echo "# $@ done"

# basic test with sqlite3
# note: ROWS=500 => too many terms in compound SELECT statement,
#       because of the many INSERT values.
# 12*3 = 36 runs
.PHONY: validate_sqlite
validate_sqlite:
	@echo "# $@ start"
	PGC_SQLITE_LOAD_EXTENSION=/usr/local/lib/sqlite_checksum.so \
	  $(MAKE) AUTH1=$(auth3) AUTH2=$(auth3) DB=base.db ROWS=10 fast_lite
	@echo "# $@ done"

# basic test with firebird, not included in feature
# 12*3 = 36 runs
.PHONY: validate_firebird
validate_firebird:
	@echo "# $@ start"
	$(MAKE) AUTH1=$(auth4) AUTH2=$(auth4) DB=$(fdb) ROWS=10 fast_firebird
	@echo "# $@ done"

# sqlite/mysql
# 12*3 = 36 runs
.PHONY: validate_mylite
validate_mylite:
	@echo "# $@ start"
	PGC_SQLITE_LOAD_EXTENSION=/usr/local/lib/sqlite_checksum.so \
	  $(MAKE) AUTH1=$(auth2) AUTH2=$(auth3) \
	    DB1=test DB2=base.db ROWS=10 fast_lite
	PGC_SQLITE_LOAD_EXTENSION=/usr/local/lib/sqlite_checksum.so \
	  $(MAKE) AUTH2=$(auth2) AUTH1=$(auth3) \
	    DB2=test DB1=base.db ROWS=10 fast_lite
	@echo "# $@ done"

# sqlite/pgsql
# 12*3 = 36 runs
.PHONY: validate_pglite
validate_pglite:
	@echo "# $@ start"
	PGC_SQLITE_LOAD_EXTENSION=/usr/local/lib/sqlite_checksum.so \
	  $(MAKE) AUTH1=$(auth1) AUTH2=$(auth3) \
	    DB1=test DB2=base.db ROWS=10 fast_lite
	PGC_SQLITE_LOAD_EXTENSION=/usr/local/lib/sqlite_checksum.so \
	  $(MAKE) AUTH2=$(auth1) AUTH1=$(auth3) \
	    DB2=test DB1=base.db ROWS=10 fast_lite
	@echo "# $@ done"

####################################################################### RELEASE

# try collisions with small 2-byte (65536 values) checksum
# the first one may fail.
# the second one very likely fails.
# this is because some diffs are in collisions so they cannot be detected,
# this the --expect option fails, hence the --expect-warn option.
# 8 runs in about 6 minutes
.PHONY: validate_collisions
validate_collisions:
	@echo "# $@ start"
	./test_collision.sh $(auth1) $(DB)
	$(MAKE) KEYS=1 COLS=1 CS=2 ROWS=100000 validate_pg
	$(MAKE) KEYS=1 COLS=1 CS=2 TOTAL=90000 ROWS=100000 \
	  PGCOPTS+='--expect-warn' validate_pg
	@echo "# $@ done"

# about 20 minutes
# ROWS=10: high change rate (80%)
# ROWS=100: medium change rate (8%)
# ROWS=1000: low change rate (<1%)
# 402+168+360+8 = 938
.PHONY: validate_release
validate_release:
	@echo "# $@ start"
	$(MAKE) ROWS=10   validate_feature    && \
	$(MAKE) ROWS=1000 validate_feature    && \
	$(MAKE)           validate_fast       && \
	$(MAKE)           validate_collisions && \
	echo "# $@ done in $$SECONDS seconds"
	@echo "# $@ done"

################################################################### PERFORMANCE
#
.PHONY: performance
performance:
	$(MAKE) CF=ck CS=8 AGG=sum NULL=text pgcopts+=' --stats -u' \
		ROWS=500000 KEYS=0 COLS=4 FOLD=7 WIDTH=1 run

.PHONY: performance_mix
performance_mix: check_validation_environment
	$(MAKE) AUTH1=$(AUTH1) AUTH2=$(AUTH1) performance
	$(MAKE) AUTH1=$(AUTH1) AUTH2=$(AUTH2) performance
	$(MAKE) AUTH1=$(AUTH2) AUTH2=$(AUTH1) performance
	$(MAKE) AUTH1=$(AUTH2) AUTH2=$(AUTH2) performance
