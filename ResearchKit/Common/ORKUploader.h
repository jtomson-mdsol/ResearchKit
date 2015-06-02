//
//  ORKUploader.h
//  ResearchKit
//
//  Created by James Tomson on 5/27/15.
//  Copyright (c) 2015 researchkit.org. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The `ORKUploaderDelegate` will be notified of item upload success and failure, and provide
 the list of pending items to upload.
 */
@protocol ORKUploaderDelegate <NSObject>

@required

/**
 Provide the next pending item to be uploaded.
 
 @return the next item waiting for succesful upload
 */
- (nullable id)nextPendingItem;

/**
 Called when item has been given to the ORKUploadClient for transport
 
 @param item the item that is pending upload
 */
- (void)itemWasScheduledForUpload:(id)item;

/**
 Called when an item was succesfully uploaded
 
 @param item     the item that was uploaded
 @param response an optional response object (e.g. receipt or http response body)
 */
- (void)item:(id)item didUploadWithResponse:(nullable id)response;

/**
 Called when an item failed to be uploaded
 
 @param item  the item that failed to be uploaded
 @param error the error containing details of the failure
 */
- (void)item:(id)item didFailUploadwithError:(nullable NSError *)error;

@end

/**
 The ORKUploadClient protocol defines a mechanism for actual transport of pending items
 */
@protocol ORKUploadClient <NSObject>

@required

/**
 Perform an upload of the passed item, and call the completion handler when done with an optional
 (id)response and (NSError *)error indicating success or failure
 */
- (void)uploadItem:(id)item completionHandler:(nullable void (^)(id, id, NSError *))completionHandler;


/**
 Attempt to stop any upload in progress
 */
- (void)stop;

@end

/**
 The `ORKUploader` is responsible for performing the upload of items provided by its delegate.
 
 The transport itself is performed by its ORKUploadClient instance `client`.
 
 Example items for upload:
 - ORKTaskResult instances to be serialized
 - File path NSURLs containing zipfile locations

 TODO: Provide subclass? e.g. ORKPeriodicUploader
 
 */
@interface ORKUploader : NSObject

/**
 The ORKUploadClient instance used to perform the transport of items
 */
@property (nonatomic, nullable) id<ORKUploadClient> client;

/**
 Will return whether this instance is started or stopped.
 */
@property (nonatomic, readonly, getter=isUploading) BOOL uploading;

/**
 The ORKUploaderDelegate instance used for bookkeeping pending items for upload
 */
@property (nonatomic, nullable) id<ORKUploaderDelegate> delegate;

/**
 Will start or  any pending uploads.
 */
- (void)start;

/**
 Will not upload any pending items until started again
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
