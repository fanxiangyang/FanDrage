## FanDrage(iOS实现一个可以自由缩放，移动的刻度尺)

最近公司需要做一个画曲线的坐标轴，动画在坐标轴上运动，当然好多复杂的曲线改变曲率，运动画线，求三次贝塞尔曲线等复杂问题，本次不做讨论，本次只是来实现一个刻度尺的功能，支持缩放，左右移动

### 我先把问题坑抛出来，怕你们看不到
*	1.空DrawRect方式为什么内存是50MB（不开启drawRect项目11M左右）
* 	2.drawRect画图方式，缩放时为什么内存暴增，CPU暴增
*  	3.换了Layer方式，缩放时内存恢复11M正常，但是CPU为什么还是暴增
*   	4.每屏幕大概4秒，20倍左右的屏幕大小，用滚动控件，还是view
*    5.缩放时触发了layer隐式动画，可以关闭吗
*    6.用了view实现，怎么实现滑动惯性移动

###一：需要的准备的技术要点，看似简单，踩坑无数

* 1.左右移动60秒，需要手势能解决，UIPanGestureRecognizer，
* 2.画图实现刻度尺，CAShapeLayer替代drawRect方法
*  3.时时缩放，使用手势UIPinchGestureRecognizer
*  4.每屏幕大概4秒，20倍左右的屏幕大小，用滚动控件，还是view

###二：项目实现，一步步踩坑，以问题切入，后面会有完整代码
####1.准备之前，创建一个FanProView来实现核心功能
```
//ViewController.m中创建一个可以画图的view(_proView)
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
```

####2.用View还是用ScrollView呢？
*	考虑这个的时候，想到后面还要画曲线什么的，view自由控制性更强，或者ScrollView有什么特殊限制，最终选择View，用ScrollView应该也是可以的（不做过多解释）
* 	想到拖动时的刻度移动，因为画20倍屏幕，用复用一个屏幕还是frame*20倍，因为刻度尺移动，给cell复用不太一样，而且线连接一起，不好控制时时拖动，时时绘制，局部渲染，还是用了view放大20倍，给ScrollView一样，滚动就行，后面会注意控制下子控件个数，避免

####3.实现画图，DrawRect内存占用高，为什么？
*	1.由于我考虑了用View实现此功能，20倍屏幕，一开始怀疑绘制内容太多，或者考虑绘制用了贝塞尔渲染，给上下文渲染不一样，结果我试了两种方法，看了说明，好像原理是一样的，没有太大差别，都是上下文渲染。
* 	2.我试着减小view的frame大小，发现明显内存降低了，难道画图真的占用很大内存？
*  	3.最后我注释了drawrect方法里面所有代码，内存还是很高，没有变化，只有注释掉drawrect方法，才恢复正常？

为什么会出现这样的情况呢，实现了UIView的-drawRect:或者CALayerDelegate的-drawLayer:inContext:方法，为了支持对图层内容的任意绘制，Core Animation必须创建一个图层宽*图层高*4字节大小的寄宿图，宽高的单位均为像素。明显看到原因了，drawRect本身就是锅，而且缩放时，占用cpu和内存都是暴增，后面再说。
#####3.1DrawRect内存占用高，怎么解决呢？
*	1.因为CALayer的contents属性就对应于寄宿图，把View的layer层改成 CATiledLayer，结果明显不一样，具体效果你可以搜索，但是本项目改了后，效果不太好，下面有更好的解决方案
* 	2.使用CAShapeLayer来实现画图的操作，内存瞬间恢复正常。


####4.CALayer，CAShapeLayer画图，不用DrawRect,CPU为什么暴增
换用CAShapeLayer，有什么好处？

*	1.CAShapeLayer使用了硬件加速，绘制同一图形会比用Core Graphics快很多。
*  	2.CAShapeLayer不需要像普通CALayer一样创建一个寄宿图形，所以无论有多大，都不会占用太多的内存
*	3.不会被图层边界剪裁掉。
*	4.不会出现像素化。

换用后，发现内存占用很低，但是CPU占用很高，发现我缩放时，重新移除创建了新的Layer,于是我就保留了layer，只是改变路径或者改变frame，瞬间所有问题都解决了，而且很丝滑的感觉，但是发现，缩放时，frame动画恢复，不是时时的，触发了layer的隐式动画，
*	CATransaction可以改变动画，begin，setAnimationDuration，commit等
*	关闭动画[CATransaction setDisableActions:YES];放在layer改变frame之前

都处理完，才发现内存，CPU占用都很少
####5.自己View实现，怎么像ScrollView一样有滑动惯性呢？
*	1.UIPinchGestureRecognizer捏合手势有一个-velocityInView：方法，拿到x,y轴速度，可以自己控制好灵敏度，移动一段距离，控制下时间，实现一个动画[UIView animateWithDuration:]
* 	2.如果感觉动画不够丝滑，可以用CADisplayLink屏幕刷新定时器，来实现，要考虑好动画先快后慢

####6.其他注意点问题
*	1.如果用touchesBegan注意和UIPanGestureRecognizer，UIPinchGestureRecognizer手势冲突，尽量避免
* 	2.注意捏合缩放时的倍数计算问题
*  	3.注意计算移动最小刻度的问题


####7.核心代码
#####7.1 FanProView.h

```
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FanProView : UIView
///中间缩放边距
@property(nonatomic,assign)UIEdgeInsets scaleInsets;
///必须这样初始化
-(instancetype)initWithW:(CGFloat)w h:(CGFloat)h;
///每次重新绘制
-(void)fan_drawPro;
@end

NS_ASSUME_NONNULL_END

```

#####7.2 FanProView.m
```

#import "FanProView.h"

@interface FanProView()
//初始化不会改变的距离
@property(nonatomic,assign,readonly)CGFloat w;//可见区域宽度
@property(nonatomic,assign,readonly)CGFloat h;//可见区域高度
@property(nonatomic,assign,readonly)CGFloat l;//最小宽度 200ms


//缩放移动时改动的属性
@property(nonatomic,assign)CGFloat s;//缩放倍数（缩放接收后赋值）
@property(nonatomic,assign)CGFloat current_scale;//当前时时缩放倍数
@property(nonatomic,assign)CGFloat c;//当前的刻度位置偏移量默认0
@property(nonatomic,assign)CGPoint touchPoint;//开始左右拖动时的初始点
@property(nonatomic,assign)CGRect touchFrame;//开始左右拖动时的初始frame
@property(nonatomic,assign)NSUInteger currentCount;//当前停留的最小刻度个数
@property(nonatomic,assign)CGFloat scrollSpeed;//拖动时结束的速度


///存放秒数的0-60s的缓存
@property(nonatomic,strong)NSMutableArray<CATextLayer *> *textLayerArr;
///字体的get方法
@property(nonatomic,strong)NSMutableDictionary *attributedStrDic;
///画刻度的layer
@property(nonatomic,strong)CAShapeLayer *topLayer;


@end

@implementation FanProView

-(void)awakeFromNib{
    [super awakeFromNib];
    [self initPro];
}
-(instancetype)initWithFrame:(CGRect)frame{
    self=[super initWithFrame:frame];
    if (self) {
        [self initPro];
    }
    return self;
}
-(instancetype)initWithW:(CGFloat)w h:(CGFloat)h{
    CGFloat min=(w-40.0f)/(4.0*5.0f);
    CGFloat cw=min*(60.0f*5.0f)+w;
    
    self=[super initWithFrame:CGRectMake(0, 0, cw, h)];
    if (self) {
        _w=w;
        _h=h;
        _l=min;
        [self initPro];
    }
    return self;
}
//初始化数据
-(void)initPro{
    self.s=1.0f;
    self.current_scale=1.0f;
    self.c=0.0f;
    self.scaleInsets=UIEdgeInsetsMake(0, _w/2.0f, 0, _w/2.0f);
    
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch=[[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(pinch:)];
    [self addGestureRecognizer:pinch];
    
    _textLayerArr=[[NSMutableArray alloc]init];
    
    [self fan_drawPro];
}
-(void)fan_drawPro{
    //重新绘制（drawRect方法用这个打开）
//    [self setNeedsDisplay];
    //layer绘制，节省了内存，CPU占用也维持在10%以下
    [self fan_drawLayer];
}
#pragma mark - Layer绘制模式

///Layer绘制方式  节省了内存，CPU占用也维持在10%以下
-(void)fan_drawLayer{
    NSLog(@"重新绘制");
    //这样做耗费cpu,30%-40% 如果改变fram，10%左右 但是Layer会有隐式动画
//    [self.textLayerArr makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
//    [self.textLayerArr removeAllObjects];
    
    
    CGFloat rw=self.frame.size.width;
//    CGFloat rh=self.frame.size.height;
    int minute=60;
    //直接贝塞尔曲线渲染
    UIBezierPath *path = [UIBezierPath bezierPath];
    //绘制两个线
    [path moveToPoint:CGPointMake(0, 1)];
    [path addLineToPoint:CGPointMake(rw, 1)];
    [path moveToPoint:CGPointMake(0, 9)];
    [path addLineToPoint:CGPointMake(rw, 9)];

    for (int i=0; i<minute*5; i++) {
        [path moveToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale), 1)];
        [path addLineToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale), 5)];
    }
    
    for (int i=0; i<minute+1; i++) {
        [path moveToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 1)];
        [path addLineToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 9)];
    }
    if (self.topLayer==nil) {
        CAShapeLayer *layer=[[CAShapeLayer alloc]init];
        layer.lineWidth=2;
        layer.lineCap = kCALineCapRound;
        layer.strokeColor=[UIColor lightGrayColor].CGColor;
        layer.path=[path CGPath];
        [self.layer addSublayer:layer];
        self.topLayer=layer;
    }else{
        self.topLayer.path=[path CGPath];
    }
    
    
    //字体1s
    if (self.textLayerArr.count>0) {
        for (int i=0; i<self.textLayerArr.count; i++) {
            //关闭动画，Layer会有隐式动画，耗费CPU（不关闭，看到字体延迟，刷新不及时）
            [CATransaction setDisableActions:YES];
            CATextLayer *layerText = self.textLayerArr[i];
            // 显示位置
            layerText.frame = CGRectMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0,20,10);
//            [self.layer addSublayer:layerText];
        }
    }else{
        for (int i=0; i<minute+1; i++) {
            NSString *second=[NSString stringWithFormat:@"%ds",i];
            NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc] initWithString:second attributes:self.attributedStrDic];
            // 绘制文本的图层
            CATextLayer *layerText = [[CATextLayer alloc] init];
            layerText.string=attributedStr;
            layerText.alignmentMode=kCAAlignmentLeft;
    //        layerText.foregroundColor = [UIColor darkTextColor].CGColor;
            layerText.backgroundColor = [UIColor orangeColor].CGColor;
            // 渲染分辨率-重要，否则显示模糊
            layerText.contentsScale = [UIScreen mainScreen].scale;
            // 显示位置
            layerText.frame = CGRectMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0,20,10);
    //        layerText.position=CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0);
            // 添加到父图书
            [self.layer addSublayer:layerText];
            [self.textLayerArr addObject:layerText];
        }
    }
   
}
-(NSMutableDictionary*)attributedStrDic{
    if (_attributedStrDic==nil) {
        NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
        textStyle.lineBreakMode = NSLineBreakByWordWrapping;
        textStyle.alignment = NSTextAlignmentLeft;//水平居中

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        //字体大小
        dict[NSFontAttributeName] = [UIFont systemFontOfSize:8];
        //设置颜色
        dict[NSForegroundColorAttributeName] = [UIColor darkTextColor];
        dict[NSParagraphStyleAttributeName]=textStyle;
        _attributedStrDic=dict;
    }
    return _attributedStrDic;
}
#pragma mark - drawRect绘制模式
/*
// 绘制空的都会内存暴增，不建议用这个方法,cpu也会暴增到40%-70%
- (void)drawRect:(CGRect)rect {
    //不开起任何绘制，只是单纯的开启方法，就有50M内存消耗，w*h*4字节
//    [super drawRect:rect];
//    return;
    NSLog(@"重新绘制");
    CGFloat rw=rect.size.width;
//    CGFloat rh=rect.size.height;
    int minute=60;
    //上下文对象
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
    //直接贝塞尔曲线渲染
    UIBezierPath *path = [UIBezierPath bezierPath];
    //线宽
    path.lineWidth = 2;
    //端点圆角
    path.lineCapStyle = kCGLineCapRound;
    //绘制两个线
    [path moveToPoint:CGPointMake(0, 1)];
    [path addLineToPoint:CGPointMake(rw, 1)];
    [path moveToPoint:CGPointMake(0, 9)];
    [path addLineToPoint:CGPointMake(rw, 9)];
    [[UIColor lightGrayColor]setStroke];
    //[[UIColor grayColor]set];边框+填充颜色

    for (int i=0; i<minute*5; i++) {
        [path moveToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale), 0)];
        [path addLineToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale), 5)];
    }
    
    for (int i=0; i<minute+1; i++) {
        [path moveToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0)];
        [path addLineToPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 9)];
    }
    //单独的绘制完成，要立即渲染
    [path stroke];//渲染
    //[path fill];渲染+填充
    //字体1s
    for (int i=0; i<minute+1; i++) {
        NSString *second=[NSString stringWithFormat:@"%ds",i];
        //自带渲染，不能放到[path stroke]之前，不然会重复渲染
        [second drawAtPoint:CGPointMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0) withAttributes:self.attributedStrDic];
//        [second drawInRect:CGRectMake(_w/2.0f+i*(_l*_current_scale)*5.0f, 0,20,20) withAttributes:self.attributedStrDic];
    }
}
+(Class)layerClass{
    return [CATiledLayer class];
}
*/
#pragma mark - 左右滚动手势处理
//这个打开会给后面的捏合手势冲突，计算不好控制，故而弃用，改用拖动手势
//-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    CGPoint touchPoint=[[touches anyObject]locationInView:self.superview];
//    [self fan_touchPoint:touchPoint touchType:0];
//}
//-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    CGPoint touchPoint=[[touches anyObject]locationInView:self.superview];
//    [self fan_touchPoint:touchPoint touchType:1];
//}
//-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    CGPoint touchPoint=[[touches anyObject]locationInView:self.superview];
//    [self fan_touchPoint:touchPoint touchType:2];
//}
//-(void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    CGPoint touchPoint=[[touches anyObject]locationInView:self.superview];
//    [self fan_touchPoint:touchPoint touchType:3];
//}
-(void)pan:(UIPanGestureRecognizer *)pan{
    CGPoint point = [pan locationInView:self.superview];
    NSInteger touchType=0;
    if (pan.state==UIGestureRecognizerStateBegan) {
        touchType=0;
    }else if (pan.state==UIGestureRecognizerStateChanged) {
        touchType=1;
    }else if (pan.state==UIGestureRecognizerStateEnded) {
        touchType=2;
    }else if (pan.state==UIGestureRecognizerStateCancelled) {
        touchType=3;
    }else if (pan.state==UIGestureRecognizerStateFailed) {
        touchType=4;
    }
//    [self fan_touchPoint:point touchType:touchType];
    
    if (touchType==2||touchType==3||touchType==4){
        //计算惯性
        CGPoint velocity=[pan velocityInView:self.superview];
        //只需要x方向移动的速度就行
        CGFloat x=velocity.x;
        self.scrollSpeed=x;
    }else{
        
    }
    
    [self fan_touchPoint:point touchType:touchType];

}
///0-Began 1-Moved 2-Ended 3-Cancelled
-(void)fan_touchPoint:(CGPoint)point touchType:(NSInteger)touchType{
    if (point.x<0) {
        point.x=0;
    }else if(point.x>self.w){
        point.x=self.w;
    }
    if (point.y<0) {
        point.y=0;
    }else if(point.y>self.h){
        point.y=self.h;
    }
//    NSLog(@"====%f",point.x);
    if (touchType==0) {
        self.touchPoint=point;
        self.touchFrame=self.frame;
    }else if (touchType==1){
        CGFloat d=point.x-self.touchPoint.x;
        CGRect frame=self.touchFrame;
        frame.origin.x+=d;
        if (frame.origin.x>=0.0f) {
            return;
        }
        if (frame.origin.x<=-(frame.size.width-_w)) {
            return;
        }
        self.frame=frame;
    }else if (touchType==2||touchType==3||touchType==4){
        //用来处理拖动惯性实现，注释掉就是给原来一模一样
        //自己试出来的比例,改动此处可修改灵敏度
        float slideFactor =fabs(0.1 * (self.scrollSpeed / 200.0f));
        CGPoint finalPoint = CGPointMake(point.x + (self.scrollSpeed * slideFactor),0);
//        NSLog(@"=%f====%f===%f===%f",slideFactor,self.scrollSpeed,point.x,finalPoint.x);
        point=finalPoint;
        
        
        CGFloat d=point.x-self.touchPoint.x;
        CGRect frame=self.touchFrame;
        frame.origin.x+=d;
        if (frame.origin.x>=0.0f) {
            frame.origin.x=0;
//            return;
        }
        if (frame.origin.x<=-(frame.size.width-_w)) {
            frame.origin.x=-(frame.size.width-_w);
//            return;
        }
        
        self.c=fabs(frame.origin.x);
        self.currentCount=[self centerOffsetX];
        frame.origin.x=-(self.s*self.l)*(CGFloat)(self.currentCount);
        self.c=fabs(frame.origin.x);

//        self.frame=frame;

//        NSLog(@"左右移动偏移量：%f",self.c);
        [UIView animateWithDuration:slideFactor delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ //slideFactor秒内做完改变动画，动画效果快进慢出（先快后慢）
            self.frame=frame;
        } completion:nil];
    }
}
//获取当前需要多少个最小刻度
-(NSUInteger)centerOffsetX{
    NSUInteger i=self.c/(self.s*self.l);
    CGFloat cha=self.c-(CGFloat)(i)*(self.s*self.l);
    if (cha/(self.s*self.l)>=0.5) {
        i+=1;
    }
    return i;
}
#pragma mark - 捏合手势处理

-(void)pinch:(UIPinchGestureRecognizer *)pinch{
//    NSLog(@"缩放倍数%f",pinch.scale);
    CGFloat scale = self.s*pinch.scale;
    if (scale>5.0f) {
        scale=5.0f;
    }
    if (scale<0.2f) {
        scale=0.2f;
    }
    if (pinch.state==UIGestureRecognizerStateBegan) {
        //开始的时候，趋近于1.0f
//        self.c=fabs(self.frame.origin.x)/self.s;
    }else if(pinch.state==UIGestureRecognizerStateChanged){
        
    }else if(pinch.state==UIGestureRecognizerStateEnded||pinch.state==UIGestureRecognizerStateCancelled||pinch.state==UIGestureRecognizerStateFailed){
        self.s=scale;
//        NSLog(@"==================%f",self.s);
    }
    CGFloat cl = self.l*scale;
    self.current_scale=scale;
    NSLog(@"真正的缩放倍数%f======%f=====%f",scale,cl,self.c*scale);
    
    CGFloat cw=cl*(60.0f*5.0f)+self.w;
    self.frame=CGRectMake(-(CGFloat)(self.currentCount)*(self.l*scale), 0, cw, self.h);
//    self.frame=CGRectMake(-self.c*scale, 0, cw, self.h);

    //缩放因子
//    self.contentScaleFactor=2.0f;
    [self fan_drawPro];
}
@end
```


