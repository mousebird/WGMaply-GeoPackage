//
//  LayerTableViewCell.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-08-03.
//  Copyright © 2016 Ranen Ghosh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LayerTableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UIImageView *typeImage;
@property (nonatomic, weak) IBOutlet UIImageView *idxImage;
@property (nonatomic, weak) IBOutlet UILabel *txtLabel;
@property (nonatomic, weak) IBOutlet UISwitch *enabledSwitch;

@end
