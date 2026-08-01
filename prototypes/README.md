# Prototypes

Standalone experiments that are not part of the app target. Nothing in here ships.

## foundation-models/

Experiments running Apple's on-device LLM (FoundationModels framework, macOS 26+) against the real Safari Reading List to evaluate possible AI features.

**Requirements:** macOS 26+, Apple Silicon, Apple Intelligence enabled, and Full Disk Access for your terminal (the scripts read `~/Library/Safari/Bookmarks.plist` directly, read-only).

```bash
cd prototypes/foundation-models
swiftc -O -parse-as-library probe.swift -o probe && ./probe   # sanity check
swiftc -O -parse-as-library experiments.swift -o exp
./exp audit      # data-quality stats over the whole reading list (no AI)
./exp topics     # free-form topic tagging, 40-item sample
./exp compare    # title-only vs title+preview tagging quality
./exp suggest    # propose smart-list categories from 80 titles
./exp classify   # classify 20 items into a fixed category set
./exp cleanup    # rewrite noisy preview text as one clean sentence
./exp fetch      # fetch pages lacking previews and summarize them
```

Samples are seeded, so runs are comparable.

## Findings (August 2026, 4,494-item library)

- 93% of items have preview text, but Safari caps it at ~220 chars; 22% of items have a bare URL as their title (mostly t.co) — the model can't do anything useful for those without fetching the page.
- Preview text measurably improves tagging over title-only. Cleanup of noisy previews into one-sentence summaries was the strongest result (8/8 good).
- Free-form topic tags fragment (near-duplicate tags, long tail). A controlled vocabulary — model proposes categories once, then classifies against them — works better.
- Classification into a fixed set was ~85% accurate: fine for suggestions, not for silent auto-filing. Apple's guardrails refused a couple of crypto-related items, so real features need graceful fallbacks.
- Throughput ~0.4s/item on M-series: tagging the full library is ~30 min of one-time background work. Page fetches ~1s each — viable on demand, not for the whole library.

Conclusion at the time: nothing compelling enough to add to the UI yet.
