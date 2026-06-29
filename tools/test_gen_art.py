#!/usr/bin/env python3
"""Tests for the art pipeline (tools/gen_art.py): the pure prompt builder + the manifest
skip/resume logic, with the OpenAI call MOCKED. No network, no key, no real API ever.

Matches the repo's standalone-script test style (plain `python -B`, exit 1 on any failure) —
the same shape as tools/test_rng_parity.py. Run: python -B tools/test_gen_art.py
"""
import os
import sys
import tempfile
import warnings

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_art as ga

fails = []
n = 0


def check(label, cond):
    global n
    n += 1
    if not cond:
        fails.append(label)


def row(**kw):
    base = {"id": "AD01", "name": "Ruinmaw", "batch": "adult", "rank": "wild",
            "class": "organic", "art_ref": "adult#1", "tier": "T2", "line": "Ruin Wolf",
            "stage": "adult", "force_primary": "Chaos", "force_secondary": "Thanatos",
            "role": "striker", "acquisition": "trap", "tags": "",
            "description": "Feral runed wolf; bleeds what it bites.", "status": "confirmed"}
    base.update(kw)
    return base


# --- slugify ---------------------------------------------------------------
check("slug basic", ga.slugify("Ruinmaw") == "ruinmaw")
check("slug spaces/punct", ga.slugify("Pale Hart!") == "pale-hart")
check("slug empty -> fallback", ga.slugify("") == "creature")
check("slug collapses runs", ga.slugify("A -- B") == "a-b")


# --- build_prompt (pure) ---------------------------------------------------
p = ga.build_prompt(row())
check("prompt starts with STYLE_ANCHOR", p.startswith(ga.STYLE_ANCHOR))
check("prompt is deterministic", ga.build_prompt(row()) == p)
check("prompt names the creature", "Ruinmaw" in p)
check("prompt mentions role", "striker" in p)
check("prompt includes description", "bleeds what it bites" in p)
check("prompt has primary force key", "Primary force Chaos" in p)
check("prompt has primary force language", "oil-slick" in p)
check("prompt has secondary touch", "touch of Thanatos" in p)
check("prompt has secondary force language", "soul-fire" in p)
check("prompt has sigil instruction", "occult sigil" in p)
check("prompt has chaos sigil motif (jagged)", "jagged occult sigil" in p)
check("prompt forbids text/border", "no text" in p.lower())

# Stage notes vary the silhouette.
check("baby stage note", "Baby stage" in ga.build_prompt(row(stage="baby")))
check("apex stage note", "apex form" in ga.build_prompt(row(stage="apex")))

# Blank secondary -> no 'touch of' clause; unknown force -> no key clause.
p_nosec = ga.build_prompt(row(force_secondary=""))
check("no secondary clause when blank", "touch of" not in p_nosec)
p_pure = ga.build_prompt(row(force_primary="Cosmos", force_secondary="Cosmos"))
check("same prim/sec -> no touch clause", "touch of" not in p_pure)
check("cosmos sigil motif (geometric)", "geometric occult sigil" in p_pure)

# Every force has a visual key + sigil motif (vocabulary completeness).
for force in ["Cosmos", "Chaos", "Eros", "Thanatos", "Gaia", "Ouranos"]:
    check("force_phrase[%s]" % force, ga.force_phrase(force) != "")
    check("sigil motif[%s]" % force, force in ga.SIGIL_MOTIF)
check("unknown force_phrase -> ''", ga.force_phrase("Nope") == "")


# --- is_generatable / select_rows -----------------------------------------
void = {"id": "X", "name": "", "force_primary": "", "status": "void"}
blank = {"id": "Y", "name": "", "force_primary": "", "status": "reviewed"}
check("void row not generatable", not ga.is_generatable(void))
check("blank (no name, no force) not generatable", not ga.is_generatable(blank))
check("real row generatable", ga.is_generatable(row()))
check("named-but-no-force row generatable", ga.is_generatable(row(force_primary="")))
# Force-only rows (no name) are real creatures (batch3/4/5) and ARE generatable.
forceonly = {"id": "Z", "name": "", "force_primary": "Eros", "force_secondary": "",
             "role": "", "stage": "", "description": "", "status": "reviewed"}
check("force-only (no name) row generatable", ga.is_generatable(forceonly))
fp = ga.build_prompt(forceonly)
check("force-only prompt has STYLE_ANCHOR", fp.startswith(ga.STYLE_ANCHOR))
check("force-only prompt has force key", "Primary force Eros" in fp)
check("force-only prompt names placeholder", "unnamed creature" in fp)

rows = [row(id="AD01"), row(id="AD02", batch="demon"),
        row(id="AD03", status="reviewed"), void]
check("select all generatable (skips void)", len(ga.select_rows(rows)) == 3)
check("select --only", [r["id"] for r in ga.select_rows(rows, only="AD01,AD03")] == ["AD01", "AD03"])
check("select --batch", [r["id"] for r in ga.select_rows(rows, batch="demon")] == ["AD02"])
check("select --status", [r["id"] for r in ga.select_rows(rows, status="reviewed")] == ["AD03"])
check("select --limit", len(ga.select_rows(rows, limit=2)) == 2)


# --- output_path -----------------------------------------------------------
op = ga.output_path("/out", row())
check("output_path id+slug", op.endswith("AD01_ruinmaw.png"))


# --- pricing: known sizes vs default-size fallback -------------------------
check("price known default size", ga.price_is_known(ga.DEFAULT_SIZE))
check("price known tall size", ga.price_is_known("1024x1536"))
check("price unknown size", not ga.price_is_known("2048x2048"))
check("price_for known returns its own price",
      ga.price_for("1024x1536") == ga.PRICE_PER_IMAGE_USD["1024x1536"])
check("price_for unknown falls back to default-size price",
      ga.price_for("2048x2048") == ga.PRICE_PER_IMAGE_USD[ga.DEFAULT_SIZE])


# --- the real registry parses and builds prompts cleanly -------------------
real = ga.load_registry()
check("registry has 407 rows", len(real) == 407)
gen_rows = [r for r in real if ga.is_generatable(r)]
check("registry has 406 generatable (1 truly-blank void skipped)", len(gen_rows) == 406)
for r in gen_rows:
    bp = ga.build_prompt(r)
    check("real prompt nonempty %s" % r["id"], len(bp) > len(ga.STYLE_ANCHOR))


# --- API key loading (env + file fallback, no real key) --------------------
saved_key = os.environ.pop("OPENAI_API_KEY", None)
try:
    check("no key -> None", ga.load_api_key(secrets_file="/no/such/file") is None)
    os.environ["OPENAI_API_KEY"] = "env-key-xyz"
    check("env key wins", ga.load_api_key(secrets_file="/no/such/file") == "env-key-xyz")
    del os.environ["OPENAI_API_KEY"]
    with tempfile.TemporaryDirectory() as td:
        sf = os.path.join(td, ".art_secrets.env")
        with open(sf, "w", encoding="utf-8") as fh:
            fh.write("# comment\nOPENAI_API_KEY=\"file-key-abc\"\nOTHER=1\n")
        check("file key fallback", ga.load_api_key(secrets_file=sf) == "file-key-abc")
finally:
    if saved_key is not None:
        os.environ["OPENAI_API_KEY"] = saved_key
    else:
        os.environ.pop("OPENAI_API_KEY", None)


# --- OpenAI client uses the injected opener (NO network) -------------------
calls = []


def fake_opener(req):
    calls.append(req)
    return b"\x89PNG-fake-bytes"


client = ga.OpenAIImageClient("fake-key", opener=fake_opener)
out = client.generate("a prompt")
check("client returns bytes from opener", out == b"\x89PNG-fake-bytes")
check("client passed prompt to opener", calls[0]["body"]["prompt"] == "a prompt")
check("client sent model gpt-image-1", calls[0]["body"]["model"] == "gpt-image-1")
check("client never leaks key in body", "fake-key" not in str(calls[0]["body"]))
check("client auth header set", calls[0]["headers"]["Authorization"] == "Bearer fake-key")


# --- generate_with_retry: backoff then success / total failure -------------
attempts = {"n": 0}


def flaky(req):
    attempts["n"] += 1
    if attempts["n"] < 3:
        raise RuntimeError("transient")
    return b"ok-bytes"


slept = []
c2 = ga.OpenAIImageClient("k", opener=flaky)
res = ga.generate_with_retry(c2, "p", retries=3, sleep=slept.append)
check("retry eventually succeeds", res == b"ok-bytes")
check("retry slept twice", len(slept) == 2)


def always_fail(req):
    raise RuntimeError("boom")


threw = False
try:
    ga.generate_with_retry(ga.OpenAIImageClient("k", opener=always_fail), "p",
                           retries=2, sleep=lambda s: None)
except RuntimeError:
    threw = True
check("retry raises after exhausting", threw)


# --- manifest skip/resume (the generate-once invariant), OpenAI MOCKED -----
class Args:
    def __init__(self, **kw):
        self.dry_run = False
        self.limit = None
        self.only = "AD01"
        self.batch = None
        self.status = None
        self.force = False
        self.size = ga.DEFAULT_SIZE
        self.out_dir = None
        self.__dict__.update(kw)


def run_live(out_dir, opener, **kw):
    """Run the pipeline with a mocked client + a fake key (forces the 'live' path, no network)."""
    gen_calls = {"n": 0}

    def counting(req):
        gen_calls["n"] += 1
        return opener(req)

    orig_client = ga.OpenAIImageClient
    orig_load_key = ga.load_api_key
    ga.load_api_key = lambda *a, **k: "fake-key"
    ga.OpenAIImageClient = lambda api_key, **ckw: orig_client(api_key, opener=counting, **ckw)
    try:
        code = ga.run(Args(out_dir=out_dir, **kw))
    finally:
        ga.OpenAIImageClient = orig_client
        ga.load_api_key = orig_load_key
    return code, gen_calls["n"]


with tempfile.TemporaryDirectory() as td:
    # First live run: generates AD01, writes image + manifest entry.
    code, ncalls = run_live(td, lambda req: b"PNGDATA")
    check("first run exit 0", code == 0)
    check("first run made 1 API call", ncalls == 1)
    man = ga.load_manifest(td)
    check("manifest has AD01 done", man.get("AD01", {}).get("status") == "done")
    check("manifest records sha256", len(man["AD01"]["sha256"]) == 64)
    check("manifest records prompt", man["AD01"]["prompt"].startswith(ga.STYLE_ANCHOR))
    imgs = [f for f in os.listdir(td) if f.endswith(".png")]
    check("image written", len(imgs) == 1 and imgs[0].startswith("AD01_"))

    # Second run (resume): AD01 already done -> SKIPPED, zero API calls.
    code2, ncalls2 = run_live(td, lambda req: b"SHOULD-NOT-RUN")
    check("resume run exit 0", code2 == 0)
    check("resume run made 0 API calls (generate-once)", ncalls2 == 0)

    # --force re-generates even when done.
    code3, ncalls3 = run_live(td, lambda req: b"PNGDATA2", force=True)
    check("--force re-runs API once", ncalls3 == 1)

    # A failing generation is recorded as 'failed' (retryable) and does NOT crash the run.
    def boom(req):
        raise RuntimeError("upstream down")

    code4, ncalls4 = run_live(td, boom, only="AD01", force=True)
    man4 = ga.load_manifest(td)
    check("failed gen recorded as failed", man4["AD01"]["status"] == "failed")
    check("failed gen recorded error", "upstream down" in man4["AD01"]["error"])
    check("failed-only run returns nonzero", code4 == 1)

    # After a failure (not 'done'), a subsequent run retries it (resume picks it back up).
    code5, ncalls5 = run_live(td, lambda req: b"RECOVERED")
    check("failed row retried on next run", ncalls5 == 1)
    check("retry marks it done", ga.load_manifest(td)["AD01"]["status"] == "done")


# --- dry-run path makes ZERO API calls and needs no key --------------------
saved = os.environ.pop("OPENAI_API_KEY", None)
try:
    with tempfile.TemporaryDirectory() as td:
        # Even with no key and dry_run, run() must not touch the client.
        code = ga.run(Args(out_dir=td, dry_run=True, only="AD01"))
        check("dry-run exit 0", code == 0)
        check("dry-run wrote no images", not any(f.endswith(".png") for f in os.listdir(td)))
        check("dry-run wrote no manifest", not os.path.exists(ga.manifest_path(td)))

        # A non-whitelisted --size warns (default-size price basis) but still runs.
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            code = ga.run(Args(out_dir=td, dry_run=True, only="AD01", size="2048x2048"))
        check("unknown-size run exit 0", code == 0)
        rt = [w for w in caught if issubclass(w.category, RuntimeWarning)]
        check("unknown-size emits RuntimeWarning", len(rt) == 1)
        check("warning names the default-size basis", ga.DEFAULT_SIZE in str(rt[0].message))

        # A known --size does NOT warn.
        with warnings.catch_warnings(record=True) as caught2:
            warnings.simplefilter("always")
            ga.run(Args(out_dir=td, dry_run=True, only="AD01", size="1024x1536"))
        check("known-size emits no RuntimeWarning",
              not [w for w in caught2 if issubclass(w.category, RuntimeWarning)])
finally:
    if saved is not None:
        os.environ["OPENAI_API_KEY"] = saved


# --- report ----------------------------------------------------------------
print("gen_art tests: %d checks, %d failed" % (n, len(fails)))
if fails:
    for f in fails:
        print("  FAIL: " + f)
    sys.exit(1)
print("OK - prompt builder + manifest skip/resume + mocked OpenAI all pass")
