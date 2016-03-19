//
//  ViewController.m
//  player
//
//  Created by Wolonge on 16/3/1.
//  Copyright © 2016年 Wolonge. All rights reserved.
//

#import "ViewController.h"
#import "PlayerViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor lightGrayColor];

    UIButton *button=[[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width/2-30,60,60,30)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    button.backgroundColor=[UIColor cyanColor];
    [button addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(10,CGRectGetMaxY(button.frame)+10,self.view.bounds.size.width-20,self.view.bounds.size.height-CGRectGetMaxY(button.frame)-130)];
    label.backgroundColor=[UIColor whiteColor];
    label.font=[UIFont systemFontOfSize:15];
    label.textAlignment=NSTextAlignmentCenter;
    label.numberOfLines=0;
    label.text=@"CDPVideoPlayer是一个用AVFoundation框架搭建的视频播放器,使用AVPlayer对象播放\n\n自带有默认UI,也可以根据需求自定义UI, 单击显示/隐藏上下导航栏, 双击切换或缩小全屏,横向拖动控制播放进度,上下拖动控制音量等等\n\n具体在CDPVideoPlayer.h文件中都有说明\n\n详情请看demo\n\ngithub地址:https://github.com/cdpenggod/CDPVideoPlayer";
    [self.view addSubview:label];

}
-(void)play{
    PlayerViewController *vc=[[PlayerViewController alloc] init];
    
    [self presentViewController:vc animated:YES completion:nil];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
