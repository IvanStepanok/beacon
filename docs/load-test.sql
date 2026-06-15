\timing on
\set ON_ERROR_STOP on
SET maintenance_work_mem = '256MB';

\echo '==================================================================='
\echo 'BEACON LOAD TEST — 500k reports, partitioned (LIST by crisis_id) vs flat'
\echo 'Mirrors production reports columns + indexes. Indexes built AFTER bulk load.'
\echo '==================================================================='

CREATE EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS reports_p CASCADE;
CREATE TABLE reports_p (
    id           text NOT NULL,
    crisis_id    text NOT NULL,
    damage       text NOT NULL,
    verification text NOT NULL,
    lat          double precision NOT NULL,
    lng          double precision NOT NULL,
    geom         geometry(Point,4326) NOT NULL,
    building_id  text,
    captured_at  timestamptz NOT NULL,
    place        text NOT NULL,
    PRIMARY KEY (crisis_id, id)
) PARTITION BY LIST (crisis_id);
CREATE TABLE reports_p_big      PARTITION OF reports_p FOR VALUES IN ('crisis-big');
CREATE TABLE reports_p_b        PARTITION OF reports_p FOR VALUES IN ('crisis-b');
CREATE TABLE reports_p_c        PARTITION OF reports_p FOR VALUES IN ('crisis-c');
CREATE TABLE reports_p_default  PARTITION OF reports_p DEFAULT;

DROP TABLE IF EXISTS reports_np CASCADE;
CREATE TABLE reports_np (LIKE reports_p);

\echo '--- Seeding 500,000 reports into crisis-big in 5 chunks (no indexes yet) ---'
DO $$
DECLARE k int;
BEGIN
  FOR k IN 0..4 LOOP
    INSERT INTO reports_p (id, crisis_id, damage, verification, lat, lng, geom, building_id, captured_at, place)
    SELECT 'rbig-'||(k*100000+g),
           'crisis-big',
           (ARRAY['none','slight','moderate','severe','destroyed'])[1+floor(random()*5)],
           (ARRAY['pending','verified','flagged'])[1+floor(random()*3)],
           lat, lng, ST_SetSRID(ST_MakePoint(lng,lat),4326),
           'b-'||floor(random()*200000),
           now() - (random()*interval '14 days'),
           'Area '||floor(random()*60)
    FROM (SELECT g, 36.0+random()*0.6 AS lat, 36.0+random()*0.6 AS lng FROM generate_series(1,100000) g) s;
  END LOOP;
END $$;

INSERT INTO reports_p (id, crisis_id, damage, verification, lat, lng, geom, building_id, captured_at, place)
SELECT 'rb-'||g, (ARRAY['crisis-b','crisis-c'])[1+floor(random()*2)],
       (ARRAY['none','slight','moderate','severe','destroyed'])[1+floor(random()*5)],
       (ARRAY['pending','verified','flagged'])[1+floor(random()*3)],
       lat, lng, ST_SetSRID(ST_MakePoint(lng,lat),4326),
       'b-'||floor(random()*20000), now() - (random()*interval '14 days'), 'Area '||floor(random()*30)
FROM (SELECT g, 40.0+random()*0.5 AS lat, 28.0+random()*0.5 AS lng FROM generate_series(1,25000) g) s;

\echo '--- Mirroring into the flat table ---'
INSERT INTO reports_np SELECT * FROM reports_p;

\echo '--- Building indexes AFTER load (both tables) ---'
CREATE INDEX ON reports_p  USING gist (geom);
CREATE INDEX ON reports_p  (crisis_id, captured_at DESC);
CREATE INDEX ON reports_p  (building_id, captured_at DESC);
CREATE INDEX ON reports_p  (crisis_id, damage);
CREATE INDEX ON reports_np USING gist (geom);
CREATE INDEX ON reports_np (crisis_id, captured_at DESC);
CREATE INDEX ON reports_np (building_id, captured_at DESC);
CREATE INDEX ON reports_np (crisis_id, damage);
ANALYZE reports_p;
ANALYZE reports_np;

\echo '--- Row counts ---'
SELECT 'reports_p_big' AS t, count(*) FROM reports_p_big
UNION ALL SELECT 'reports_p_b', count(*) FROM reports_p_b
UNION ALL SELECT 'reports_p_c', count(*) FROM reports_p_c
UNION ALL SELECT 'flat reports_np', count(*) FROM reports_np;

\echo '====== Q1 crisis-scoped map bbox — PARTITIONED (expect 1 partition) ======'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT count(*) FROM reports_p WHERE crisis_id='crisis-big' AND geom && ST_MakeEnvelope(36.20,36.20,36.30,36.30,4326);
\echo '------ Q1 FLAT (for comparison) ------'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT count(*) FROM reports_np WHERE crisis_id='crisis-big' AND geom && ST_MakeEnvelope(36.20,36.20,36.30,36.30,4326);

\echo '====== Q2 latest-per-building in crisis bbox — PARTITIONED (map pins) ======'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM (
  SELECT id, row_number() OVER (PARTITION BY building_id ORDER BY captured_at DESC, id DESC) rn
  FROM reports_p WHERE crisis_id='crisis-big' AND geom && ST_MakeEnvelope(36.20,36.20,36.25,36.25,4326)
) q WHERE rn=1;

\echo '====== Q3 stats aggregate (damage breakdown) — PARTITIONED ======'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT damage, count(*) FROM reports_p WHERE crisis_id='crisis-big' GROUP BY damage;

\echo '====== Q4 keyset pagination page 1 — PARTITIONED (reports list) ======'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id, captured_at FROM reports_p WHERE crisis_id='crisis-big' ORDER BY captured_at DESC, id DESC LIMIT 50;

\echo '====== Q5 MVT tile bbox, NO crisis (cross-partition GIST) — "near me" ======'
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT count(*) FROM reports_p WHERE geom && ST_MakeEnvelope(36.21,36.21,36.215,36.215,4326);

\echo '--- sizes ---'
SELECT 'reports_p total' AS obj, pg_size_pretty(pg_total_relation_size('reports_p')) AS sz
UNION ALL SELECT 'reports_p_big partition', pg_size_pretty(pg_total_relation_size('reports_p_big'));
\echo 'DONE.'
