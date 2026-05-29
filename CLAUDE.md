# CalBro 项目说明

## 沟通语言

**与用户沟通一律使用中文。**

---

## 项目定位

原生 SwiftUI iPhone app(iOS 26),从一张俯拍食物照片 **完全离线** 估算卡路里与宏量营养素。
部署 **DPF-Nutrition** 模型(Han et al., *Foods* 2023, arXiv:2310.11702 — 单目 RGB→预测深度→RGB-D 融合),
**不是** CVPR 2021 Nutrition5k 架构。配套研究仓库:[T0MYYY/nutrition5k-calorie-estimation-adsp31018](https://github.com/T0MYYY/nutrition5k-calorie-estimation-adsp31018)。

- 2026-05-28 改名:CalBuddy → **CalBro**(避免与同名项目冲突)。
- Project = `CalBro.xcodeproj`,scheme = `CalBro`,targets = `CalBro` / `CalBroTests` / `CalBroWidgetExtension`。
- Bundle id:`com.wydfcc.calbro`;widget `com.wydfcc.calbro.CalBroWidget`;App Group `group.com.wydfcc.calbro`。
- GitHub:https://github.com/T0MYYY/calbro

---

## 构建

```bash
# 模拟器
xcodebuild -project CalBro.xcodeproj -scheme CalBro \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# 真机(automatic signing 自动注册 App Group + HealthKit + widget)
xcodebuild -project CalBro.xcodeproj -scheme CalBro \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

- pbxproj 是 **objectVersion 77、手工编辑**;widget target 是手加进 pbxproj 的——**用 `project.yml` 重新生成(xcodegen)会丢掉 widget target**,不要覆盖。
- Capabilities:App Groups、HealthKit、Camera、User Notifications、WidgetKit。

---

## Core ML 管线(关键)

DA2(深度估计)→ DPF(营养回归):

- **DA2** `DepthAnythingV2SmallF16P6.mlpackage`:输入 `image`(CVPixelBuffer BGRA)→ 输出 `depth`(GRAYSCALE_FLOAT16 CVPixelBuffer)。
- **DPF** `DPFNutritionRGBDepth.mlpackage`:输入 `rgb` [1,3,336,448] float16 + `depth` [1,1,336,448] float16 → `nutrition` [1,5] float16 = [calories, mass, fat, carb, protein]。
- 模型放 `CalBro/Resources/Models/`,**git-ignored**(DPF weight.bin ~173MB > GitHub 100MB 限制,且无 git-lfs)。见 `CalBro/Resources/Models/MODELS.md`;可从 HF [`T0MYYY/dpf-nutrition`](https://huggingface.co/T0MYYY/dpf-nutrition) 下载(含 coreml 两个 .mlpackage)。构建需本地存在。

---

## 踩过的坑(读最终代码读不出来的复盘)

1. **always-450kcal bug**:`MLModel` 首次编译要 30–60s,旧代码只等 500ms 就 fallback 到 450。修复:加载存成 `Task<LoadedModels?, Never>`,`predictNutrition` 里 `await loadingTask.value`。
2. **深度转换**:DA2 输出 GRAYSCALE_FLOAT16 CVPixelBuffer 直接读不稳;经 `CIContext` 渲染成 BGRA 再读 R 通道(跨版本可靠)。
3. **LiDAR/深度采集**:`CameraCaptureController` 必须用 DiscoverySession 选 `.builtInLiDARDepthCamera`(挑 `supportedDepthDataFormats` 非空的);普通 `.builtInWideAngleCamera` **没有深度**。还要设 `device.activeDepthDataFormat`(Float32),否则深度 delegate 不触发。高度门控(27–34cm)依赖它。
4. **日历崩溃**:`ForEach(viewModel.weeks.indices, id:\.self)` 遍历**计算属性** + `weeks[week][index]` → 月份切换行数 5↔6 时数组越界。修复:`CalendarDayModel: Identifiable` 网格、`let weeks` 捕获一次、按 identity 遍历。
5. **暗色对比 bug(系统性)**:`CBColors.ink` 暗色下接近白(0xf7f7f2),当**填充**配白字 = 隐形。**规则:绝不用 `CBColors.ink` 当填充背景,用 `controlFill` / `controlOnFill`。**
6. **swipeActions 不触发**:在 ScrollView+VStack 里 `.swipeActions` 不生效;`LoggedMealRow` 改用内联 `Menu` + `contextMenu`。
7. **截图技巧**(无 UI 自动化工具时):seed UserDefaults 跳过 onboarding;`xcrun simctl spawn <udid> defaults import com.wydfcc.calbro <plist>`(直接写 plist 有缓存,要走 `defaults import` / cfprefsd);`simctl ui <udid> appearance dark|light`;meal 时间戳要用**分钟级**(host 是 CDT,小时级会跨午夜被 `isDateInToday` 过滤掉)。

---

## 架构地图

- `NutritionPredictionService.swift` — Core ML 管线(Task-based 加载)
- `CameraCaptureController.swift` / `CameraFlowViewModel.swift` — LiDAR 选择 + Phase(scanning→aiming→countdown→processing→result)+ CMMotion tilt + 高度门控(27–34cm,`HeightGuidanceBar` 无单位进度条)
- `MealLogStore.swift` — `@Observable` 单例,UserDefaults key `calbro.meals.v1`,60 天窗口,log/update/remove,`syncWidget()` 写 App Group
- `UserProfile.swift` — Mifflin-St Jeor BMR/TDEE,`recalculateTargets()`;`UnitSystem { metric, imperial }` + `heightDisplay`/`weightDisplay` 助手(卡路里恒为 kcal)
- `Shared/SharedNutrition.swift` — App Group 桥(app + widget 双 target):`WidgetNutritionSnapshot` + `SharedNutritionStore`
- `CalBroWidget/` — TimelineProvider + systemSmall/Medium + accessoryCircular/Rectangular,自带调色板(不依赖 app DesignSystem)
- `RealHealthKitSyncService` / `RealReminderService` — HealthKit 读 bodyMass/height/DOB/sex/activeEnergy 回填 profile;本地通知;`IntegrationViewModel` 用 `#if targetEnvironment(simulator)` Mock / Real 切换
- UI:原生 iOS 26 `TabView { Tab(...) }` Liquid Glass;相机 tab `.toolbar(.hidden, for: .tabBar)`;无底部 Log tab(Today 的 + FAB → `.fullScreenCover(item:)`)
- 设计系统前缀 `CB`;主色 terra = Indigo(#4338CA light / #818CF8 dark)
- 历史遗留:`appState` key 仍是 `calBuddy.appState.v1`(改名时大小写未命中替换);无已发布用户,无害。

---

## 已知缺口

- Core ML 预测可能仍不准(normalization 是否被应用两次?);**backbone 未针对手机相机标定,输出数值无参考价值**,仅作 UI/架构演示。
- 体重历史/追踪未实现(`PlateauAlertView` 为占位)。

---

## 提交规范

- commit 信息不加 `Co-Authored-By: Claude`。
- git push 前需获得用户明确授权。
