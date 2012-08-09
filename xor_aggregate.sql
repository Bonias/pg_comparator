-- $Id: xor_aggregate.sql 1141 2012-08-09 12:22:18Z fabien $
--
-- add XOR aggregate to PostgreSQL
--

-- default behavior for strict functions used: NULLs are ignored...

DROP AGGREGATE IF EXISTS XOR(bit);
CREATE AGGREGATE XOR(
  BASETYPE = BIT,
  SFUNC = bitxor,
  STYPE = BIT
);

DROP AGGREGATE IF EXISTS XOR(INT2);
CREATE AGGREGATE XOR(
  BASETYPE = INT2,
  SFUNC = int2xor,
  STYPE = INT2
);

DROP AGGREGATE IF EXISTS XOR(INT4);
CREATE AGGREGATE XOR(
  BASETYPE = INT4,
  SFUNC = int4xor,
  STYPE = INT4
);

DROP AGGREGATE IF EXISTS XOR(INT8);
CREATE AGGREGATE XOR(
  BASETYPE = INT8,
  SFUNC = int8xor,
  STYPE = INT8
);
