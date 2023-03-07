//
//  FanProView.h
//  FanDrage
//
//  Created by 向阳凡 on 2021/1/7.
//

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
