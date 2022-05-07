//
//  AudioProcessor.h
//
//
//  Created by Emil Rakhmangulov on 04.05.2022.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioManager : NSObject

typedef NS_ENUM(NSInteger, FilterType) {
    FilterTypeMan = 0,
    FilterTypeMonster = 1,
    FilterTypeGirl = 2,
    FilterTypeCartoon = 3,
    FilterTypeRoom = 4,
    FilterTypeRadio = 5
};

- (id)initWithAudioAssetTrack:(AVAssetTrack *)audioAssetTrack;
- (void)stopProcessing;

@property (readonly, nonatomic) AVAssetTrack *audioAssetTrack;
@property (readonly, nonatomic) AVAudioMix *audioMix;
@property (nonatomic) BOOL isFilterEnabled;
@property (nonatomic) FilterType currentFilterType;

@end

NS_ASSUME_NONNULL_END
