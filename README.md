# BiliHomeBlocker

一个独立的 iOS tweak，**隐藏 B 站 App 的"首页"内容区和顶部 Tab 栏**。

通过 FLEX 调试工具精确定位到两个关键视图，在它们每次布局时强制设置 `hidden = YES`，彻底、稳定、一劳永逸。

## 原理（基于 FLEX 调试）

通过 FLEX 查看 B 站 App 的视图层次结构，精确定位到两个关键视图：

| 视图类名 | 作用 | 位置 |
|---------|------|------|
| `BBHD2PegasusFeedCollectionView` | 首页内容瀑布流 / 推荐列表 | `HomeViewController` → `BFCPageScrollView` 下 |
| `BFCTabScrollView` | 顶部分类标签滚动栏（直播/推荐/热门/追番等） | `HomeTopBar` 下，frame `{(532, 20), (325, 49)}` |

### 为什么不用 Hook 网络请求了？

之前的方案尝试 Hook `BFCRequest` 和 `NSURLSession` 拦截 `tab/v2` 接口回包，但：
- B 站接口字段和路由可能随版本变化
- 网络层 Hook 点可能不生效或与其他 tweak 冲突
- 无法 100% 保证覆盖所有请求路径

**新方案的优势：**
- ✅ 直接操作 UI 视图，与网络层无关，不受接口变化影响
- ✅ 通过 FLEX 验证，目标视图 100% 存在且可定位
- ✅ 在 `layoutSubviews` 中设置 `hidden`，每次布局自动生效
- ✅ 代码极简，仅 50 行核心逻辑，维护成本极低

## Hook 架构

```
┌─────────────────────────────────────────────────────────────┐
│  dylib 加载（constructor）                                  │
│  ├─ 获取 BBHD2PegasusFeedCollectionView 的 Class            │
│  │   └─ 替换 layoutSubviews IMP                             │
│  │      └─ 调用原方法 → [self setHidden:YES]                │
│  └─ 获取 BFCTabScrollView 的 Class                          │
│      └─ 替换 layoutSubviews IMP                             │
│         └─ 调用原方法 → [self setHidden:YES]                │
└─────────────────────────────────────────────────────────────┘
```

## 文件结构

```
BiliHomeBlocker/
├── Makefile                       # Theos 编译配置
├── Tweak.xm                       # 核心代码（约 50 行）
├── BiliHomeBlocker.plist          # 注入过滤器（tv.danmaku.bilianime）
├── control                        # Theos 打包 deb 必需
├── .github/workflows/build.yml    # GitHub Actions 自动编译
├── README.md                      # 本文件
└── .gitignore
```

## 本地编译

需要 macOS + Xcode + Theos：

```bash
# 安装 Theos（如未安装）
git clone --recursive https://github.com/theos/theos.git $HOME/theos
export THEOS=$HOME/theos
export PATH=$PATH:$THEOS/bin

# 编译
cd BiliHomeBlocker
make clean
make
# 产物：.theos/obj/debug/BiliHomeBlocker.dylib

# 打包 deb
make package
# 产物：packages/*.deb
```

## GitHub Actions 自动编译

1. 把本项目 push 到 GitHub 仓库
2. 进入 Actions 页面，手动触发 `Build BiliHomeBlocker`
3. 下载产物：
   - `BiliHomeBlocker-dylib`（非越狱注入用）
   - `BiliHomeBlocker-deb`（越狱直接装）

## 注入到 B 站 App

### 方式一：越狱设备

```bash
# 复制 dylib + plist 到 substrate 目录
scp BiliHomeBlocker.dylib BiliHomeBlocker.plist \
    root@device:/Library/MobileSubstrate/DynamicLibraries/

# 或装 deb 包
dpkg -i BiliHomeBlocker_2.0.0_iphoneos-arm64.deb
```

### 方式二：非越狱（Sideload）

1. **砸壳**：用 frida-ios-dump 对 B 站 App 砸壳，得到 `bili-universal.app`
2. **注入 dylib**：
   ```bash
   optool install -c load \
     -p "@executable_path/BiliHomeBlocker.dylib" \
     -t bili-universal.app/bili-universal
   ```
3. **重签名安装**：用 Sideloadly / AltStore 安装到手机

## 验证是否生效

装好后打开 B 站 App：

- ✅ 首页内容区（推荐视频/瀑布流）完全空白/消失
- ✅ 顶部 Tab 栏（直播/推荐/热门/追番等标签）完全消失
- ✅ 系统日志里能看到：
  ```
  [BiliHomeBlocker] ✅ dylib 已加载，开始 hook...
  [BiliHomeBlocker] ✅ BBHD2PegasusFeedCollectionView layoutSubviews 已 hook，hidden 强制为 YES
  [BiliHomeBlocker] ✅ BFCTabScrollView layoutSubviews 已 hook，hidden 强制为 YES
  [BiliHomeBlocker] ✅ 所有 hook 完成，首页内容 + Tab 栏已隐藏
  ```

## 注意事项

- 仅用于学习研究，请勿用于商业用途
- 如果 B 站 App 更新后类名发生变化（如 `BBHD2PegasusFeedCollectionView` 改名），需要更新 `Tweak.xm`
- 可通过 FLEX 重新定位新类名，修改后重新编译即可
- `control` 文件里的 `Package`/`Maintainer`/`Author` 改成你自己的信息

## 技术细节

### 为什么选 `layoutSubviews` 作为 Hook 点？

- `layoutSubviews` 是 UIView 的标准方法，每次视图布局都会调用
- 在 `layoutSubviews` 中设置 `hidden` 可以覆盖任何后续代码对 `hidden` 属性的修改
- 即使 B 站的业务代码在某个时机把 `hidden` 设为 `NO`，下一次布局时又会变回 `YES`
- 比 Hook `setHidden:` 更可靠，因为某些代码可能直接修改 `_hidden` ivar

### 为什么用 `imp_implementationWithBlock` 而不是 `%hook`？

- 这两个类不是标准的 UIView 子类需要特殊处理
- `imp_implementationWithBlock` + `method_setImplementation` 更轻量，不需要 Logos 语法
- 直接在 `constructor` 中执行，dylib 加载即生效，不依赖任何 ViewController 生命周期
