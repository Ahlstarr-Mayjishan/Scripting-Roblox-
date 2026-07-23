import assert from "node:assert/strict";
import test from "node:test";

import { compareNetworkSignals, requiresNetworkReauth } from "../src/risk.js";

test("network changes are risk signals and never hard authorization decisions", () => {
  assert.deepEqual(
    compareNetworkSignals(
      { ipHash: "ip-a", country: "VN", asn: "7552" },
      { ipHash: "ip-a", country: "VN", asn: "7552" },
    ),
    { ipChanged: false, countryChanged: false, asnChanged: false, score: 0 },
  );

  assert.deepEqual(
    compareNetworkSignals(
      { ipHash: "ip-a", country: "VN", asn: "7552" },
      { ipHash: "ip-b", country: "VN", asn: "7552" },
    ),
    { ipChanged: true, countryChanged: false, asnChanged: false, score: 10 },
  );

  const vpnChange = compareNetworkSignals(
    { ipHash: "ip-a", country: "VN", asn: "7552" },
    { ipHash: "ip-b", country: "SG", asn: "13335" },
  );
  assert.equal(vpnChange.countryChanged, true);
  assert.equal(vpnChange.asnChanged, true);
  assert.equal(vpnChange.score, 70);
  assert.equal("blocked" in vpnChange, false);
});

test("only a recent country or ASN switch requires session re-authentication", () => {
  const now = 10_000;
  const current = { ipHash: "new", country: "VN", asn: "7552" };

  assert.equal(requiresNetworkReauth(null, current, now, 180), false);
  assert.equal(requiresNetworkReauth({
    last_seen_at: now - 20,
    ipHash: "old",
    country: "VN",
    asn: "7552",
  }, current, now, 180), false);
  assert.equal(requiresNetworkReauth({
    last_seen_at: now - 20,
    ipHash: "old",
    country: "US",
    asn: "7922",
  }, current, now, 180), true);
  assert.equal(requiresNetworkReauth({
    last_seen_at: now - 181,
    ipHash: "old",
    country: "US",
    asn: "7922",
  }, current, now, 180), false);
});
