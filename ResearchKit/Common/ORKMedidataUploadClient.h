//
//  ORKMedidataUploadClient.h
//  ResearchKit
//
//  Created by James Tomson on 6/2/15.
//  Copyright (c) 2015 researchkit.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ORKUploader.h"

NS_ASSUME_NONNULL_BEGIN

@class ORKTaskResult;

@interface ORKMedidataUploadClient : NSObject <ORKUploadClient>

@property (nonatomic, readonly, getter=isAuthenticated) BOOL authenticated;

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password completionHandler:(nullable void (^)(NSURLResponse *, NSError *))completionHandler;

- (void)uploadItem:(ORKTaskResult *)taskResult completionHandler:(nullable void (^)(ORKTaskResult *, NSURLResponse *, NSError *))completionHandler;

@end

NS_ASSUME_NONNULL_END