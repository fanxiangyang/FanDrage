//
//  FanProView.m
//  FanDrage
//
//  Created by 向阳凡 on 2021/1/7.
//

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
//    NSLog(@"重新绘制");
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
//    NSLog(@"真正的缩放倍数%f======%f=====%f",scale,cl,self.c*scale);
    
    CGFloat cw=cl*(60.0f*5.0f)+self.w;
    self.frame=CGRectMake(-(CGFloat)(self.currentCount)*(self.l*scale), 0, cw, self.h);
//    self.frame=CGRectMake(-self.c*scale, 0, cw, self.h);

    //缩放因子
//    self.contentScaleFactor=2.0f;
    [self fan_drawPro];
}
@end
