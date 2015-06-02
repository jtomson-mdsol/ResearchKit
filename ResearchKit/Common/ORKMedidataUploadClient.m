//
//  ORKMedidataUploadClient.m
//  ResearchKit
//
//  Created by James Tomson on 6/2/15.
//  Copyright (c) 2015 researchkit.org. All rights reserved.
//

#import "ORKMedidataUploadClient.h"
#import "ORKResult.h"

#pragma mark - Serialization helpers

@interface ORKQuestionResult (MORK)
@property (readonly) NSDictionary *mork_fieldDataDictionary;
@end

@implementation ORKQuestionResult (MORK)

- (NSDictionary *)mork_fieldDataDictionary {
    return @{@"data_value" : [self mork_rawResult],
             @"item_oid" : self.identifier,
             @"date_time_entered" : [[self mork_dateFormatter] stringFromDate:self.endDate]};
}

- (NSString *)mork_rawResult {
    static NSDictionary *rawResultDictionary = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        rawResultDictionary = @{@"ORKChoiceQuestionResult": ^NSString*(ORKChoiceQuestionResult *result) {
                                    return [NSString stringWithFormat:@"%@", result.choiceAnswers.firstObject];
                                },
                                @"ORKDateQuestionResult": ^NSString*(ORKDateQuestionResult *result) {
                                    return [[self mork_dateFormatter] stringFromDate:result.dateAnswer];
                                },
                                @"ORKScaleQuestionResult": ^NSString*(ORKScaleQuestionResult *result) {
                                    return [NSString stringWithFormat:@"%@", [result scaleAnswer]];
                                }};
    });
    
    NSString *class = NSStringFromClass([self class]);
    NSString *(^block)(ORKQuestionResult *) = rawResultDictionary[class];
    NSAssert(block != nil, @"The %@ class is not currently supported.", class);
    return block(self);
}

- (NSDateFormatter *) mork_dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MM-yyyy hh:mm:ss"];
    });
    
    return dateFormatter;
}
@end

@interface ORKCollectionResult (MORK)

@property (readonly) NSArray *mork_fieldDataFromResults;

@end

@implementation ORKCollectionResult (MORK)

-(NSArray *) mork_fieldDataFromResults {
    NSMutableArray *data = [NSMutableArray array];
    [self.results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[ORKQuestionResult class]]) {
            ORKQuestionResult *result = (ORKQuestionResult *) obj;
            [data addObject: result.mork_fieldDataDictionary];
        }
        else if ([obj isKindOfClass:[ORKStepResult class]]) {
            // Extract data from nested ORKCollectionResult
            ORKStepResult *stepResult = (ORKStepResult *) obj;
            [data addObjectsFromArray: stepResult.mork_fieldDataFromResults];
        }
    }];
    return [data copy];
}

@end

#pragma mark - ORKMedidataUploadClient

@interface ORKMedidataUploadClient ()

@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURLSessionConfiguration *sessionConfig;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *password;

@property (nonatomic, getter=isAuthenticated) BOOL authenticated;

@end


@implementation ORKMedidataUploadClient

- (NSURLSession *)createSession {
    return [NSURLSession sessionWithConfiguration:self.sessionConfig];
}

- (void)addAuthenticationHeaders:(NSMutableURLRequest *)request {
    NSString *authString = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
    NSData *authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
    [request addValue:authValue forHTTPHeaderField:@"Authorization"];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [self createSession];
    }
    return self;
}

// FIXME
-(NSMutableDictionary *) odmParameters {
    NSDictionary *params = @{
                             @"subject_name": @"SB01",
                             @"study_uuid": @"e018fcb9-e06a-4ecb-8496-7af5af03b0b2",
                             @"signature_date_time_entered": @"2014-12-10T17:03:24",
                             @"folder_oid": @"SCREEN",
                             @"form_oid": @"MORK_FRM",
                             @"site_oid": @"site1",
                             @"version": @"1.0",
                             @"device_id": @"3FC94B89-920C-412A-BB9D-BFA9DF40F1B1",
                             @"rave_url": @"https://my-rave-url.mdsol.com",
                             @"study_name": @"MyStudyName",
                             @"subject_uuid": @"ba86d135-0f64-42a9-a45c-89087eb44fbe",
                             @"record_oid": @"MORK_FRM_LOG_LINE",
                             @"log_line": @1
                             };
    
    return [NSMutableDictionary dictionaryWithDictionary:params];
}

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password completionHandler:(nullable void (^)(NSURLResponse *, NSError *))completionHandler {
    
    /*
     Setup Basic authentication
     */
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://epro-url.imedidata.net/api/Username/authenticate"]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];
    
    [self addAuthenticationHeaders:request];
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    
    /*
     Authenticate the user with the Patient Cloud Gateway.
     */
    NSError *error = nil;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:@{@"password" : @{@"primary_password" : @"Password"}}
                                                       options:0
                                                         error:&error];
    if (!postData) {
        completionHandler(nil, error);
        return;
    }
    
    request.HTTPBody = postData;
    
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if(error) {
            self.authenticated = NO;
            completionHandler(response, error);
        }

        // remember credentials
        self.username = username;
        self.password = password;
        
        self.authenticated = YES;
        
        completionHandler(response, nil);
        
    }] resume];
}

- (void)uploadItem:(ORKTaskResult*)taskResult completionHandler:(nullable void (^)(ORKTaskResult *, NSURLResponse *, NSError *))completionHandler {
    
    /*
     Extract data from the ORKTaskResult and serialize it in the format expected by the Patient Cloud Gateway.
     */
    NSMutableDictionary *params = [self odmParameters];
    params[@"field_data"] = taskResult.mork_fieldDataFromResults;
    
    NSError *error = nil;
    NSData *odmData = [NSJSONSerialization dataWithJSONObject:@{@"form_data": params}
                                                      options:0
                                                        error:&error];
    
    if (!odmData) {
        completionHandler(taskResult, nil, error);
        return;
    }
    
    /*
     Post the results to the Patient Cloud Gateway.
     */
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://epro-app.imedidata.com/api/odm"]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];
    [self addAuthenticationHeaders:request];
    request.HTTPBody = odmData;
    
    [[_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error)
            completionHandler(taskResult, response, error);
        else
            completionHandler(taskResult, response, nil);
    }] resume];
}

- (void)stop {
    [self.session invalidateAndCancel];
    self.session = [self createSession];
}

@end
