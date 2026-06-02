# LibRaw Evaluation Plan / LibRaw 评估方案

Last updated: 2026-05-26

This document evaluates whether PreStage should introduce LibRaw as an optional RAW decode backend.

本文用于评估 PreStage 是否应引入 LibRaw 作为可选 RAW 解码后端。

## Current Decode Pipeline / 当前解码管线

PreStage now routes preview-source selection, backend-based raster decoding, ImageIO downsampling, direct-raster capability checks, pixel-size reads, and warmup through `PreviewDecodeService`.

当前 PreStage 已通过 `PreviewDecodeService` 统一处理预览来源选择、后端式栅格解码、ImageIO 下采样、直接栅格解码能力判断、像素尺寸读取和预热缓存。

The current priority order is:

1. Prefer existing JPG/HEIC/PNG/TIFF files and valid generated JPG proxies.
2. Use ImageIO/CoreGraphics for direct preview when the format is supported.
3. Fall back to QuickLook for files that cannot be directly decoded.
4. Use the shared analysis buffer path for histogram and waveform data.

当前优先级：

1. 优先使用原始 JPG/HEIC/PNG/TIFF 或有效 JPG 代理文件。
2. 支持时使用 ImageIO/CoreGraphics 直接预览。
3. 无法直接解码时回退 QuickLook。
4. 直方图、波形图等分析工具使用共享分析缓冲。

This means LibRaw should not replace the whole pipeline immediately. It should be tested as a future `PreviewRasterDecodeProvider` behind the existing shared decode boundary.

因此 LibRaw 不应立即替换整个预览系统，而应先作为未来的 `PreviewRasterDecodeProvider` 放在现有共享解码边界之后进行对照测试。

## Why Evaluate LibRaw / 为什么评估 LibRaw

Potential benefits:

- More explicit RAW control than QuickLook or ImageIO.
- Access to RAW sensor data for clipping maps and more trustworthy RAW-aware scopes.
- Cross-platform decode core for the future Windows x86 port.
- More predictable behavior for formats where QuickLook quality or timing varies.
- Ability to generate standardized low-resolution previews and analysis buffers.

潜在收益：

- 比 QuickLook 和 ImageIO 更直接地控制 RAW 解码。
- 可访问 RAW 传感器数据，用于纯黑/纯白剪切图和更可信的 RAW 示波器。
- 可作为未来 Windows x86 版本的跨平台解码核心。
- 对 QuickLook 质量或加载时间不稳定的格式提供更可控的路径。
- 可生成统一规格的低分辨率预览和分析缓冲。

## What LibRaw Should Not Do First / 不应首先承担的职责

LibRaw should not initially become the default gallery renderer.

LibRaw 初期不应直接成为画廊默认渲染器。

Reasons:

- QuickLook and ImageIO already provide good system-integrated color handling and camera-format support.
- LibRaw introduces color science, white balance, demosaic, licensing, packaging, and performance risks.
- A bad RAW render path would harm review trust more than a slower fallback.

原因：

- QuickLook 和 ImageIO 已提供较好的系统颜色管理和相机格式支持。
- LibRaw 会带来色彩科学、白平衡、去马赛克、授权、打包和性能风险。
- 错误的 RAW 渲染比慢一些的 fallback 更伤害选片信任。

## Evaluation Options / 评估选项

| Option | Role | Pros | Cons | Recommendation |
| --- | --- | --- | --- | --- |
| ImageIO only | Current direct decode path | Native, simple, good color management, low maintenance | RAW internals are opaque; format coverage depends on macOS | Keep as default |
| QuickLook only | System preview fallback | Often high quality and fast for visual preview | Less controllable; harder to extract analysis buffers; switching can flicker | Keep as fallback |
| Core Image RAW | Apple RAW pipeline | Native, better access than QuickLook, ColorSync-friendly | Still Apple-only; Windows port cannot reuse it | Consider for soft proofing/profiles |
| LibRaw optional backend | RAW decode and analysis provider | Cross-platform, explicit RAW access, useful for clipping/scopes | Build/license/color/performance complexity | Evaluate behind protocol |
| External helper process | Separate RAW decoder CLI/service | Crash isolation, easier memory limits, can share with Windows | IPC complexity, slower first call, packaging overhead | Consider if LibRaw memory is risky |

## Prototype Scope / 原型范围

### Phase 0: Standalone Probe

Create a separate experiment target, for example `Experiments/LibRawProbe` or `Tools/RawDecodeProbe`.

Output:

- Decode selected RAW samples to 1024 px and 2048 px previews.
- Export JSON metrics: decode time, peak memory if available, dimensions, orientation, camera model, white balance mode, output profile assumptions.
- Export comparison thumbnails for visual inspection.
- Include no production UI integration.

阶段 0：先做独立探针，不接入正式 UI。输出低分辨率预览、性能 JSON 和对比缩略图。

### Phase 1: Provider Abstraction

The production pipeline now has a small backend protocol behind the existing decode service:

```swift
protocol PreviewRasterDecodeProvider {
    var identifier: String { get }

    func supportsDirectRasterPreview(url: URL) -> Bool
    func imagePixelSize(at url: URL) -> CGSize?
    func downsampledImage(at url: URL, maxPixelSize: Int) -> CGImage?
}
```

The default provider remains ImageIO/QuickLook. LibRaw is registered only in experimental builds or diagnostics.

阶段 1：生产管线已有后端协议，默认仍走 ImageIO/QuickLook；LibRaw 未来只应先在实验或诊断入口注册。

### Phase 2: Analysis-First Integration

Use LibRaw first for:

- RAW-aware clipping map.
- RAW-derived histogram/waveform comparison mode.
- Proxy generation quality comparison.
- Cross-platform decode parity samples for Windows.

Do not use it for default gallery display until it beats or matches current visual trust.

阶段 2：优先用于 RAW 剪切图、RAW 级示波器对照、代理质量对照和 Windows 迁移样本，不直接替代默认画廊预览。

### Phase 3: Optional Preview Backend

Only after the earlier phases pass should PreStage expose a hidden or advanced setting:

- Preview source: System / LibRaw / Auto.
- Proxy generator: System / LibRaw.
- Analysis source: Display preview / RAW data.

阶段 3：通过高级设置提供可选预览后端，而不是强制切换。

## Test Corpus / 测试素材

The LibRaw evaluation needs a fixed local corpus:

- Panasonic RW2 from the current Dali folder.
- DJI DNG and panoramic JPEG/DNG samples.
- Sony ARW.
- Canon CR2 and CR3.
- Nikon NEF.
- Fujifilm RAF.
- Olympus/OM System ORF.
- RAW+JPEG same-name pairs.
- High-aspect-ratio images and portrait images that previously exposed overlay geometry bugs.

评估必须覆盖当前项目真实痛点：Dali RW2、DJI DNG、RAW+JPEG 配对、超宽图、竖图，以及常见相机厂商 RAW。

## Metrics / 指标

Required measurements:

- First preview latency at 1024 px and 2048 px.
- Batch throughput for 100, 500, and 1000 RAW files.
- Peak RSS and per-decode temporary allocation.
- Cancellation latency when rapidly switching gallery selection.
- Output orientation and aspect-ratio correctness.
- Color comparison against QuickLook/ImageIO and Lightroom/Capture One reference exports.
- Proxy file size and generation time.
- Analysis-buffer consistency for histogram, waveform, clipping map, and future vectorscope.

必须测量首帧延迟、批量吞吐、峰值内存、取消延迟、方向/比例正确性、颜色对照、代理大小/速度和分析数据一致性。

## Acceptance Criteria / 接受标准

LibRaw can move beyond experiment only if:

- It does not regress current gallery, filmstrip, guide, crop mask, and proxy geometry behavior.
- 1024 px RAW preview median latency is competitive with ImageIO/QuickLook or provides clearly better analysis value.
- Peak memory remains bounded under large-folder preheat.
- Orientation and displayed aspect match `PreviewRenderGeometry`.
- Color differences are documented and acceptable for review use.
- Universal macOS packaging remains viable.
- Licensing review confirms the chosen link mode and distribution model are acceptable.
- The same core approach can be reused by the Windows x86 port.

只有在不破坏现有画廊/胶片条/辅助线/遮幅几何、性能和内存可控、方向比例正确、色彩差异可解释、授权和打包可接受，并能服务 Windows 移植时，才应进入正式接入。

## Main Risks / 主要风险

- Licensing: LibRaw has dual licensing considerations. Static linking and commercial distribution need careful review before release.
- Color science: RAW decoding is not merely file reading; white balance, camera matrices, tone curves, demosaic choice, and output profile affect trust.
- Format drift: New camera support depends on LibRaw updates.
- Packaging: macOS universal builds, hardened runtime, and future notarization need repeatable scripts.
- Memory: Full RAW decode can allocate large buffers; background preheat must remain bounded and cancellable.
- Maintenance: Once introduced, RAW backend behavior becomes a product promise.

## Recommended Decision / 建议结论

Proceed with LibRaw evaluation, but treat it as an optional RAW analysis backend first.

建议继续评估 LibRaw，但第一目标是 RAW 分析后端，而不是默认画廊预览后端。

Near-term order:

1. Keep `PreviewDecodeService` as the stable abstraction boundary.
2. Keep `PreviewRasterDecodeProvider` as the backend boundary.
3. Add a standalone LibRaw probe target when dependency packaging is ready.
4. Compare LibRaw against current ImageIO/QuickLook on real folders.
5. Use LibRaw first for RAW clipping map and analysis scopes.
6. Consider optional preview rendering only after visual, performance, memory, and licensing checks pass.

短期顺序：

1. 保持 `PreviewDecodeService` 作为稳定边界。
2. 保持 `PreviewRasterDecodeProvider` 作为后端边界。
3. 先新增独立 LibRaw 探针。
4. 用真实文件夹和当前 ImageIO/QuickLook 路径对照。
5. 优先接入 RAW clipping map 和分析示波器。
6. 只有在画质、速度、内存和授权都通过后，再考虑作为可选预览路径。
