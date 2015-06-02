//
//  ORKTaskResultUploader.m
//  ResearchKit
//
//  Created by James Tomson on 5/27/15.
//  Copyright (c) 2015 researchkit.org. All rights reserved.
//

#import "ORKUploader.h"

@interface ORKUploader ()

@property (nonatomic) BOOL uploading;

@end

@implementation ORKUploader

- (void)start {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isUploading)
            return;
        
        self.uploading = YES;
        
        id pendingItem = nil;
        __block UInt32 pendingCount = 0; // bookkeeping to know when we're no longing `uploading`
        
        while ((pendingItem = [self.delegate nextPendingItem])) {
            
            ++pendingCount;
            [self.delegate itemWasScheduledForUpload:pendingItem];
            
            [self.client uploadItem:pendingItem completionHandler:^ void(id item, id response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    --pendingCount;
                    if (pendingCount <= 0)
                        self.uploading = NO;
                    
                    if (error)
                        [self.delegate item:pendingItem didFailUploadwithError:error];
                    else
                        [self.delegate item:pendingItem didUploadWithResponse:response];
                });
            }];
        }
        
        if (pendingCount == 0)
            self.uploading = NO; // nothing was scheduled
    });
    
}

- (void)stop {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isUploading)
            return;
        
        [self.client stop];
        
        self.uploading = NO;
    });
}

@end
