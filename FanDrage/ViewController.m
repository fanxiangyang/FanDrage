//
//  ViewController.m
//  FanDrage
//
//  Created by 向阳凡 on 2021/1/7.
//

#import "ViewController.h"
#import "FanProView.h"
#import "FanKit.h"

@interface ViewController ()
@property(nonatomic,strong)FanProView *proView;


@property(nonatomic,strong)UIView *redView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor=[[UIColor whiteColor]colorWithAlphaComponent:0.8];
    
    [self configUI];
}
-(void)configUI{
    //拖动区域view
    _redView = [[UIView alloc]init];
    _redView.backgroundColor=[UIColor redColor];
    [self.view addSubview:_redView];
    [self.view fan_addConstraints:_redView edgeInsets:UIEdgeInsetsMake(34, 40, 34, 40) layoutType:FanLayoutAttributeAll viewSize:CGSizeZero];
    _redView.clipsToBounds=YES;
//    [self.view layoutIfNeeded];
    //画图绘制区域
    _proView = [[FanProView alloc]initWithW:FanScreenWidth-80 h:FanScreenHeight-68];
//    _proView = [[FanProView alloc]initWithW:_redView.frame.size.width h:_redView.frame.size.height];
    _proView.backgroundColor=[UIColor whiteColor];
    [_redView addSubview:_proView];
    //中间画一根红线标尺
    [_redView.layer addSublayer:[FanDrawLayer fan_lineStartPoint:CGPointMake((FanScreenWidth-80)/2.0f, 0) toPoint:CGPointMake((FanScreenWidth-80)/2.0f, (FanScreenHeight-68)) lineWidth:2 lineColor:[UIColor redColor]]];
    
}

@end
