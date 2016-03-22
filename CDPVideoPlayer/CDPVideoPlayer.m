//
//  CDPVideoPlayer.m
//  player
//
//  Created by CDP on 16/3/2.
//  Copyright © 2016年 CDP. All rights reserved.
//

#import "CDPVideoPlayer.h"
#import "CDPButton.h"
#import <MediaPlayer/MediaPlayer.h>

#define CDPSWIDTH   [UIScreen mainScreen].bounds.size.width
#define CDPSHEIGHT  [UIScreen mainScreen].bounds.size.height

//上下导航栏高(全屏时上导航栏高+20)
#define CDPTOPHEIGHT(FullScreen) ((FullScreen==YES)?60:40)
#define CDPFOOTHEIGHT 40

//导航栏上button的宽高
#define CDPButtonWidth 30
#define CDPButtonHeight 30

//导航栏隐藏前所需等待时间
#define CDPHideBarIntervalTime 3

@implementation CDPVideoPlayer{
    AVPlayerLayer *_playerLayer;//播放器layer
    id _playerTimeObserver;
    
    UIView *_bufferView;//缓冲view
    UIActivityIndicatorView *_activityView;//缓冲旋转菊花
    UILabel *_bufferLabel;//缓冲label
    
    UISlider *_volumeSlider;//音量slider
    
    NSTimer *_timer;//计时器
    
    NSString *_urlStr;//视频地址
    
    BOOL _haveOriginalUI;//是否创建默认交互UI
    CGRect _initFrame;
    
    CGFloat _lastShowBarTime;//最后一次导航栏显示时的时间
    BOOL _isShowBar;//导航栏是否显示
    
    UIView *_topBar;//顶部导航栏
    CDPButton *_backButton;//返回button
    UILabel *_titleLabel;//标题
    
    UIView *_footBar;//底部导航栏
    UIButton *_playButton;//播放\暂停button
    UIButton *_switchButton;//切换全屏button
    UILabel *_timeLabel;//时间label
    
    UISlider *_slider;//播放进度条
    BOOL _dragSlider;//是否正在拖动slider
    UIProgressView *_progressView;//缓冲进度条
    
}

-(instancetype)initWithFrame:(CGRect)frame url:(NSString *)url delegate:(id <CDPVideoPlayerDelegate>)delegate haveOriginalUI:(BOOL)haveOriginalUI{
    if (self=[super initWithFrame:frame]) {
        _initFrame=frame;
        _urlStr=url;
        _delegate=delegate;
        _currentTime=0;
        _totalTime=0;
        _isFullScreen=NO;
        _isSwitch=NO;
        _changeBar=NO;
        _lastShowBarTime=0;
        _haveOriginalUI=haveOriginalUI;
        _dragSlider=NO;
        
        //添加手势
        [self addGR];

        [self createUI];
        
        //监控播放器
        [_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
        
        //开始播放
        [self checkAndUpdateStatus:CDPVideoPlayerReadyPlay];
        [_player play];
    }
    return self;
}
-(void)dealloc{
    [_player removeObserver:self forKeyPath:@"rate"];

    [self closePlayer];
    
    if (self.superview) {
        [self removeFromSuperview];
    }
}
//添加手势
-(void)addGR{
    //单击
    UITapGestureRecognizer *tapGR=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGR:)];
    [self addGestureRecognizer:tapGR];
    
    //双击
    UITapGestureRecognizer *doubleGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGR:)];
    doubleGR.numberOfTouchesRequired = 1;
    doubleGR.numberOfTapsRequired = 2;
    [tapGR requireGestureRecognizerToFail:doubleGR];
    [self addGestureRecognizer:doubleGR];
    
    //拖动
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    [self addGestureRecognizer:panGesture];
}
//关闭播放器
-(void)closePlayer{
    
    if (_timer) {
        [_timer invalidate];
        _timer=nil;
    }
    
    [self removeObserver];
    [self removeNotification];
    
    [_player.currentItem cancelPendingSeeks];
    [_player.currentItem.asset cancelLoading];
    
    [_player removeTimeObserver:_playerTimeObserver];
    _playerTimeObserver=nil;
    
    [_player cancelPendingPrerolls];

    [_player replaceCurrentItemWithPlayerItem:nil];
    
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    
    for (CALayer *subLayer in self.layer.sublayers) {
        [subLayer removeFromSuperlayer];
    }
}
//计时器
-(void)timeGo{
    //判断是否隐藏导航栏
    if ([[NSDate date] timeIntervalSince1970]-_lastShowBarTime>=CDPHideBarIntervalTime) {
        [self hideBar];
    }
    else if(_lastShowBarTime==0){
        [self hideBar];
    }
    
    if (_slider) {
        _slider.userInteractionEnabled=(_totalTime==0)?NO:YES;
    }
}
#pragma mark - 通知
//添加通知
-(void)addNotification{
    //添加AVPlayerItem播放结束通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playBackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    
    //添加AVPlayerItem开始缓冲通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bufferStart:) name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
    
}
//移除通知
-(void)removeNotification{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
//播放结束通知回调
-(void)playBackFinished:(NSNotification *)notification{
    
    [self checkAndUpdateStatus:CDPVideoPlayerEnd];
    
    if ([_delegate respondsToSelector:@selector(playFinishedWithItem:)]) {
        [_delegate playFinishedWithItem:notification.object];
    }
}
//缓冲开始回调
-(void)bufferStart:(NSNotification *)notification{
    [self checkAndUpdateStatus:CDPVideoPlayerBuffer];
}
#pragma mark - KVO监控
//给播放器添加进度更新
-(void)addProgressObserver{
    //设置每秒执行一次
    AVPlayerItem *playerItem=_player.currentItem;
    __weak typeof (self) weakSelf=self;
    __weak typeof(_slider) weakSlider=_slider;
    
    _playerTimeObserver=[_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0,1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        CGFloat current=CMTimeGetSeconds(time);
        CGFloat total=CMTimeGetSeconds([playerItem duration]);
        
        if (current) {
            _currentTime=current;
            _totalTime=total;
            
            if (_haveOriginalUI==YES&&weakSlider&&_dragSlider==NO) {
                weakSlider.value=_currentTime/_totalTime;
                
                [weakSelf updateTime:current];
            }
            if ([weakSelf.delegate respondsToSelector:@selector(updateProgressWithCurrentTime:totalTime:)]) {
                [weakSelf.delegate updateProgressWithCurrentTime:current totalTime:total];
            }
        }
    }];
}
//添加KVO监控
-(void)addObserver{
    AVPlayerItem *playerItem=_player.currentItem;
    
    //监控状态属性(AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态)
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    //监控网络加载情况属性
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    //监控是否可播放
    [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
}
//移除KVO监控
-(void)removeObserver{
    [_player.currentItem removeObserver:self forKeyPath:@"status"];
    [_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
}
//通过KVO监控回调
//keyPath 监控属性 object 监视器 change 状态改变 context 上下文
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        //监控是否可播放
        if (_haveOriginalUI==YES&&_bufferView) {
            [self removeBufferView];
        }
        
        if (_status!=CDPVideoPlayerPause&&_status!=CDPVideoPlayerEnd) {
            if (_player.currentItem.playbackLikelyToKeepUp==YES) {
                [self checkAndUpdateStatus:CDPVideoPlayerPlay];
                [_player play];
            }
        }
    }
    else if ([keyPath isEqualToString:@"rate"]) {
        //监控播放器播放速率
        if(_player.rate==1){
            [self checkAndUpdateStatus:CDPVideoPlayerPlay];
        }
    }
    else if ([keyPath isEqualToString:@"status"]) {
        //监控状态属性
        AVPlayerStatus status= [[change objectForKey:@"new"] intValue];
        
        switch (status) {
            case AVPlayerStatusReadyToPlay:{
                _currentTime=CMTimeGetSeconds(_player.currentTime);
                _totalTime=CMTimeGetSeconds([_player.currentItem duration]);
                
                if (status!=CDPVideoPlayerPause) {
                    [self checkAndUpdateStatus:CDPVideoPlayerReadyPlay];
                }
            }
                break;
            case AVPlayerStatusUnknown:{
                [self closePlayer];
                [self checkAndUpdateStatus:CDPVideoPlayerUnknown];
            }
                break;
            case AVPlayerStatusFailed:{
                [self closePlayer];
                [self checkAndUpdateStatus:CDPVideoPlayerFailed];
            }
                break;
        }
    }
    else if([keyPath isEqualToString:@"loadedTimeRanges"]){
        //监控网络加载情况属性
        NSArray *array=_player.currentItem.loadedTimeRanges;
        
        //本次缓冲时间范围
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];
        CGFloat startSeconds = CMTimeGetSeconds(timeRange.start);
        CGFloat durationSeconds = CMTimeGetSeconds(timeRange.duration);
        
        //现有缓冲总长度
        NSTimeInterval totalBuffer = startSeconds + durationSeconds;
        
        if (_haveOriginalUI&&_progressView) {
            [_progressView setProgress:totalBuffer/_totalTime animated:NO];
        }
        if ([_delegate respondsToSelector:@selector(updateBufferWithStartTime:duration:totalBuffer:)]) {
            [_delegate updateBufferWithStartTime:startSeconds duration:durationSeconds totalBuffer:totalBuffer];
        }
    }
}
#pragma mark - 创建UI
-(void)createUI{
    //容器view
    self.backgroundColor=[UIColor blackColor];
    self.userInteractionEnabled=YES;
    
    //播放器
    [self createPlayerWithContainView:self];
    
    //音量
    MPVolumeView *mpVolumeView=[[MPVolumeView alloc] initWithFrame:CGRectMake(50,50,40,40)];
    for (UIView *view in [mpVolumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeSlider=(UISlider*)view;
            break;
        }
    }
    [mpVolumeView setHidden:YES];
    [mpVolumeView setShowsVolumeSlider:YES];
    [mpVolumeView sizeToFit];
}
//创建播放器
-(void)createPlayerWithContainView:(UIView *)containView{
    AVPlayerItem *playerItem=[self getPlayItemWithUrl:_urlStr];
    _player=[AVPlayer playerWithPlayerItem:playerItem];
    
    _playerLayer=[AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.frame=containView.bounds;
    
    //视频填充模式
//    _playerLayer.videoGravity=AVLayerVideoGravityResizeAspect;
    [containView.layer insertSublayer:_playerLayer atIndex:0];
    
    //默认交互UI
    if (_haveOriginalUI==YES) {
        [self createTopBar];
        [self createFootBar];
        [self createBufferView];
    }
    
    //添加KVO监控
    [self addObserver];
    
    //进度监控
    [self addProgressObserver];
    
    //添加通知
    [self addNotification];
    
    //计时器
    if (_timer==nil) {
        _timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeGo) userInfo:nil repeats:YES];
    }
    
}
//根据url获得AVPlayerItem对象
-(AVPlayerItem *)getPlayItemWithUrl:(NSString *)urlStr{
    //对url进行编码
    //    urlStr =[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url=[NSURL URLWithString:urlStr];
    AVPlayerItem *playerItem=[AVPlayerItem playerItemWithURL:url];
    return playerItem;
}
//创建缓冲view
-(void)createBufferView{
    _bufferView=[[UIView alloc] initWithFrame:CGRectMake(_initFrame.size.width/2-60,_initFrame.size.height/2-30,120,60)];
    _bufferView.backgroundColor=[UIColor blackColor];
    _bufferView.alpha=0.7;
    _bufferView.layer.cornerRadius=10;
    _bufferView.layer.masksToBounds=YES;
    
    //缓冲旋转菊花
     _activityView=[[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(_bufferView.frame.origin.x+41,_bufferView.frame.origin.y+1,38,38)];
    [_activityView stopAnimating];
    
    //缓冲label
    _bufferLabel=[[UILabel alloc] initWithFrame:CGRectMake(_bufferView.frame.origin.x,CGRectGetMaxY(_activityView.frame),120,20)];
    _bufferLabel.textColor=[UIColor whiteColor];
    _bufferLabel.textAlignment=NSTextAlignmentCenter;
    _bufferLabel.font=[UIFont systemFontOfSize:16];
    _bufferLabel.text=@"加 载 中...";
}
//创建topBar
-(void)createTopBar{
    if (_topBar==nil) {
        _topBar=[[UIView alloc] initWithFrame:CGRectMake(0,0,_initFrame.size.width,CDPTOPHEIGHT(NO))];
        _topBar.backgroundColor=[UIColor blackColor];
        _topBar.alpha=0.5;
        _topBar.userInteractionEnabled=YES;
        [self addSubview:_topBar];
        
        //返回
        _backButton=[[CDPButton alloc] initWithFrame:CGRectMake(5,_topBar.frame.origin.y+CDPTOPHEIGHT(NO)/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight)
                                                     imageRect:CGRectMake(CDPButtonWidth/2-4,CDPButtonHeight/2-8,8,16)
                                                     titleRect:CGRectZero];
        [_backButton addTarget:self action:@selector(backClick) forControlEvents:UIControlEventTouchUpInside];
        [_backButton setImage:[UIImage imageNamed:@"CDPBack"] forState:UIControlStateNormal];
        [self addSubview:_backButton];
        
        //标题
        _titleLabel=[[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxY(_backButton.frame),_topBar.frame.origin.y,_topBar.frame.size.width-CGRectGetMaxY(_backButton.frame)-5,CDPTOPHEIGHT(NO))];
        _titleLabel.textColor=[UIColor whiteColor];
        _titleLabel.font=[UIFont systemFontOfSize:14];
        [self addSubview:_titleLabel];
    }
}
//创建footBar
-(void)createFootBar{
    if (_footBar==nil) {
        _footBar=[[UIView alloc] initWithFrame:CGRectMake(0,_initFrame.size.height-CDPFOOTHEIGHT,_initFrame.size.width,CDPFOOTHEIGHT)];
        _footBar.backgroundColor=[UIColor blackColor];
        _footBar.alpha=0.5;
        _footBar.userInteractionEnabled=YES;
        [self addSubview:_footBar];
        
        //播放\暂停
        _playButton=[[UIButton alloc] initWithFrame:CGRectMake(5,_footBar.frame.origin.y+CDPFOOTHEIGHT/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight)];
        [_playButton addTarget:self action:@selector(playOrPause) forControlEvents:UIControlEventTouchUpInside];
        [_playButton setImage:[UIImage imageNamed:@"CDPPlay"] forState:UIControlStateNormal];
        [_playButton setImage:[UIImage imageNamed:@"CDPPause"] forState:UIControlStateSelected];
        [self addSubview:_playButton];
        
        //切换全屏
        _switchButton=[[UIButton alloc] initWithFrame:CGRectMake(_footBar.frame.size.width-35,_footBar.frame.origin.y+CDPFOOTHEIGHT/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight)];
        [_switchButton addTarget:self action:@selector(switchClick) forControlEvents:UIControlEventTouchUpInside];
        [_switchButton setImage:[UIImage imageNamed:@"CDPZoomIn"] forState:UIControlStateNormal];
        [_switchButton setImage:[UIImage imageNamed:@"CDPZoomOut"] forState:UIControlStateSelected];
        [self addSubview:_switchButton];
        
        //时间
        _timeLabel=[[UILabel alloc] initWithFrame:CGRectMake(_switchButton.frame.origin.x-80,_footBar.frame.origin.y,80,CDPFOOTHEIGHT)];
        _timeLabel.textAlignment=NSTextAlignmentCenter;
        _timeLabel.text=@"00:00/00:00";
        _timeLabel.font=[UIFont systemFontOfSize:10];
        _timeLabel.numberOfLines=0;
        _timeLabel.textColor=[UIColor whiteColor];
        [self addSubview:_timeLabel];
        
        //缓冲进度条
        _progressView=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.frame=CGRectMake(CGRectGetMaxX(_playButton.frame),_footBar.frame.origin.y+CDPFOOTHEIGHT/2,CGRectGetMinX(_timeLabel.frame)-CGRectGetMaxX(_playButton.frame),2);
        _progressView.progressTintColor=[UIColor lightGrayColor];
        _progressView.trackTintColor=[UIColor darkGrayColor];
        [self insertSubview:_progressView belowSubview:_playButton];
        
        //进度条
        _slider=[[UISlider alloc] initWithFrame:CGRectMake(_progressView.frame.origin.x-2,_progressView.frame.origin.y-14,_progressView.bounds.size.width+2,30)];
        [_slider setThumbImage:[UIImage imageNamed:@"CDPSlider"] forState:UIControlStateNormal];
        _slider.minimumTrackTintColor=[UIColor whiteColor];
        _slider.maximumTrackTintColor=[UIColor clearColor];
        [_slider addTarget:self action:@selector(sliderChange) forControlEvents:UIControlEventValueChanged];
        [_slider addTarget:self action:@selector(sliderChangeEnd) forControlEvents:UIControlEventTouchUpInside];
        [self insertSubview:_slider aboveSubview:_progressView];
    }
}
#pragma mark - CDPVideoPlayer外部交互
//播放
-(void)play{
    //记录最后一次显示开始时间
    _lastShowBarTime=[[NSDate date] timeIntervalSince1970];
    
    if (_player.currentItem==nil) {
        _currentTime=0;
        _totalTime=0;
        [self createPlayerWithContainView:self];
    }
    [_player play];
    [self checkAndUpdateStatus:CDPVideoPlayerPlay];
}
//暂停
-(void)pause{
    //记录最后一次显示开始时间
    _lastShowBarTime=[[NSDate date] timeIntervalSince1970];
    
    [_player pause];
    [self checkAndUpdateStatus:CDPVideoPlayerPause];
}
//关闭播放器并销毁当前播放view
-(void)close{
    [self closePlayer];
    for (UIGestureRecognizer *gr in self.gestureRecognizers) {
        [self removeGestureRecognizer:gr];
    }
    if (self.superview) {
        [self removeFromSuperview];
    }
}
//切换\取消全屏状态
-(void)setIsFullScreen:(BOOL)isFullScreen{
    //记录最后一次显示开始时间
    _lastShowBarTime=[[NSDate date] timeIntervalSince1970];
    
    if (_isSwitch==YES) {
        return;
    }
    _isFullScreen=isFullScreen;
    
    _isSwitch=YES;
    if (_isFullScreen==YES) {
        //全屏
        [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight];

        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformMakeRotation(M_PI_2);
            [self updateFrame];
        }completion:^(BOOL finished) {
            _isSwitch=NO;
        }];
    }
    else{
        //非全屏
        [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait];

        [UIView animateWithDuration:0.3 animations:^{
            self.transform=CGAffineTransformIdentity;
            [self updateFrame];
        }completion:^(BOOL finished) {
            _isSwitch=NO;
        }];
    }
}
//改变当前播放时间到time
-(void)seeTime:(CGFloat)time{
    [_player seekToTime:CMTimeMakeWithSeconds(time,1) completionHandler:^(BOOL finished) {
        
    }];
}
#pragma mark - 更新
//检查并更新播放器状态
-(void)checkAndUpdateStatus:(CDPVideoPlayerStatus)newStatus{
    if (_status!=newStatus) {
        _status=newStatus;
        
        //判断进行默认UI交互
        if (_haveOriginalUI==YES) {
            switch (_status) {
                case CDPVideoPlayerReadyPlay:{
                    //可播放
                    [self removeBufferView];
                }
                    break;
                case CDPVideoPlayerPlay:{
                    //开始播放
                    _playButton.selected=YES;
                    [self removeBufferView];
                }
                    break;
                case CDPVideoPlayerPause:{
                    //暂停
                    _playButton.selected=NO;
                }
                    break;
                case CDPVideoPlayerBuffer:{
                    //缓冲
                    _playButton.selected=YES;
                    [self showBufferView];
                }
                    break;
                case CDPVideoPlayerEnd:{
                    //播放结束
                    _playButton.selected=NO;
                    [self removeBufferView];
                }
                    break;
                case CDPVideoPlayerUnknown:{
                    //播放失败
                    _playButton.selected=NO;
                    [self removeBufferView];
                }
                    break;
                case CDPVideoPlayerFailed:{
                    //未知
                    _playButton.selected=NO;
                    [self removeBufferView];
                }
                    break;
            }
        }
        
        if ([_delegate respondsToSelector:@selector(updatePlayerStatus:)]) {
            [_delegate updatePlayerStatus:_status];
        }
    }
}
//更新播放器frame
-(void)updateFrame{
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    if (_isFullScreen==YES) {
        //全屏
        NSInteger systemVersion=[[UIDevice currentDevice].systemVersion integerValue];
        self.frame=(systemVersion<8.0&&systemVersion>=7.0)?CGRectMake(0,0,CDPSWIDTH,CDPSHEIGHT):CGRectMake(0,0,CDPSHEIGHT,CDPSWIDTH);
        _playerLayer.frame=self.bounds;
        self.center=self.window.center;
        
        if (_haveOriginalUI==YES&&_topBar&&_footBar) {
            [self restoreOrChangeAlpha:YES];
            
            [self restoreOrChangeFrame:NO];
            
            _switchButton.selected=YES;
        }
    }
    else{
        //非全屏
        self.frame=_initFrame;
        _playerLayer.frame=self.bounds;
        
        if (_haveOriginalUI==YES&&_topBar&&_footBar) {
            [self restoreOrChangeTransForm:YES];
            
            [self restoreOrChangeFrame:YES];
            
            _switchButton.selected=NO;
        }
    }
}
#pragma mark - 手势点击
//单双击
-(void)tapGR:(UITapGestureRecognizer *)tapGR{
    if(tapGR.numberOfTapsRequired == 2) {
        //双击
        if ([_delegate respondsToSelector:@selector(doubleClick)]) {
            [_delegate doubleClick];
        }
        if (_haveOriginalUI==YES) {
            [self switchClick];
        }
    }
    else{
        //单击
        if (_isShowBar==YES) {
            [self hideBar];
        }
        else{
            [self showBar];
        }
    }
}
//拖动
- (void)panGesture:(UIPanGestureRecognizer *)panGR{
    if(panGR.numberOfTouches>1) {
        return;
    }
    CGPoint translationPoint=[panGR translationInView:self];
    [panGR setTranslation:CGPointZero inView:self];
    
    CGFloat x=translationPoint.x;
    CGFloat y=translationPoint.y;
    
    if ((x==0&&fabs(y)>=5)||fabs(y)/fabs(x)>=3) {
        //上下调节音量
        if (_dragSlider==YES) {
            return;
        }
        CGFloat ratio = ([[UIDevice currentDevice].model rangeOfString:@"iPad"].location != NSNotFound)?20000.0f:13000.0f;
        CGPoint velocity = [panGR velocityInView:self];
        
        CGFloat nowValue = _volumeSlider.value;
        CGFloat changedValue = 1.0f * (nowValue - velocity.y / ratio);
        if(changedValue < 0) {
            changedValue = 0;
        }
        if(changedValue > 1) {
            changedValue = 1;
        }
        
        [_volumeSlider setValue:changedValue animated:YES];
        
        [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
    else{
        if ([_delegate respondsToSelector:@selector(panGR:)]) {
            [_delegate panGR:panGR];
        }
        if (_haveOriginalUI==YES){
            //默认UI左右拖动调节进度
            if((y==0&&fabs(x)>=5)||fabs(x)/fabs(y)>=3) {
                if (_totalTime==0) {
                    return;
                }
                if (_player.rate==1||_status!=CDPVideoPlayerPause) {
                    [_player pause];
                }
                _dragSlider=YES;
                
                _slider.value=_slider.value+(x/self.bounds.size.width);

                [self seeTime:_slider.value*_totalTime];
                [self updateTime:_slider.value*_totalTime];
            }
            if (panGR.state==UIGestureRecognizerStateEnded) {
                //拖动手势结束
                _dragSlider=NO;
                
                if (_status!=CDPVideoPlayerPause) {
                    [_player play];
                }
            }
        }
    }
}
#pragma mark - 默认UI交互
//显示缓冲view
-(void)showBufferView{
    [_activityView startAnimating];
    
    if (_bufferView.superview==nil) {
        [self addSubview:_bufferView];
    }
    if (_activityView.superview==nil) {
        [self addSubview:_activityView];
    }
    if (_bufferLabel.superview==nil) {
        [self addSubview:_bufferLabel];
    }
}
//隐藏缓冲view
-(void)removeBufferView{
    [_activityView stopAnimating];

    [_bufferView removeFromSuperview];
    [_activityView removeFromSuperview];
    [_bufferLabel removeFromSuperview];
}
//设置标题
-(void)setTitle:(NSString *)title{
    _title=title;
    if (_titleLabel) {
        _titleLabel.text=_title;
    }
}
//返回
-(void)backClick{
    //记录最后一次显示开始时间
    _lastShowBarTime=[[NSDate date] timeIntervalSince1970];
    
    if (_isFullScreen==YES) {
        //取消全屏
        [self switchClick];
    }
    else{
        //返回
        if ([_delegate respondsToSelector:@selector(back)]) {
            [_delegate back];
        }
    }
}
//播放、暂停
-(void)playOrPause{
    if(_playButton.selected==NO){
        //开始播放
        if (_status==CDPVideoPlayerEnd) {
            [self seeTime:1];
            [self updateTime:1];
        }
        [self play];
        _playButton.selected=YES;
    }
    else{
        //暂停播放
        [self pause];
        _playButton.selected=NO;
    }
}
//切换\取消全屏状态
-(void)switchClick{
    self.isFullScreen=!_isFullScreen;
    
    if ([_delegate respondsToSelector:@selector(switchSizeClick)]) {
        [_delegate switchSizeClick];
    }
}
//拖动slider时,改变当前播放时间
-(void)sliderChange{
    if (_totalTime==0) {
        return;
    }
    _dragSlider=YES;
    
    [self seeTime:_slider.value*_totalTime];
    
    [self updateTime:_slider.value*_totalTime];
}
//拖动slider后
-(void)sliderChangeEnd{
    _dragSlider=NO;
}
//更新播放时间
-(void)updateTime:(CGFloat)playTime{
    NSInteger a=playTime/60;
    NSInteger b=_totalTime/60;
    NSInteger c=playTime-a*60;
    NSInteger d=_totalTime-b*60;
    
    if (_timeLabel) {
        _timeLabel.text=[NSString stringWithFormat:@"%d:%02d/%d:%02d",a,c,b,d];
    }
}
//显示导航栏
-(void)showBar{
    //记录最后一次显示开始时间
    _lastShowBarTime=[[NSDate date] timeIntervalSince1970];
    if (_isShowBar==YES||_changeBar==YES) {
        return;
    }
    _isShowBar=YES;
    [[UIApplication sharedApplication] setStatusBarHidden:NO];

    if ([_delegate respondsToSelector:@selector(showBar)]) {
        [_delegate showBar];
    }
    if (_haveOriginalUI==YES&&_changeBar==NO) {
        _changeBar=YES;
        [UIApplication sharedApplication].statusBarStyle=UIStatusBarStyleLightContent;
        
        [UIView animateWithDuration:0.3 animations:^{
            [self restoreOrChangeAlpha:YES];
            
            [self restoreOrChangeTransForm:YES];
            
        }completion:^(BOOL finished) {
            _changeBar=NO;
        }];
    }
    
}
//隐藏导航栏
-(void)hideBar{
    if (_isShowBar==NO||_changeBar==YES) {
        return;
    }
    _isShowBar=NO;
    if (_isFullScreen==YES) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }
    if ([_delegate respondsToSelector:@selector(hideBar)]) {
        [_delegate hideBar];
    }
    if (_haveOriginalUI==YES&&_changeBar==NO) {
        _changeBar=YES;

        [self restoreOrChangeTransForm:YES];
        
        [UIView animateWithDuration:0.3 animations:^{
            if (_isFullScreen==YES) {
                [self restoreOrChangeTransForm:NO];
                
                [self restoreOrChangeAlpha:YES];
            }
            else{
                [self restoreOrChangeAlpha:NO];
            }
        }completion:^(BOOL finished) {
            _changeBar=NO;
        }];
    }
}
//恢复或改变transForm
-(void)restoreOrChangeTransForm:(BOOL)restore{
    CGAffineTransform oriTransform=CGAffineTransformIdentity;
    CGAffineTransform topTransform=CGAffineTransformMakeTranslation(0,-_topBar.bounds.size.height);
    CGAffineTransform footTransform=CGAffineTransformMakeTranslation(0,_footBar.bounds.size.height);
    
    if (restore==YES) {
        _topBar.transform=oriTransform;
        _backButton.transform=oriTransform;
        _titleLabel.transform=oriTransform;
        
        _footBar.transform=oriTransform;
        _playButton.transform=oriTransform;
        _switchButton.transform=oriTransform;
        _progressView.transform=oriTransform;
        _slider.transform=oriTransform;
        _timeLabel.transform=oriTransform;
    }
    else{
        _topBar.transform=topTransform;
        _backButton.transform=topTransform;
        _titleLabel.transform=topTransform;
        
        _footBar.transform=footTransform;
        _playButton.transform=footTransform;
        _switchButton.transform=footTransform;
        _progressView.transform=footTransform;
        _slider.transform=footTransform;
        _timeLabel.transform=footTransform;
    }
}
//恢复或改变alpha
-(void)restoreOrChangeAlpha:(BOOL)restore{
    CGFloat a=0;
    CGFloat b=0.5;
    CGFloat c=1;
    
    if (restore==YES) {
        _topBar.alpha=b;
        _backButton.alpha=c;
        _titleLabel.alpha=c;
        
        _footBar.alpha=b;
        _playButton.alpha=c;
        _switchButton.alpha=c;
        _progressView.alpha=c;
        _slider.alpha=c;
        _timeLabel.alpha=c;
    }
    else{
        _topBar.alpha=a;
        _backButton.alpha=a;
        _titleLabel.alpha=a;
        
        _footBar.alpha=a;
        _playButton.alpha=a;
        _switchButton.alpha=a;
        _progressView.alpha=a;
        _slider.alpha=a;
        _timeLabel.alpha=a;
    }
}
//恢复或改变frame
-(void)restoreOrChangeFrame:(BOOL)restoreFrame{
    if (restoreFrame==YES) {
        _topBar.frame=CGRectMake(0,0,_initFrame.size.width,CDPTOPHEIGHT(NO));
        _footBar.frame=CGRectMake(0,_initFrame.size.height-CDPFOOTHEIGHT,_initFrame.size.width,CDPFOOTHEIGHT);

        _backButton.frame=CGRectMake(5,_topBar.frame.origin.y+CDPTOPHEIGHT(NO)/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight);
        _titleLabel.frame=CGRectMake(CGRectGetMaxY(_backButton.frame),_topBar.frame.origin.y,_topBar.frame.size.width-CGRectGetMaxY(_backButton.frame)-5,CDPTOPHEIGHT(NO));
    }
    else{
        _topBar.frame=CGRectMake(0,0,self.bounds.size.width,CDPTOPHEIGHT(YES));
        _footBar.frame=CGRectMake(0,self.bounds.size.height-CDPFOOTHEIGHT,self.bounds.size.width,CDPFOOTHEIGHT);
        
        _backButton.frame=CGRectMake(5,_topBar.frame.origin.y+CDPTOPHEIGHT(NO)/2-CDPButtonHeight/2+20,CDPButtonWidth,CDPButtonHeight);
        _titleLabel.frame=CGRectMake(CGRectGetMaxY(_backButton.frame),_topBar.frame.origin.y+20,_topBar.frame.size.width-CGRectGetMaxY(_backButton.frame)-5,CDPTOPHEIGHT(NO));
    }
    _bufferView.frame=CGRectMake(self.bounds.size.width/2-60,self.bounds.size.height/2-30,120,60);
    _activityView.frame=CGRectMake(_bufferView.frame.origin.x+41,_bufferView.frame.origin.y+1,38,38);
    _bufferLabel.frame=CGRectMake(_bufferView.frame.origin.x,CGRectGetMaxY(_activityView.frame),120,20);
                  
    _playButton.frame=CGRectMake(5,_footBar.frame.origin.y+CDPFOOTHEIGHT/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight);
    _switchButton.frame=CGRectMake(_footBar.frame.size.width-35,_footBar.frame.origin.y+CDPFOOTHEIGHT/2-CDPButtonHeight/2,CDPButtonWidth,CDPButtonHeight);
    _timeLabel.frame=CGRectMake(_switchButton.frame.origin.x-80,_footBar.frame.origin.y,80,CDPFOOTHEIGHT);
    _progressView.frame=CGRectMake(CGRectGetMaxX(_playButton.frame),_footBar.frame.origin.y+CDPFOOTHEIGHT/2,CGRectGetMinX(_timeLabel.frame)-CGRectGetMaxX(_playButton.frame),2);
    _slider.frame=CGRectMake(_progressView.frame.origin.x-2,_progressView.frame.origin.y-14,_progressView.bounds.size.width+2,30);
}
















/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
