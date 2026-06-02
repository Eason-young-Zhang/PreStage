# Baselines / 基线记录

This folder stores repeatable real-world regression and performance baseline reports.

本目录保存可重复运行的真实样本回归与性能基线记录。

## Real-World Folder Baseline / 真实文件夹基线

`RealWorldBaselineTests` is skipped by default. To run it against a local photo folder:

`RealWorldBaselineTests` 默认跳过。要针对本机照片文件夹运行，可使用：

```bash
env \
  CLANG_MODULE_CACHE_PATH=.build/module-cache \
  PRESTAGE_REALWORLD_SOURCE=/path/to/photo-folder \
  PRESTAGE_REALWORLD_RECURSIVE=false \
  PRESTAGE_REALWORLD_SAMPLE_LIMIT=80 \
  PRESTAGE_REALWORLD_REPORT=docs/baselines/example.md \
  swift test --disable-sandbox --filter RealWorldBaselineTests
```

The test records:

测试记录以下内容：

- scan, metadata, XMP, RAW/JPEG pairing, and proxy-readiness timings;
- media counts, RAW-only counts, total size, and proxy hit/missing counts;
- gallery preview source selection and preview warmup timings;
- the slowest preview warmup samples for follow-up diagnosis.

## 2026-05-26 Results / 2026-05-26 结果

- `real_world_dali_2026-05-26.md`: mixed DNG/RW2/JPEG folder, 860 files, 28.78 GB. Metadata loading is the dominant cost at 18.176s; gallery warmup sampled 80 items with no failures.
- `real_world_bridge_2026-05-01_2026-05-26.md`: RAW-only RW2 folder, 262 files, 6.34 GB. Metadata loading took 4.867s; gallery warmup sampled 80 RAW items with no failures.

Current interpretation:

当前判断：

- Plain scanning, XMP sidecar reads, pairing, and proxy freshness checks are fast enough for the tested folders.
- Metadata extraction is the main measurable cost in large folders.
- Proxy coverage is incomplete in the mixed Dali folder: 102 valid RAW proxies, 500 missing.
- RAW-only RW2 preview warmup is currently fast through ImageIO thumbnail extraction, but this still needs UI-level scrolling and switching checks on large folders.
