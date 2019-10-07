//
//  RJSceneViewController.m
//  RJEventTracking_Example
//
//  Created by Ryan Jin on 2019/10/7.
//  Copyright © 2019 RylanJIN. All rights reserved.
//

#import "RJSceneViewController.h"

@interface RJSceneViewController ()

@property (nonatomic, assign) NSInteger orderType;

@end

@implementation RJSceneViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)segmentAction:(UISegmentedControl *)sender {
    self.orderType = sender.selectedSegmentIndex;
}

- (IBAction)callService:(UIButton *)sender {
    // to do call service logic
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
