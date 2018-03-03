//
//  ViewController.m
//  HCKVO
//
//  Created by HChong on 2018/1/26.
//  Copyright © 2018年 HChong. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVO.h"
#import "Message.h"

@interface ViewController ()

@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) Message *message;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.button];
    
    [self.message HC_addObserver:self forKey:@"text" withBlock:^(id  _Nullable observedObject, NSString * _Nullable observedKey, id  _Nullable oldValue, id  _Nullable newValue) {
        NSLog(@"%@------------%@", oldValue, newValue);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)buttonAction {
    self.message.text = [NSString stringWithFormat:@"%d", arc4random() % 100000];
}

#pragma mark - Getter, Setter
- (UIButton *)button {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        _button.frame = CGRectMake(50, 100, 100, 50);
        [_button addTarget:self action:@selector(buttonAction) forControlEvents:UIControlEventTouchUpInside];
        [_button setTitle:@"确定" forState:UIControlStateNormal];
        _button.backgroundColor = [UIColor grayColor];
        _button.titleLabel.font = [UIFont systemFontOfSize:12];
    }
    return _button;
}

- (Message *)message {
    if (!_message) {
        _message = [[Message alloc] init];
    }
    return _message;
}

@end
