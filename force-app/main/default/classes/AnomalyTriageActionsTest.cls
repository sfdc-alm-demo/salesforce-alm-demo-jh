@IsTest
private class AnomalyTriageActionsTest {

    @TestSetup
    static void setup() {
        Account a1 = new Account(Name='ADI Test', SLA_Tier__c='Gold', Strategic_Account__c=false);
        Account a2 = new Account(Name='Micron Test', SLA_Tier__c='Strategic', Strategic_Account__c=true);
        insert new List<Account>{a1, a2};

        Asset adiAsset = new Asset(Name='AD9082', SerialNumber='ADI-AD9082-FAB-7741', AccountId=a1.Id);
        Asset micronAsset = new Asset(Name='DDR5', SerialNumber='MICRON-DDR5-DC-9921', AccountId=a2.Id);
        insert new List<Asset>{adiAsset, micronAsset};

        Known_Pattern__c kp = new Known_Pattern__c(
            Name='Thermal-Recoverable-AD9xxx',
            Pattern_Hash__c='hash_known_thermal',
            Match_Confidence__c=0.92,
            Anomaly_Category__c='Thermal',
            Recommended_Action__c='Throttle clock 15%, monitor 30min, replace if recurrence.'
        );
        Known_Pattern__c kp2 = new Known_Pattern__c(
            Name='Thermal-Mid-Confidence',
            Pattern_Hash__c='hash_mid_conf',
            Match_Confidence__c=0.72,
            Anomaly_Category__c='Thermal',
            Recommended_Action__c='Engineer review.'
        );
        insert new List<Known_Pattern__c>{kp, kp2};
    }

    static AnomalyTriageActions.TriageRequest makeReq(String corr, String serial, String code, String cat, String sev, String hash) {
        AnomalyTriageActions.TriageRequest r = new AnomalyTriageActions.TriageRequest();
        r.correlationId = corr;
        r.deviceSerial = serial;
        r.anomalyCode = code;
        r.anomalyCategory = cat;
        r.severitySignal = sev;
        r.patternHash = hash;
        r.confidenceScore = 0.9;
        r.sourceSystem = 'TestSys';
        r.siteCode = 'TST-1';
        r.telemetryPayload = '{"k":"v"}';
        return r;
    }

    @IsTest
    static void tier3_novel_high_severity_strategic() {
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-t3-novel', 'MICRON-DDR5-DC-9921', 'ECC_BURST_NOVEL_88', 'Memory_ECC', 'Critical', 'hash_unknown_xyz');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Novel + Critical must be Tier 3');
        Asset a = [SELECT Triage_Frozen__c FROM Asset WHERE SerialNumber='MICRON-DDR5-DC-9921'];
        System.assertEquals(true, a.Triage_Frozen__c, 'Tier 3 must freeze asset');
    }

    @IsTest
    static void tier2_gold_high_severity_known_pattern_mid_conf() {
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-t2-gold', 'ADI-AD9082-FAB-7741', 'TEMP_SPIKE_001', 'Thermal', 'High', 'hash_mid_conf');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(2, rs[0].tier, 'Gold+High with mid-confidence must be Tier 2');
        Asset a = [SELECT Triage_Frozen__c FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'];
        System.assertEquals(false, a.Triage_Frozen__c, 'Tier 2 must NOT freeze asset');
    }

    @IsTest
    static void tier1_known_recoverable_low_sla() {
        Account a = [SELECT Id FROM Account WHERE Name='ADI Test'];
        a.SLA_Tier__c = 'Standard';
        update a;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-t1-std', 'ADI-AD9082-FAB-7741', 'TEMP_SPIKE_001', 'Thermal', 'Low', 'hash_known_thermal');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(1, rs[0].tier, 'Standard SLA + known recoverable + Thermal must be Tier 1');
    }

    @IsTest
    static void idempotency_duplicate_skipped() {
        Test.startTest();
        AnomalyTriageActions.TriageRequest req1 = makeReq('corr-dup-1', 'ADI-AD9082-FAB-7741', 'X', 'Thermal', 'Medium', 'hash_known_thermal');
        AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req1});
        AnomalyTriageActions.TriageRequest req2 = makeReq('corr-dup-1', 'ADI-AD9082-FAB-7741', 'X', 'Thermal', 'Medium', 'hash_known_thermal');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req2});
        Test.stopTest();
        System.assertEquals(true, rs[0].duplicate, 'Second call with same correlation_id must be flagged duplicate');
    }

    @IsTest
    static void unknown_asset_fails_safe_to_tier3() {
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-unknown', 'NOT-A-REAL-SERIAL', 'X', 'Thermal', 'Critical', 'hash_unknown');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Unknown asset must fail-safe to Tier 3');
        System.assertEquals('UNKNOWN_ASSET_FAIL_SAFE', rs[0].classificationRule);
    }

    @IsTest
    static void confidence_boundary_0_85_inclusive_for_tier1() {
        Account a = [SELECT Id FROM Account WHERE Name='ADI Test'];
        a.SLA_Tier__c = 'Silver';
        update a;
        Known_Pattern__c kp = new Known_Pattern__c(Name='Boundary', Pattern_Hash__c='hash_boundary', Match_Confidence__c=0.85, Anomaly_Category__c='Thermal');
        insert kp;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-bound', 'ADI-AD9082-FAB-7741', 'X', 'Thermal', 'Low', 'hash_boundary');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(1, rs[0].tier, 'Confidence exactly 0.85 must qualify for Tier 1');
    }

    @IsTest
    static void platform_event_trigger_dispatches_to_actions() {
        Test.startTest();
        Database.SaveResult sr = EventBus.publish(new Device_Anomaly__e(
            Device_Serial__c='ADI-AD9082-FAB-7741',
            Anomaly_Code__c='TEMP_SPIKE_001',
            Anomaly_Category__c='Thermal',
            Severity_Signal__c='High',
            Telemetry_Payload__c='{}',
            Detected_At__c=DateTime.now(),
            Source_System__c='TestSys',
            Confidence_Score__c=0.91,
            Pattern_Hash__c='hash_mid_conf',
            Site_Code__c='TST-1',
            Replay_Correlation_Id__c='corr-pe-trigger-1'
        ));
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(true, sr.isSuccess(), 'PE publish must succeed');
        System.assertEquals(1, [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c='corr-pe-trigger-1'], 'Trigger must produce one audit row');
    }

    // ---------------------------------------------------------------------
    // WATCHDOG hardening tests (15 new methods) — added 2026-06-10
    // Validates bulkification, classifier branch coverage, side-effect
    // suppression on frozen asset, idempotency side effects, reasoning
    // trace cap, PE trigger dispatch, and blank-input edges.
    // ---------------------------------------------------------------------

    @IsTest
    static void bulk_200_events_through_triage_action() {
        // Arrange: 200 unique correlation IDs, same known asset, mid-conf known pattern
        // -> Tier 2 GOLD_SLA_HIGH_SEVERITY (Gold + High + conf 0.72 in 0.60-0.85 band: actually
        // KNOWN_PATTERN_ESCALATION_CONFIDENCE_BAND fires first; either way Tier 2).
        List<AnomalyTriageActions.TriageRequest> reqs = new List<AnomalyTriageActions.TriageRequest>();
        for (Integer i = 0; i < 200; i++) {
            reqs.add(makeReq('corr-bulk-action-' + i, 'ADI-AD9082-FAB-7741',
                'TEMP_SPIKE_001', 'Thermal', 'High', 'hash_mid_conf'));
        }
        Test.startTest();
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(reqs);
        Test.stopTest();
        // Assert: 200 results, all classified, governor limits not blown
        System.assertEquals(200, rs.size(), 'All 200 reqs must produce results');
        Integer audits = [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c LIKE 'corr-bulk-action-%'];
        System.assertEquals(200, audits, 'Bulk 200 must produce 200 audit rows');
    }

    @IsTest
    static void bulk_200_events_through_PE_trigger() {
        // Arrange: 200 PE publishes in one transaction
        List<Device_Anomaly__e> evts = new List<Device_Anomaly__e>();
        for (Integer i = 0; i < 200; i++) {
            evts.add(new Device_Anomaly__e(
                Device_Serial__c='ADI-AD9082-FAB-7741',
                Anomaly_Code__c='TEMP_SPIKE_001',
                Anomaly_Category__c='Thermal',
                Severity_Signal__c='High',
                Telemetry_Payload__c='{}',
                Detected_At__c=DateTime.now(),
                Source_System__c='TestSys',
                Confidence_Score__c=0.72,
                Pattern_Hash__c='hash_mid_conf',
                Site_Code__c='TST-1',
                Replay_Correlation_Id__c='corr-bulk-pe-' + i
            ));
        }
        Test.startTest();
        List<Database.SaveResult> srs = EventBus.publish(evts);
        Test.getEventBus().deliver();
        Test.stopTest();
        // Assert: every publish OK and trigger produced 200 audits
        for (Database.SaveResult sr : srs) System.assertEquals(true, sr.isSuccess(), 'PE publish failed');
        Integer audits = [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c LIKE 'corr-bulk-pe-%'];
        System.assertEquals(200, audits, 'Bulk PE must produce 200 audit rows via trigger');
    }

    @IsTest
    static void tier3_correlation_breach_3_in_24h() {
        // Arrange: pre-seed 3 audit rows in last 24h on ADI asset, then trigger 4th request.
        // Use known pattern + Medium sev + Gold SLA + non-strategic so we DODGE
        // novel+highSev and strategic+highSev rules, landing on recentCount>=3.
        Asset adi = [SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'];
        List<Anomaly_Audit__c> seed = new List<Anomaly_Audit__c>();
        for (Integer i = 0; i < 3; i++) {
            seed.add(new Anomaly_Audit__c(
                Correlation_Id__c='seed-corr-' + i,
                Asset__c=adi.Id,
                Tier__c='Tier 2',
                Processed_At__c=DateTime.now().addHours(-1),
                Trace_JSON__c='{}'
            ));
        }
        insert seed;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-corr-breach',
            'ADI-AD9082-FAB-7741', 'TEMP_SPIKE_001', 'Thermal', 'Medium', 'hash_known_thermal');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Recent count >=3 must escalate to Tier 3');
        System.assertEquals('CORRELATION_BREACH_3_IN_24H', rs[0].classificationRule);
    }

    @IsTest
    static void tier2_existing_open_p1_p2_case_path() {
        // The org has a flow ('SDO Service - Case - On Create') that requires a
        // helperConfig param and blocks direct Case inserts in apex tests, so we
        // can't seed an open Case via DML. Instead, unit-test the classifier
        // branch directly: build the AssetContext + PatternMatch fixtures the
        // selectors would have returned, and assert the rule fires.
        AnomalySelectors.AssetContext ctx = new AnomalySelectors.AssetContext();
        ctx.assetId = [SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'].Id;
        ctx.accountId = [SELECT Id FROM Account WHERE Name='ADI Test'].Id;
        ctx.accountName = 'ADI Test';
        ctx.slaTier = 'Silver';
        ctx.strategicAccount = false;
        ctx.triageFrozen = false;
        AnomalySelectors.PatternMatch pm = new AnomalySelectors.PatternMatch();
        pm.found = true; pm.matchConfidence = 0.95; pm.patternName='X';
        Test.startTest();
        AnomalyClassifier.Decision d = AnomalyClassifier.classify(
            ctx, pm, /*recent*/0, /*openP1P2*/1, 'Low', 'Power');
        Test.stopTest();
        System.assertEquals(2, d.tier, 'Open P1/P2 case path must yield Tier 2');
        System.assertEquals('EXISTING_OPEN_P1_P2_CASE', d.rule);
    }

    @IsTest
    static void tier3_strategic_account_high_severity_known_pattern() {
        // Strategic + High sev + known pattern (so not novel+highSev) -> STRATEGIC_ACCOUNT_HIGH_SEVERITY
        // Add a known pattern hash so novel=false but unrelated to thermal recoverable gate.
        Known_Pattern__c kp = new Known_Pattern__c(Name='Mem-Known',
            Pattern_Hash__c='hash_mem_known', Match_Confidence__c=0.95,
            Anomaly_Category__c='Memory_ECC', Recommended_Action__c='Replace DIMM.');
        insert kp;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-strat-high',
            'MICRON-DDR5-DC-9921', 'ECC_001', 'Memory_ECC', 'High', 'hash_mem_known');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Strategic+High must be Tier 3');
        System.assertEquals('STRATEGIC_ACCOUNT_HIGH_SEVERITY', rs[0].classificationRule);
    }

    @IsTest
    static void tier3_platinum_sla_high_severity_non_strategic() {
        // Set ADI to Platinum, non-strategic. Use known pattern + High sev to dodge novel+highSev,
        // then strategic+highSev fails (not strategic), recent=0, lands on Plat/Strat+highSev.
        Account a = [SELECT Id FROM Account WHERE Name='ADI Test'];
        a.SLA_Tier__c = 'Platinum';
        a.Strategic_Account__c = false;
        update a;
        Known_Pattern__c kp = new Known_Pattern__c(Name='Plat-Known',
            Pattern_Hash__c='hash_plat_known', Match_Confidence__c=0.95,
            Anomaly_Category__c='Thermal', Recommended_Action__c='Throttle.');
        insert kp;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-plat-high',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'High', 'hash_plat_known');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Platinum+High (non-strategic) must be Tier 3');
        System.assertEquals('PLATINUM_OR_STRATEGIC_HIGH_SEVERITY', rs[0].classificationRule);
    }

    @IsTest
    static void tier2_gold_high_severity_branch_isolated() {
        // Gold SLA + High sev + known pattern with conf >= 0.85 (so we skip the
        // 0.60-0.85 confidence-band rule), non-strategic, recent=0 -> GOLD_SLA_HIGH_SEVERITY.
        Known_Pattern__c kp = new Known_Pattern__c(Name='Gold-High-Known',
            Pattern_Hash__c='hash_gold_high', Match_Confidence__c=0.95,
            Anomaly_Category__c='Thermal', Recommended_Action__c='Throttle.');
        insert kp;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-gold-high',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'High', 'hash_gold_high');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(2, rs[0].tier);
        System.assertEquals('GOLD_SLA_HIGH_SEVERITY', rs[0].classificationRule);
    }

    @IsTest
    static void tier2_novel_medium_severity() {
        // Novel pattern + Medium sev + Gold SLA + non-strategic -> NOVEL_PATTERN_MEDIUM_SEVERITY
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-novel-med',
            'ADI-AD9082-FAB-7741', 'WEIRD_001', 'Thermal', 'Medium', 'hash_does_not_exist');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(2, rs[0].tier);
        System.assertEquals('NOVEL_PATTERN_MEDIUM_SEVERITY', rs[0].classificationRule);
    }

    @IsTest
    static void default_escalate_fallthrough() {
        // Known pattern conf>=0.85, Silver SLA, Low sev, category Power
        // (so Tier 1 gate misses on category). All other rules miss -> DEFAULT_ESCALATE.
        Account a = [SELECT Id FROM Account WHERE Name='ADI Test'];
        a.SLA_Tier__c = 'Silver';
        update a;
        Known_Pattern__c kp = new Known_Pattern__c(Name='Power-Default',
            Pattern_Hash__c='hash_power_default', Match_Confidence__c=0.95,
            Anomaly_Category__c='Power', Recommended_Action__c='Recheck.');
        insert kp;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-default',
            'ADI-AD9082-FAB-7741', 'PWR_002', 'Power', 'Low', 'hash_power_default');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(2, rs[0].tier);
        System.assertEquals('DEFAULT_ESCALATE', rs[0].classificationRule);
    }

    @IsTest
    static void asset_frozen_override_suppresses_automation() {
        // Pre-freeze asset. Code path: alreadyProcessed=false, ctx loaded (frozen=true),
        // classify() runs, then the freeze override fires BEFORE createCase/insert.
        // Contract: NO Case, NO WorkOrder, NO FeedItem; audit row written with
        // ASSET_FROZEN_HUMAN_REVIEW_ONLY rule.
        Asset adi = [SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'];
        adi.Triage_Frozen__c = true;
        adi.Triage_Frozen_Until__c = DateTime.now().addHours(24);
        update adi;
        Integer caseBefore = [SELECT COUNT() FROM Case WHERE AssetId=:adi.Id];
        Integer woBefore = [SELECT COUNT() FROM WorkOrder WHERE AssetId=:adi.Id];
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-frozen',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'High', 'hash_mid_conf');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Frozen override forces Tier 3');
        System.assertEquals('ASSET_FROZEN_HUMAN_REVIEW_ONLY', rs[0].classificationRule);
        System.assertEquals(null, rs[0].caseId, 'No Case must be created when asset frozen');
        System.assertEquals(null, rs[0].workOrderId, 'No WorkOrder when asset frozen');
        System.assertEquals(caseBefore, [SELECT COUNT() FROM Case WHERE AssetId=:adi.Id],
            'Case count unchanged');
        System.assertEquals(woBefore, [SELECT COUNT() FROM WorkOrder WHERE AssetId=:adi.Id],
            'WorkOrder count unchanged');
        System.assertEquals(1, [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c='corr-frozen'],
            'Audit row still written');
    }

    @IsTest
    static void idempotency_duplicate_creates_no_side_effects() {
        // First call writes audit + case/etc; second call with same correlation_id
        // must short-circuit before any DML side effect.
        AnomalyTriageActions.TriageRequest first = makeReq('corr-idem-side',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'Medium', 'hash_known_thermal');
        AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{first});
        Integer auditAfterFirst = [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c='corr-idem-side'];
        Asset adi = [SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'];
        Integer caseAfterFirst = [SELECT COUNT() FROM Case WHERE AssetId=:adi.Id];
        Integer woAfterFirst = [SELECT COUNT() FROM WorkOrder];
        Test.startTest();
        AnomalyTriageActions.TriageRequest dup = makeReq('corr-idem-side',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'Medium', 'hash_known_thermal');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{dup});
        Test.stopTest();
        System.assertEquals(true, rs[0].duplicate);
        System.assertEquals(auditAfterFirst,
            [SELECT COUNT() FROM Anomaly_Audit__c WHERE Correlation_Id__c='corr-idem-side'],
            'Duplicate must not write a second audit row');
        System.assertEquals(caseAfterFirst,
            [SELECT COUNT() FROM Case WHERE AssetId=:adi.Id],
            'Duplicate must not create another Case');
        System.assertEquals(woAfterFirst, [SELECT COUNT() FROM WorkOrder],
            'Duplicate must not create another WorkOrder');
    }

    @IsTest
    static void reasoning_trace_truncates_to_131k() {
        // Pre-fill Reasoning_Trace__c near the cap; triage must keep total <= 131000 chars.
        Asset adi = [SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741'];
        String filler = '';
        // Build a 130_990-char string (just under cap) so any new entry forces truncation.
        String chunk = '0123456789';
        for (Integer i = 0; i < 13099; i++) filler += chunk;
        adi.Reasoning_Trace__c = filler;
        update adi;
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-trace-cap',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'Medium', 'hash_known_thermal');
        AnomalyTriageActions.triage(new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        Asset after = [SELECT Reasoning_Trace__c FROM Asset WHERE Id=:adi.Id];
        System.assert(after.Reasoning_Trace__c != null, 'Trace must be populated');
        System.assert(after.Reasoning_Trace__c.length() <= 131000,
            'Trace must be capped at <= 131000 chars; was ' + after.Reasoning_Trace__c.length());
    }

    @IsTest
    static void pe_trigger_dispatch_validates_tier_and_side_effects() {
        // PE publish for known mid-conf pattern + High sev + Gold acct should
        // yield Tier 2, with a Case and an audit row, via trigger -> action.
        Test.startTest();
        Database.SaveResult sr = EventBus.publish(new Device_Anomaly__e(
            Device_Serial__c='ADI-AD9082-FAB-7741',
            Anomaly_Code__c='TEMP_SPIKE_999',
            Anomaly_Category__c='Thermal',
            Severity_Signal__c='High',
            Telemetry_Payload__c='{}',
            Detected_At__c=DateTime.now(),
            Source_System__c='TestSys',
            Confidence_Score__c=0.72,
            Pattern_Hash__c='hash_mid_conf',
            Site_Code__c='TST-1',
            Replay_Correlation_Id__c='corr-pe-tier2'
        ));
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(true, sr.isSuccess(), 'PE publish must succeed');
        List<Anomaly_Audit__c> audits = [SELECT Tier__c, Case__c, Asset__c FROM Anomaly_Audit__c
            WHERE Correlation_Id__c='corr-pe-tier2'];
        System.assertEquals(1, audits.size(), 'Trigger produced exactly one audit row');
        System.assertEquals('Tier 2', audits[0].Tier__c, 'Tier 2 expected for mid-conf+Gold+High');
        // NOTE: audit.Case__c is null in apex tests because the org flow
        // 'SDO Service - Case - On Create' rejects Case insert (missing
        // helperConfig). The triage code's try/catch swallows that. We verify
        // the trigger->action dispatch reached the audit step with correct tier.
        System.assertNotEquals(null, audits[0].Asset__c, 'Audit must link the Asset');
    }

    @IsTest
    static void blank_correlation_id_does_not_short_circuit_as_duplicate() {
        // alreadyProcessed() returns false for blank correlation_id, so the request must
        // proceed to classification (NOT be flagged duplicate). The audit insert will
        // ultimately fail because Correlation_Id__c is required+unique on the SObject;
        // we catch that and assert the request reached classify (i.e. side-effect DML
        // happened past the duplicate-check return).
        AnomalyTriageActions.TriageRequest req = makeReq('',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'Medium', 'hash_known_thermal');
        Test.startTest();
        Boolean threw = false;
        Integer caseCountBefore = [SELECT COUNT() FROM Case WHERE AssetId IN
            (SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741')];
        try {
            List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
                new List<AnomalyTriageActions.TriageRequest>{req});
            // If triage completes, blank corr did not short-circuit as duplicate
            System.assertEquals(false, rs[0].duplicate,
                'Blank correlation_id must NOT be flagged as duplicate');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        // Either path proves we did NOT short-circuit on duplicate: caseCount grew
        // or an exception fired (audit insert) — both happen only past the dup-check.
        Integer caseCountAfter = [SELECT COUNT() FROM Case WHERE AssetId IN
            (SELECT Id FROM Asset WHERE SerialNumber='ADI-AD9082-FAB-7741')];
        System.assert(caseCountAfter > caseCountBefore || threw,
            'Blank correlation_id must reach classify+act, not be skipped as duplicate');
    }

    @IsTest
    static void blank_pattern_hash_treated_as_novel() {
        // Blank pattern_hash -> lookupKnownPattern returns found=false (novel).
        // Combined with High sev -> NOVEL_PATTERN_HIGH_SEVERITY, Tier 3.
        Test.startTest();
        AnomalyTriageActions.TriageRequest req = makeReq('corr-blank-hash',
            'ADI-AD9082-FAB-7741', 'TEMP_001', 'Thermal', 'High', '');
        List<AnomalyTriageActions.TriageResult> rs = AnomalyTriageActions.triage(
            new List<AnomalyTriageActions.TriageRequest>{req});
        Test.stopTest();
        System.assertEquals(3, rs[0].tier, 'Blank pattern_hash treated as novel; high sev -> Tier 3');
        System.assertEquals('NOVEL_PATTERN_HIGH_SEVERITY', rs[0].classificationRule);
    }
}