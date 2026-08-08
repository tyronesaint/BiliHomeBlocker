/*
 *  BiliHomeBlocker.xm
 *
 *  功能：隐藏 B 站 App"首页"及搜索页的内容
 *  原理：Hook 具体的内容视图类 layoutSubviews，强制设置 hidden = YES
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#include <objc/runtime.h>

#pragma mark - 通用 hidden 设置器
static void forceHiddenForClass(Class cls, const char *className) {
    if (!cls) {
        NSLog(@"[BiliHomeBlocker] ⚠️ 类 %s 不存在，跳过", className);
        return;
    }

    SEL sel = @selector(layoutSubviews);
    Method origMethod = class_getInstanceMethod(cls, sel);
    if (!origMethod) {
        NSLog(@"[BiliHomeBlocker] ⚠️ %s 没有 layoutSubviews 方法", className);
        return;
    }

    IMP origIMP = method_getImplementation(origMethod);

    IMP newIMP = imp_implementationWithBlock(^(UIView *self) {
        ((void (*)(UIView *, SEL))origIMP)(self, sel);
        self.hidden = YES;
    });

    method_setImplementation(origMethod, newIMP);
    NSLog(@"[BiliHomeBlocker] ✅ %s layoutSubviews 已 hook，hidden 强制为 YES", className);
}

#pragma mark - 构造函数：dylib 加载时立即执行
__attribute__((constructor))
static void BiliHomeBlockerInit() {
    NSLog(@"[BiliHomeBlocker] ✅ dylib 已加载，开始 hook...");

    // 1️⃣ 顶部 Tab 标签栏
    forceHiddenForClass(objc_getClass("BFCTabScrollView"), "BFCTabScrollView");

    // 2️⃣ 首页推荐瀑布流
    forceHiddenForClass(objc_getClass("BBHD2PegasusFeedCollectionView"), "BBHD2PegasusFeedCollectionView");

    // 3️⃣ 直播页内容列表
    forceHiddenForClass(objc_getClass("BBLiveHomeFeed.FeedCollectionView"), "BBLiveHomeFeed.FeedCollectionView");

    // 4️⃣ 频道页 Banner 轮播图
    forceHiddenForClass(objc_getClass("PGCChannelSwift.BannerV3View"), "PGCChannelSwift.BannerV3View");

    // 5️⃣ 频道页内容列表（标准命名）
    forceHiddenForClass(objc_getClass("PGCChannelSwift.ChannelCollectionView"), "PGCChannelSwift.ChannelCollectionView");

    // 6️⃣ 频道页内容列表（带模块前缀的 Swift 类）
    forceHiddenForClass(objc_getClass("bbpgcexposer_PGCChannelSwift.ChannelCollectionView"), "bbpgcexposer_PGCChannelSwift.ChannelCollectionView");

    // 7️⃣ 搜索页热搜列表 Cell
    forceHiddenForClass(objc_getClass("BBHD2SearchSwift.SearchHotListCell"), "BBHD2SearchSwift.SearchHotListCell");

    NSLog(@"[BiliHomeBlocker] ✅ 所有 hook 完成");
}
