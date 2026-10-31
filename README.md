# 美化工具箱（MeihuaToolbox）

iOS 美化素材制作工具：图标包、气泡、背景、百度 iOS 键盘皮肤、切图。原生 SwiftUI 实现，所有处理都在手机本地完成。

## 安装

GitHub Actions 每次推送到 `main` 都会编译一个未签名的 IPA（产物名 `MeihuaToolbox-ipa`），用自签工具签名后安装。系统要求 iOS 17 及以上。

处理结果保存在「文件」App › 我的 iPhone › 美化工具箱 › 输出。

## 工具

| 分类 | 工具 |
|---|---|
| 图片 | 改尺寸（含 11xr 机型档）、去除背景、批量水印、暗标打标与查询 |
| 图标 | 一键图标配套、一键图标对位、自定义对标、图标改色、图标批量改色 |
| 切图 | 素材切割、CSS 精灵图切割、键盘图片分割与拼接 |
| 气泡与背景 | 红包气泡、一键背景配套 |
| 键盘皮肤（百度 iOS `.bdi`） | 顶栏替换、皮肤改色、安卓 `.bds` 与 iOS `.bdi` 互转 |

「11xr」指 iPhone 11 / XR 这一档（828×1792，2 倍图）。全面屏机型里只有它是 2 倍图，所以要单独出一套。

改好的键盘皮肤用分享面板选「用百度输入法打开」导入。App 不会直接写入其他 App 的数据。

## 目录

```
project.yml                 XcodeGen 工程描述（.xcodeproj 不入库，CI 现生成）
App/                        SwiftUI 界面
  Common/                   共用：ToolSession、导入导出、结果区
  Home/                     首页与工具目录
  Tools/<分类>/             各工具页面
Packages/MeihuaCore/        纯算法与文件格式（不依赖 UIKit，可在 macOS 上跑单元测试）
.github/workflows/build.yml 单元测试 + 编译 + 打包 IPA
```

## 开发

```bash
# 核心模块单元测试（macOS）
cd Packages/MeihuaCore && swift test

# 生成工程并编译（需要 XcodeGen 2.46.0）
xcodegen generate
xcodebuild -project MeihuaToolbox.xcodeproj -scheme MeihuaToolbox \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

第三方依赖只有 [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 0.9.20（MIT），版本锁死在 `Packages/MeihuaCore/Package.swift`。