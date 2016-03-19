//
//  CDPVideoPlayer.h
//  player
//
//  Created by CDP on 16/3/2.
//  Copyright © 2016年 CDP. All rights reserved.
//

//https://github.com/cdpenggod/CDPVideoPlayer
//--------------------------------------说明---------------------------------------------------
//如果使用切换全屏功能,且项目Targets设置中Device Orientation未开启横屏选项,则在对应的viewController里添加
//-(BOOL)shouldAutorotate{
//    return !_player.isSwitch;
//}
//如果有navigationController控制器,则要在相应的navigationController里添加以下方法,并且在-(void)switchSizeClick回调中判断是否全屏来隐藏navigationBar
//-(BOOL)shouldAutorotate{
//    return self.topViewController.shouldAutorotate;
//}
////如果有tabBarController控制器,则要在相应的tabBarController里添加以下方法
//- (BOOL)shouldAutorotate{
//    return self.selectedViewController.shouldAutorotate;
//}

//如果使用切换全屏功能,而以上添加方法满足不了需求或项目Targets设置中Device Orientation开启了横屏选项,则以上添加方法的内容可能需要根据自己情况做不同的适配
//而且可能需要用到以下两个方法,具体情况请自行分析
//-(NSUInteger)supportedInterfaceOrientations;
//-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

//如果使用切换全屏功能,且使用了自定义UI,可以在切换全屏方法里添加以下判断,防止连续点击切换按钮出现bug
//if(isSwitch==YES){
//    return;
//}


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef enum{
    CDPVideoPlayerReadyPlay=0,//可以播放
    CDPVideoPlayerPlay,//开始播放
    CDPVideoPlayerPause,//暂停
    CDPVideoPlayerBuffer,//停顿缓冲
    CDPVideoPlayerEnd,//播放结束
    CDPVideoPlayerFailed,//播放失败
    CDPVideoPlayerUnknown,//未知
}CDPVideoPlayerStatus;



@protocol CDPVideoPlayerDelegate <NSObject>
@optional

//播放结束
-(void)playFinishedWithItem:(AVPlayerItem *)item;

//更新播放状态
-(void)updatePlayerStatus:(CDPVideoPlayerStatus)status;

//更新播放进度(currentTime目前播放时间,total总播放时间)
-(void)updateProgressWithCurrentTime:(CGFloat)currentTime totalTime:(CGFloat)totalTime;

//更新缓冲进度(startTime本次缓冲的起始时间,duration本次缓冲获得的时长,totalBuffer已获得的总缓冲时间)
-(void)updateBufferWithStartTime:(CGFloat)startTime duration:(CGFloat)duration totalBuffer:(NSTimeInterval)totalBuffer;

//单击显示上下导航栏时回调
-(void)showBar;

//单击隐藏上下导航栏时回调
-(void)hideBar;

//双击回调(默认UI时相当于点击了一次切换全屏按钮并会触发-(void)switchSizeClick回调)
-(void)doubleClick;

//横向拖动屏幕手势回调
-(void)panGR:(UIPanGestureRecognizer *)pan;

//非全屏下返回键点击回调(仅限默认UI)
-(void)back;

//每次点击切换全屏键回调(仅限默认UI)
-(void)switchSizeClick;

@end




@interface CDPVideoPlayer : UIView



//AVPlayer播放器对象(如不会用,最好不要调用)
@property (nonatomic,strong) AVPlayer *player;

//播放状态
@property (nonatomic,assign,readonly) CDPVideoPlayerStatus status;

//切换\取消全屏状态
//如要使用全屏,必须要用isSwitch判断,并且在info.plist里面加入View controller-based status bar appearance后设置为NO
//并且在全屏模式下点击返回应为取消全屏效果，而不是退出对应viewController

@property (nonatomic,assign) BOOL isFullScreen;


//用来判断是否正在切换全屏中
@property (nonatomic,assign,readonly) BOOL isSwitch;

//用来判断是否正在切换上下导航栏状态(仅限默认UI)
@property (nonatomic,assign,readonly) BOOL changeBar;

//标题(仅限默认UI)
@property (nonatomic,strong) NSString *title;

//当前播放时间
@property (nonatomic,assign,readonly) CGFloat currentTime;

//总播放时间
@property (nonatomic,assign,readonly) CGFloat totalTime;

@property (nonatomic,weak) id <CDPVideoPlayerDelegate> delegate;

//初始化
//frame高度最好大过200,haveOriginalUI是否创建默认交互UI
-(instancetype)initWithFrame:(CGRect)frame url:(NSString *)url delegate:(id <CDPVideoPlayerDelegate>)delegate haveOriginalUI:(BOOL)haveOriginalUI;

//播放并判断是否重新加载当前url资源
-(void)play;

//暂停
-(void)pause;

//关闭播放器并销毁当前播放view
//一定要在退出时使用,否则内存可能释放不了
-(void)close;

//改变当前播放时间到time
-(void)seeTime:(CGFloat)time;




@end
