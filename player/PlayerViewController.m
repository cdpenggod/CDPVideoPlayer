//
//  PlayerViewController.m
//  player
//
//  Created by Wolonge on 16/3/1.
//  Copyright © 2016年 Wolonge. All rights reserved.
//

#import "PlayerViewController.h"
#import "CDPVideoPlayer.h"

#define SWIDTH   [UIScreen mainScreen].bounds.size.width
#define SHEIGHT  [UIScreen mainScreen].bounds.size.height

@interface PlayerViewController () <CDPVideoPlayerDelegate> {
    CDPVideoPlayer *_player;
    
}

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [self createUI];
    
    //开始播放
    [_player play];
    
}
-(void)dealloc{
    //关闭播放器并销毁当前播放view
    //一定要在退出时使用,否则内存可能释放不了
    [_player close];
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [UIApplication sharedApplication].statusBarStyle=UIStatusBarStyleLightContent;
    self.view.backgroundColor=[UIColor lightTextColor];
}
-(BOOL)shouldAutorotate{
    return !_player.isSwitch;
}
#pragma mark - 创建UI
-(void)createUI{
    
    //播放器
    _player=[[CDPVideoPlayer alloc] initWithFrame:CGRectMake(0,120,SWIDTH,SWIDTH*3/4)
                                              url:@"http://v.theonion.com/onionstudios/video/3158/640.mp4"
                                         delegate:self
                                   haveOriginalUI:YES];
    _player.title=@"这是标题~~";
    [self.view addSubview:_player];
    
}
#pragma mark - CDPVideoPlayerDelegate
//非全屏下返回点击(仅限默认UI)
-(void)back{
    [self backClick];
}
#pragma mark - 点击事件
//返回
-(void)backClick{
    [self dismissViewControllerAnimated:YES completion:nil];
}


















- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
