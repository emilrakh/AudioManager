//
//  AudioProcessor.m
//
//
//  Created by Emil Rakhmangulov on 04.05.2022.
//

//#include <UIKit/UIKit.h>

#import "AudioManager.h"

typedef struct AVAudioManagerContext {
    Boolean isNonInterleaved;
    AudioUnit audioUnitPitch;
    AudioUnit audioUnitDist;
    AudioUnit audioUnitEQ;
    AudioUnit audioUnitReverb;
    Float64 sampleCount;
    NSInteger audioEffectType;
    void *self;
} AVAudioManagerContext;

static void tap_InitCallback(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut);
static void tap_FinalizeCallback(MTAudioProcessingTapRef tap);
static void tap_PrepareCallback(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat);
static void tap_UnprepareCallback(MTAudioProcessingTapRef tap);
static void tap_ProcessCallback(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut);

static OSStatus AU_PitchRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus AU_DistRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus AU_EQRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus AU_ReverbRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

@interface AudioManager () {
    AVAudioMix *_audioMix;
    AudioStreamBasicDescription * processingFormat;
    CMItemCount maxFrames;
}
@end

FilterType processorFilterType;

UInt64 processedFrames;
AudioUnit distAudioUnit;
AudioUnit pitchAudioUnit;
AudioUnit eqAudioUnit;
AudioUnit reverbAudioUnit;

bool distortionEnabled;
bool pitchEnabled;
bool eqEnabled;
bool reverbEnabled;

@implementation AudioManager

+(void)applyManEffect {
    distortionEnabled = false;
    pitchEnabled = true;
    eqEnabled = false;
    reverbEnabled = false;
    
    //PITCH
    float pitch = (float)-400;
    OSStatus status = AudioUnitSetParameter(pitchAudioUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
    if (noErr != status) NSLog(@"AudioUnitSetParameter(kNewTimePitchParam_Pitch): %d", (int)status);
}

+ (void) applyMonsterEffect {
    distortionEnabled = true;
    pitchEnabled = true;
    eqEnabled = true;
    reverbEnabled = false;
    
    //PITCH
    float pitch = (float)-600;
    OSStatus status = AudioUnitSetParameter(pitchAudioUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
    
    CFArrayRef presets;
    UInt32 size = sizeof(presets);
    
    //DIST
    AudioUnitGetProperty(distAudioUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &presets, &size);

    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(presets, 21); // Waves

    status = AudioUnitSetProperty(distAudioUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
    
    if (noErr != status) NSLog(@"AudioUnitSetParameter(kAudioUnitProperty_PresentPreset): %d", (int)status);
    
    status = AudioUnitSetParameter(distAudioUnit, kDistortionParam_FinalMix, kAudioUnitScope_Global, 0, 10, 0);
    
    //EQ
    UInt32 numberOfBands = (UInt32)3;
    status = AudioUnitSetProperty(eqAudioUnit, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &numberOfBands, (UInt32)sizeof(UInt32));
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_Frequency + 1, kAudioUnitScope_Global, 0, 10000, 0);
    }

    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_Gain + 1, kAudioUnitScope_Global, 0, -24, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_GlobalGain, kAudioUnitScope_Global, 0, 0, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand, kAudioUnitScope_Global, 0, 1, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand + 1, kAudioUnitScope_Global, 0, 0, 0);
    }
}

+ (void)applyGirlEffect {
    distortionEnabled = false;
    pitchEnabled = true;
    eqEnabled = true;
    reverbEnabled = false;
    
    //PITCH
    float pitch = (float)300;
    OSStatus status = AudioUnitSetParameter(pitchAudioUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
    
    //EQ
    UInt32 numberOfBands = (UInt32)3;
    status = AudioUnitSetProperty(eqAudioUnit, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &numberOfBands, (UInt32)sizeof(UInt32));

    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_Frequency, kAudioUnitScope_Global, 0, 400, 0);
    }

    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_FilterType, kAudioUnitScope_Global, 0, kAUNBandEQFilterType_2ndOrderButterworthHighPass, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_GlobalGain, kAudioUnitScope_Global, 0, 10, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand, kAudioUnitScope_Global, 0, 0, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand + 1, kAudioUnitScope_Global, 0, 1, 0);
    }
}

+ (void) applyCartoonEffect {
    distortionEnabled = false;
    pitchEnabled = true;
    eqEnabled = false;
    reverbEnabled = false;
    
    //PITCH
    float pitch = (float)800;
    AudioUnitSetParameter(pitchAudioUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
}

+ (void) applyRoomEffect {
    distortionEnabled = false;
    pitchEnabled = false;
    eqEnabled = false;
    reverbEnabled = true;
    
    //PITCH
    float pitch = (float)0;
    OSStatus status = AudioUnitSetParameter(pitchAudioUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
    
    //REVERB
    if (noErr == status) {
        status = AudioUnitSetParameter(reverbAudioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 70, 0);
    }
    if (noErr == status) {
        status = AudioUnitSetParameter(reverbAudioUnit, kReverb2Param_RandomizeReflections, kAudioUnitScope_Global, 0, 1000, 0);
    }
    if (noErr == status) {
        status = AudioUnitSetParameter(reverbAudioUnit, kReverb2Param_MaxDelayTime, kAudioUnitScope_Global, 0, 0.5, 0);
    }
    if (noErr == status) {
        status = AudioUnitSetParameter(reverbAudioUnit, kReverb2Param_DecayTimeAt0Hz, kAudioUnitScope_Global, 0, 2, 0);
    }
    if (noErr == status) {
        status = AudioUnitSetParameter(reverbAudioUnit, kReverb2Param_DecayTimeAtNyquist, kAudioUnitScope_Global, 0, 3, 0);
    }
}

+ (void) applyRadioEffect {
    distortionEnabled = false;
    pitchEnabled = false;
    eqEnabled = true;
    reverbEnabled = false;
    
    //EQ
    UInt32 numberOfBands = (UInt32)3;
    OSStatus status = AudioUnitSetProperty(eqAudioUnit, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &numberOfBands, (UInt32)sizeof(UInt32));

    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_Frequency, kAudioUnitScope_Global, 0, 5000, 0);
    }

    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_FilterType, kAudioUnitScope_Global, 0, kAUNBandEQFilterType_BandPass, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_GlobalGain, kAudioUnitScope_Global, 0, 10, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand, kAudioUnitScope_Global, 0, 0, 0);
    }
    
    if (noErr == status) {
        status = AudioUnitSetParameter(eqAudioUnit, kAUNBandEQParam_BypassBand + 1, kAudioUnitScope_Global, 0, 1, 0);
    }
}

//- (void)setCurrentFilterType: (FilterType)currentFilterType {
- (void)setCurrent: (FilterType)currentFilterType {
    
    NSLog(@"Stack trace : %@",[NSThread callStackSymbols]);

    switch (currentFilterType) {
        case FilterTypeMan:
            [AudioManager applyManEffect];
            break;
        case FilterTypeMonster:
            [AudioManager applyMonsterEffect];
            break;
        case FilterTypeGirl:
            [AudioManager applyGirlEffect];
            break;
        case FilterTypeCartoon:
            [AudioManager applyCartoonEffect];
            break;
        case FilterTypeRoom:
            [AudioManager applyRoomEffect];
            break;
        case FilterTypeRadio:
            [AudioManager applyRadioEffect];
            break;
    }
}

- (void)stopProcessing {
    NSLog(@"AudioManager - stopProcessing");
    AVMutableAudioMixInputParameters *params = (AVMutableAudioMixInputParameters *)_audioMix.inputParameters[0];
    MTAudioProcessingTapRef audioProcessingTap = params.audioTapProcessor;
    AVAudioManagerContext *context = (AVAudioManagerContext *)MTAudioProcessingTapGetStorage(audioProcessingTap);

    context->self = NULL;
    params.audioTapProcessor = NULL;
}

- (id)initWithAudioAssetTrack:(AVAssetTrack *)audioAssetTrack {
    NSParameterAssert(audioAssetTrack && [audioAssetTrack.mediaType isEqualToString:AVMediaTypeAudio]);
    
    self = [super init];
    
    if (self) {
        _audioAssetTrack = audioAssetTrack;
    }
    
    return self;
}

- (AVAudioMix *)audioMix {
    if (!_audioMix) {
        AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
        if (audioMix) {
            AVMutableAudioMixInputParameters *audioMixInputParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:self.audioAssetTrack];
            if (audioMixInputParameters) {
                MTAudioProcessingTapCallbacks callbacks;
                
                callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
                callbacks.clientInfo = (__bridge void *)self;
                callbacks.init = tap_InitCallback;
                callbacks.finalize = tap_FinalizeCallback;
                callbacks.prepare = tap_PrepareCallback;
                callbacks.unprepare = tap_UnprepareCallback;
                callbacks.process = tap_ProcessCallback;
                
                MTAudioProcessingTapRef audioProcessingTap;
                if (noErr == MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &audioProcessingTap)) {
                    audioMixInputParameters.audioTapProcessor = audioProcessingTap;
                    
                    CFRelease(audioProcessingTap);
                    
                    audioMix.inputParameters = @[audioMixInputParameters];
                    
                    _audioMix = audioMix;
                }
            }
        }
    }
    
    return _audioMix;
}

@end

#pragma mark - MTAudioProcessingTap Callbacks

static void tap_InitCallback(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    AVAudioManagerContext *context = calloc(1, sizeof(AVAudioManagerContext));
    
    // Initialize MTAdioProcessingTap context
    context->isNonInterleaved = false;
    context->audioUnitPitch = NULL;
    context->audioUnitDist = NULL;
    context->audioUnitEQ = NULL;
    context->audioUnitReverb = NULL;
    context->sampleCount = 0.0f;
    context->audioEffectType = 0;
    context->self = clientInfo;
    
    *tapStorageOut = context;
}

static void tap_FinalizeCallback(MTAudioProcessingTapRef tap) {
    AVAudioManagerContext *context = (AVAudioManagerContext *)MTAudioProcessingTapGetStorage(tap);
    
    // Clear MTAdioProcessingTap context
    context->self = NULL;
    
    free(context);
}

static void tap_PrepareCallback(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    
    AVAudioManagerContext *context = (AVAudioManagerContext *)MTAudioProcessingTapGetStorage(tap);
    
    // Verify processing format
    if (processingFormat->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        context->isNonInterleaved = true;
    }
    
    // Create bandpass filter Audio Unit
    AudioUnit audioUnitPitch;
    
    AudioComponentDescription audioComponentDescriptionPitch;
    audioComponentDescriptionPitch.componentType = kAudioUnitType_FormatConverter;
    audioComponentDescriptionPitch.componentSubType = kAudioUnitSubType_NewTimePitch;
    audioComponentDescriptionPitch.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescriptionPitch.componentFlags = 0;
    audioComponentDescriptionPitch.componentFlagsMask = 0;
    
    AudioComponent audioComponentPitch = AudioComponentFindNext(NULL, &audioComponentDescriptionPitch);
    if (audioComponentPitch) {
        if (noErr == AudioComponentInstanceNew(audioComponentPitch, &audioUnitPitch)) {
            OSStatus status = noErr;
            
            // Set audio unit input/output stream formate to processing format
            if (noErr == status) {
                status = AudioUnitSetProperty(audioUnitPitch, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            if (noErr == status) {
                status = AudioUnitSetProperty(audioUnitPitch, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            
            // Set audio unit render callback
            if (noErr == status) {
                AURenderCallbackStruct renderCallbackStruct;
                renderCallbackStruct.inputProc = AU_PitchRenderCallback;
                renderCallbackStruct.inputProcRefCon = (void *)tap;
                status = AudioUnitSetProperty(audioUnitPitch, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallbackStruct, sizeof(AURenderCallbackStruct));
            }
            
            // Set audio unit maximum frames per slice to max frames
            if (noErr == status) {
                UInt32 maximumFramesPerSlice = (UInt32)maxFrames;
                status = AudioUnitSetProperty(audioUnitPitch, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, (UInt32)sizeof(UInt32));
            }
            
            // Initialize audio unit
            if (noErr == status) {
                status = AudioUnitInitialize(audioUnitPitch);
            }
            
            if (noErr != status) {
                AudioComponentInstanceDispose(audioUnitPitch);
                audioUnitPitch = NULL;
            }
            
            context->audioUnitPitch = audioUnitPitch;
            pitchAudioUnit = audioUnitPitch;
        }
    }
    
    AudioUnit audioUnitDist;
    
    AudioComponentDescription audioComponentDescriptionDist;
    audioComponentDescriptionDist.componentType = kAudioUnitType_Effect;
    audioComponentDescriptionDist.componentSubType = kAudioUnitSubType_Distortion;
    audioComponentDescriptionDist.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescriptionDist.componentFlags = 0;
    audioComponentDescriptionDist.componentFlagsMask = 0;
    
    AudioComponent audioComponentDist = AudioComponentFindNext(NULL, &audioComponentDescriptionDist);
    if (audioComponentDist) {
        if (noErr == AudioComponentInstanceNew(audioComponentDist, &audioUnitDist)) {
            OSStatus status = noErr;
            
            if (noErr == status) {
                status = AudioUnitSetProperty(audioUnitDist, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            if (noErr == status) {
                status = AudioUnitSetProperty(audioUnitDist, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            
            if (noErr == status) {
                AURenderCallbackStruct renderCallbackStruct;
                renderCallbackStruct.inputProc = AU_DistRenderCallback;
                renderCallbackStruct.inputProcRefCon = (void *)tap;
                status = AudioUnitSetProperty(audioUnitDist, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallbackStruct, sizeof(AURenderCallbackStruct));
            }
            
            if (noErr == status) {
                UInt32 maximumFramesPerSlice = (UInt32)maxFrames;
                status = AudioUnitSetProperty(audioUnitDist, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, (UInt32)sizeof(UInt32));
            }
            
            if (noErr == status) {
                status = AudioUnitInitialize(audioUnitDist);
            }
            
            if (noErr != status) {
                AudioComponentInstanceDispose(audioUnitDist);
                audioUnitDist = NULL;
            }
            
            context->audioUnitDist = audioUnitDist;
            distAudioUnit = audioUnitDist;
        }
    }
    
    AudioUnit eqUnit;
    
    AudioComponentDescription audioComponentDescriptionEQ;
    audioComponentDescriptionEQ.componentType = kAudioUnitType_Effect;
    audioComponentDescriptionEQ.componentSubType = kAudioUnitSubType_NBandEQ;
    audioComponentDescriptionEQ.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescriptionEQ.componentFlags = 0;
    audioComponentDescriptionEQ.componentFlagsMask = 0;
    
    AudioComponent audioComponentEQ = AudioComponentFindNext(NULL, &audioComponentDescriptionEQ);
    if (audioComponentEQ) {
        if (noErr == AudioComponentInstanceNew(audioComponentEQ, &eqUnit)) {
            OSStatus status = noErr;
            
            if (noErr == status) {
                status = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            if (noErr == status) {
                status = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            
            if (noErr == status) {
                AURenderCallbackStruct renderCallbackStruct;
                renderCallbackStruct.inputProc = AU_EQRenderCallback;
                renderCallbackStruct.inputProcRefCon = (void *)tap;
                status = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallbackStruct, sizeof(AURenderCallbackStruct));
            }
            
            if (noErr == status) {
                UInt32 maximumFramesPerSlice = (UInt32)maxFrames;
                status = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, (UInt32)sizeof(UInt32));
            }
            
            if (noErr == status) {
                status = AudioUnitInitialize(eqUnit);
            }
            
            if (noErr != status) {
                AudioComponentInstanceDispose(eqUnit);
                eqUnit = NULL;
            }
            
            context->audioUnitEQ = eqUnit;
            eqAudioUnit = eqUnit;
        }
    }
    
    AudioUnit reverbUnit;
    
    AudioComponentDescription audioComponentDescriptionReverb;
    audioComponentDescriptionReverb.componentType = kAudioUnitType_Effect;
    audioComponentDescriptionReverb.componentSubType = kAudioUnitSubType_Reverb2;
    audioComponentDescriptionReverb.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescriptionReverb.componentFlags = 0;
    audioComponentDescriptionReverb.componentFlagsMask = 0;
    
    AudioComponent audioComponentReverb = AudioComponentFindNext(NULL, &audioComponentDescriptionReverb);
    if (audioComponentReverb) {
        if (noErr == AudioComponentInstanceNew(audioComponentReverb, &reverbUnit)) {
            OSStatus status = noErr;
            
            if (noErr == status) {
                status = AudioUnitSetProperty(reverbUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            if (noErr == status) {
                status = AudioUnitSetProperty(reverbUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, processingFormat, sizeof(AudioStreamBasicDescription));
            }
            
            if (noErr == status) {
                AURenderCallbackStruct renderCallbackStruct;
                renderCallbackStruct.inputProc = AU_ReverbRenderCallback;
                renderCallbackStruct.inputProcRefCon = (void *)tap;
                status = AudioUnitSetProperty(reverbUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallbackStruct, sizeof(AURenderCallbackStruct));
            }
            
            if (noErr == status) {
                UInt32 maximumFramesPerSlice = (UInt32)maxFrames;
                status = AudioUnitSetProperty(reverbUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, (UInt32)sizeof(UInt32));
            }
            
            if (noErr == status) {
                status = AudioUnitInitialize(reverbUnit);
            }
            
            if (noErr != status) {
                AudioComponentInstanceDispose(reverbUnit);
                reverbUnit = NULL;
            }
            
            context->audioUnitReverb = reverbUnit;
            reverbAudioUnit = reverbUnit;
        }
    }
}

static void tap_UnprepareCallback(MTAudioProcessingTapRef tap) {
    AVAudioManagerContext *context = (AVAudioManagerContext *)MTAudioProcessingTapGetStorage(tap);
    
    // Release bandpass filter Audio Unit
    if (context->audioUnitPitch) {
        AudioUnitUninitialize(context->audioUnitPitch);
        AudioComponentInstanceDispose(context->audioUnitPitch);
        context->audioUnitPitch = NULL;
    }
    
    if (context->audioUnitDist) {
        AudioUnitUninitialize(context->audioUnitDist);
        AudioComponentInstanceDispose(context->audioUnitDist);
        context->audioUnitDist = NULL;
    }
    
    if (context->audioUnitEQ) {
        AudioUnitUninitialize(context->audioUnitEQ);
        AudioComponentInstanceDispose(context->audioUnitEQ);
        context->audioUnitEQ = NULL;
    }
    
    if (context->audioUnitReverb) {
        AudioUnitUninitialize(context->audioUnitReverb);
        AudioComponentInstanceDispose(context->audioUnitReverb);
        context->audioUnitReverb = NULL;
    }
}

static void tap_ProcessCallback(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    AVAudioManagerContext *context = (AVAudioManagerContext *)MTAudioProcessingTapGetStorage(tap);
    
    OSStatus status;
    
    AudioManager * self = ((__bridge AudioManager *)context->self);
    
    // Skip processing when format not supported
    if (!self) {
      NSLog(@"AudioManager - processCallback CANCELLED");
      return;
    }
    
    // Apply bandpass filter Audio Unit
    if (self.isFilterEnabled) {
        AudioTimeStamp audioTimeStamp;
        audioTimeStamp.mSampleTime = context->sampleCount;
        audioTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        
        if (pitchEnabled) {
            status = AudioUnitRender(context->audioUnitPitch, 0, &audioTimeStamp, 0, (UInt32)numberFrames, bufferListInOut);
        } else if (eqEnabled) {
            status = AudioUnitRender(context->audioUnitEQ, 0, &audioTimeStamp, 0, (UInt32)numberFrames, bufferListInOut);
        } else if (distortionEnabled) {
            status = AudioUnitRender(context->audioUnitDist, 0, &audioTimeStamp, 0, (UInt32)numberFrames, bufferListInOut);
        } else {
            status = AudioUnitRender(context->audioUnitReverb, 0, &audioTimeStamp, 0, (UInt32)numberFrames, bufferListInOut);
        }
        
        if (noErr != status) {
            NSLog(@"AudioUnitRender: %d", (int)status);
            return;
        }
        
        // Increment sample count for Audio Unit
        context->sampleCount += numberFrames;
        processedFrames += numberFrames;
        // Set number of frames out
        *numberFramesOut = numberFrames;
    } else {
        // Get actual audio buffers
        status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
        if (noErr != status) {
            NSLog(@"MTAudioProcessingTapGetSourceAudio: %d", (int)status);
            return;
        }
    }
}

#pragma mark - Audio Unit Callbacks

OSStatus AU_PitchRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    AudioTimeStamp audioTimeStamp;
    audioTimeStamp.mSampleTime = processedFrames;
    audioTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    
    if (eqEnabled) {
        return AudioUnitRender(eqAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    if (distortionEnabled) {
        return AudioUnitRender(distAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    if (reverbEnabled) {
        return AudioUnitRender(reverbAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    // Return audio buffers
    return MTAudioProcessingTapGetSourceAudio(inRefCon, inNumberFrames, ioData, NULL, NULL, NULL);
}

OSStatus AU_EQRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    AudioTimeStamp audioTimeStamp;
    audioTimeStamp.mSampleTime = processedFrames;
    audioTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;

    if (distortionEnabled) {
        return AudioUnitRender(distAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    if (reverbEnabled) {
        return AudioUnitRender(reverbAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    
    return MTAudioProcessingTapGetSourceAudio(inRefCon, inNumberFrames, ioData, NULL, NULL, NULL);
}

OSStatus AU_ReverbRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    return MTAudioProcessingTapGetSourceAudio(inRefCon, inNumberFrames, ioData, NULL, NULL, NULL);
}

OSStatus AU_DistRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    AudioTimeStamp audioTimeStamp;
    audioTimeStamp.mSampleTime = processedFrames;
    audioTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    
    if (reverbEnabled) {
        return AudioUnitRender(reverbAudioUnit, 0, &audioTimeStamp, 0, inNumberFrames, ioData);
    }
    return MTAudioProcessingTapGetSourceAudio(inRefCon, inNumberFrames, ioData, NULL, NULL, NULL);
}
