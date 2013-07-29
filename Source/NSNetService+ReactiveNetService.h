//
//  NSNetService+ReactiveNetService.h
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface NSNetService (ReactiveNetService)

+ (RACSignal *)rac_servicesOfType:(NSString *)type inDomain:(NSString *)domainString;
- (RACSignal *)rac_resolveWithTimeout:(NSTimeInterval)timeout;

@end

OBJC_EXTERN NSString *const RACNetServiceErrorDomain;
OBJC_EXTERN NSString *const RACNetServiceSystemErrorDomain;
